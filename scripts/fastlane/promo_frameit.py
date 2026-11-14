"""Approved promotional composition stage for run_frameit_pipeline.sh."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import struct
import subprocess
import tempfile
from datetime import datetime, timezone

SCREEN_IDS = {"02_Timer", "11_RoutinesCatalog", "20_ProgressMonth",
              "12_RoutineEditor", "05_TrainingCompleted"}


def dimensions(path):
    with path.open("rb") as stream:
        header = stream.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return list(struct.unpack(">II", header[16:24]))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate(config, root, check_sources=True):
    if config["locale"] != "es":
        raise ValueError("Only the approved Spanish delivery is enabled")
    screens = config["screens"]
    if len(screens) != 5 or {s["id"] for s in screens} != SCREEN_IDS:
        raise ValueError("Exactly five distinct approved screens are required")
    for screen in screens:
        if Path(screen["source"]).name != screen["id"] + ".png":
            raise ValueError("Source filename must match its screen identifier")
    if config["canvas"] != [1290, 2796]:
        raise ValueError("This delivery requires a 1290×2796 App Store canvas")
    if not check_sources:
        return
    project = (root / "GymTimerPro.xcodeproj/project.pbxproj").read_text()
    for key, value in [("MARKETING_VERSION", config["version"]),
                       ("CURRENT_PROJECT_VERSION", config["build"])]:
        if set(re.findall(rf"{key}\s*=\s*([^;]+);", project)) != {value}:
            raise ValueError(f"Recapture sources and update manifest: {key} changed")
    for screen in screens:
        path = root / screen["source"]
        if dimensions(path) != [1320, 2868] or digest(path) != screen["sha256"]:
            raise ValueError(f"Unverified or changed source: {screen['id']}")
    provenance = json.loads((root / config["capture_provenance"]).read_text())
    for filename, expected in provenance["source"]["files_sha256"].items():
        if Path(filename).name != ".DS_Store" and digest(root / filename) != expected:
            raise ValueError(f"App changed since capture; recapture before rendering: {filename}")
    for key in ["icon"]:
        if not (root / config[key]).is_file():
            raise FileNotFoundError(config[key])


def command(*args, **kwargs):
    subprocess.run([str(a) for a in args], check=True, **kwargs)


def label(text, font, size, color, bounds, output):
    command("magick", "-background", "none", "-fill", color, "-font", font,
            "-pointsize", size, "-interline-spacing", "-6", "-gravity", "center",
            "label:" + text, "-resize", bounds + ">", output)


def render(config, root, output):
    if output.exists():
        raise ValueError(f"Output already exists; select a new results root: {output}")
    validate(config, root)
    style = config["style"]
    cache = Path.home() / ".fastlane/frameit/latest"
    frame = cache / f"Apple {config['frame_device']} {config['frame_color'].title()}.png"
    if not (frame.is_file() and (cache / "offsets.json").is_file()
            and (cache / "version.txt").is_file()
            and int((cache / "version.txt").read_text().strip()) > 0):
        raise ValueError("Required Frameit cache is missing; no automatic downloads allowed")
    for executable in ["fastlane", "magick"]:
        if not shutil.which(executable):
            raise ValueError(f"Required executable missing: {executable}")
    display, body = [str(root / style[k]) for k in ["display_font", "body_font"]]
    for font in [display, body]:
        if not Path(font).is_file():
            raise FileNotFoundError(font)
    with tempfile.TemporaryDirectory(prefix="repbuzz-promo-") as folder:
        work = Path(folder)
        stage, final = work / "frames", work / "final"
        stage.mkdir()
        final.mkdir()
        frame_config = {"default": {"use_platform": "IOS",
                        "force_device_type": config["frame_device"],
                        "frame": config["frame_color"]}, "data": []}
        (stage / "Framefile.json").write_text(json.dumps(frame_config))
        for screen in config["screens"]:
            command("magick", root / screen["source"], "-resize",
                    "x".join(map(str, config["screen_size"])) + "!",
                    stage / (screen["id"] + ".png"))
        env = dict(os.environ, FASTLANE_SKIP_UPDATE_CHECK="1", FASTLANE_OPT_OUT_USAGE="1")
        command("fastlane", "frameit", "ios", cwd=stage, env=env)
        for screen in config["screens"]:
            framed = stage / (screen["id"] + "_framed.png")
            if not framed.is_file():
                raise ValueError(f"Frameit did not produce {screen['id']}; nothing exported")
        size = "x".join(map(str, config["canvas"]))
        background = work / "background.png"
        command("magick", "-size", size, "gradient:" + "-".join(style["background"]),
                background)
        for color_name in ["blue", "orange"]:
            paths = " ".join(f"path '{p}'" for p in style[color_name + "_paths"])
            glow = work / "glow.png"
            command("magick", "-size", size, "xc:none", "-fill", "none", "-stroke",
                    style[color_name], "-strokewidth", 100, "-draw", paths,
                    "-blur", "0x65", glow)
            command("magick", background, glow, "-compose", "over", "-composite",
                    "-fill", "none", "-stroke", style[color_name],
                    "-strokewidth", 12, "-draw", paths, background)
        icon, brand, lockup = [work / (n + ".png") for n in ["icon", "brand", "lockup"]]
        mask = work / "icon-mask.png"
        command("magick", "-size", "164x164", "xc:none", "-fill", "white",
                "-draw", "roundrectangle 0,0,163,163,35,35", mask)
        command("magick", root / config["icon"], "-resize", "164x164", mask,
                "-alpha", "off", "-compose", "CopyOpacity", "-composite", icon)
        label("RepBuzz", display, 86, "white", "420x150", brand)
        command("magick", "-size", "570x164", "xc:none", icon,
                "-geometry", "+0+0", "-composite", brand, "-gravity", "west",
                "-geometry", "+194+0", "-composite", lockup)
        provenance = {"version": config["version"], "build": config["build"],
                      "locale": "es", "generated_at": datetime.now(timezone.utc).isoformat(),
                      "frame_device": config["frame_device"], "screens": []}
        for index, screen in enumerate(config["screens"], 1):
            title, subtitle, phone = [work / (n + ".png") for n in ["title", "subtitle", "phone"]]
            label(screen["title"], display, style["title_size"], "white", "1150x280", title)
            label(screen["subtitle"], body, style["subtitle_size"],
                  style["subtitle_color"], "1160x150", subtitle)
            command("magick", stage / (screen["id"] + "_framed.png"),
                    "-resize", "x".join(map(str, style["phone_bounds"])), phone)
            target = final / f"{index:02d}_{screen['id']}.png"
            args = ["magick", background]
            for image, y in [(lockup, style["brand_y"]), (title, style["title_y"]),
                             (subtitle, style["subtitle_y"]), (phone, style["phone_y"])]:
                args += [image, "-gravity", "north", "-geometry", f"+0+{y}", "-composite"]
            command(*args, "-alpha", "off", "-colorspace", "sRGB", "-depth", 8, target)
            if dimensions(target) != config["canvas"]:
                raise ValueError(f"Invalid final dimensions: {target.name}")
            provenance["screens"].append(dict(screen, output=target.name,
                                               output_sha256=digest(target)))
        (final / "manifest.json").write_text(json.dumps(provenance, ensure_ascii=False, indent=2))
        output.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(final, output)
    print(f"Created five verified Spanish screenshots: {output}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--design-config", required=True, type=Path)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--results-root", type=Path,
                        help="New output directory; existing results are never reused or overwritten")
    parser.add_argument("--check-only", action="store_true", help="Validate current version and source hashes without rendering")
    args = parser.parse_args()
    root = args.project_root.resolve()
    config = json.loads(args.design_config.read_text())
    if args.check_only:
        validate(config, root)
        print("Five source mappings, hashes and current app version verified")
    else:
        render(config, root, args.results_root or root / "fastlane/frameit/results/repbuzz-es")


if __name__ == "__main__":
    main()
