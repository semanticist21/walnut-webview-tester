#!/usr/bin/env python3
"""
App Store Connect Screenshot Upload Script

Converts SVG screenshots to PNG using rsvg-convert (preserves gradients)
and prepares them for fastlane deliver upload.
Uses parallel processing for speed.
"""

import os
import subprocess
import shutil
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading

# Configuration
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
FASTLANE_SCREENSHOTS = PROJECT_ROOT / "fastlane" / "screenshots"
SCREENSHOTS_DIR = SCRIPT_DIR / "screenshots"

# Device dimensions
IPHONE_SIZE = (1320, 2868)  # iPhone 6.9" (iPhone 16 Pro Max)
IPAD_SIZE = (2048, 2732)    # iPad Pro 13" (official App Store spec)

# Current generic screenshot size
GENERIC_IPHONE_SIZE = (1206, 2622)
GENERIC_IPAD_SIZE = (2064, 2752)

# All App Store Connect locales
LOCALES = [
    "ar-SA", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA", "en-GB", "en-US",
    "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "he", "hi", "hr", "hu", "id",
    "it", "ja", "ko", "ms", "nl-NL", "no", "pl", "pt-BR", "pt-PT", "ro",
    "ru", "sk", "sv", "th", "tr", "uk", "vi", "zh-Hans", "zh-Hant"
]

# Maximum screenshots per device type (App Store allows 10)
MAX_IPHONE_SCREENSHOTS = 10
MAX_IPAD_SCREENSHOTS = 10

# Parallel processing
MAX_WORKERS = 8
print_lock = threading.Lock()


def log(msg):
    """Thread-safe print."""
    with print_lock:
        print(msg)


def run_cmd(cmd, check=True):
    """Run a shell command."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise subprocess.CalledProcessError(result.returncode, cmd, result.stderr)
    return result


def convert_svg_to_png(svg_path, png_path, width, height):
    """Convert SVG to PNG using rsvg-convert (preserves gradients)."""
    cmd = f'rsvg-convert -w {width} -h {height} "{svg_path}" -o "{png_path}"'
    run_cmd(cmd)
    return f"Converted: {svg_path.name}"


def resize_png(src_path, dst_path, target_width, target_height):
    """Resize PNG with cover (fill) behavior - crops to fit exact dimensions."""
    # Get source dimensions
    result = run_cmd(f'magick identify -format "%wx%h" "{src_path}"')
    src_dims = result.stdout.strip().split("x")
    src_w, src_h = int(src_dims[0]), int(src_dims[1])

    # Calculate scale to cover target (fill, not fit)
    scale_w = target_width / src_w
    scale_h = target_height / src_h
    scale = max(scale_w, scale_h)

    new_w = int(src_w * scale)
    new_h = int(src_h * scale)

    # Resize then center crop
    cmd = (
        f'magick "{src_path}" '
        f'-resize {new_w}x{new_h} '
        f'-gravity center '
        f'-extent {target_width}x{target_height} '
        f'"{dst_path}"'
    )
    run_cmd(cmd)
    return f"Resized: {src_path.name}"


def process_locale(locale):
    """Process all screenshots for a single locale."""
    locale_src = SCRIPT_DIR / locale
    locale_dst = FASTLANE_SCREENSHOTS / locale
    locale_dst.mkdir(parents=True, exist_ok=True)

    tasks = []
    screenshot_index = 1
    ipad_index = 1

    # 1. Localized SVG promo images (1.svg, 2.svg, 3.svg) → iPhone
    for i in [1, 2, 3]:
        svg_path = locale_src / f"{i}.svg"
        if svg_path.exists():
            png_path = locale_dst / f"{screenshot_index:02d}_iPhone67_{i}.png"
            tasks.append(("svg", svg_path, png_path, IPHONE_SIZE[0], IPHONE_SIZE[1]))
            screenshot_index += 1

    # 2. Generic iPhone screenshots (1.png ~ 12.png) - resize
    remaining_slots = MAX_IPHONE_SCREENSHOTS - (screenshot_index - 1)
    for i in range(1, min(13, remaining_slots + 1)):
        src_path = SCREENSHOTS_DIR / f"{i}.png"
        if src_path.exists():
            dst_path = locale_dst / f"{screenshot_index:02d}_iPhone67_generic{i}.png"
            tasks.append(("resize", src_path, dst_path, IPHONE_SIZE[0], IPHONE_SIZE[1]))
            screenshot_index += 1

    # 3. Localized iPad SVG promo images (ipad-1.svg, ipad-2.svg, ipad-3.svg)
    for i in [1, 2, 3]:
        svg_path = locale_src / f"ipad-{i}.svg"
        if svg_path.exists():
            png_path = locale_dst / f"{ipad_index:02d}_iPadPro129_{i}.png"
            tasks.append(("svg", svg_path, png_path, IPAD_SIZE[0], IPAD_SIZE[1]))
            ipad_index += 1

    # 4. Generic iPad screenshots (ipad-1.png ~ ipad-4.png) - resize
    remaining_ipad_slots = MAX_IPAD_SCREENSHOTS - (ipad_index - 1)
    for i in range(1, min(5, remaining_ipad_slots + 1)):
        src_path = SCREENSHOTS_DIR / f"ipad-{i}.png"
        if src_path.exists():
            dst_path = locale_dst / f"{ipad_index:02d}_iPadPro129_generic{i}.png"
            tasks.append(("resize", src_path, dst_path, IPAD_SIZE[0], IPAD_SIZE[1]))
            ipad_index += 1

    # Execute tasks
    for task_type, src, dst, w, h in tasks:
        if task_type == "svg":
            convert_svg_to_png(src, dst, w, h)
        else:
            resize_png(src, dst, w, h)

    return locale, screenshot_index - 1, ipad_index - 1


def main():
    print("=" * 60)
    print("App Store Screenshot Preparation (Parallel)")
    print("=" * 60)

    # Check dependencies
    try:
        run_cmd("which rsvg-convert")
        run_cmd("which magick")
    except subprocess.CalledProcessError as e:
        print(f"Error: Missing dependency. Install with: brew install librsvg imagemagick")
        return

    # Clean and create output directory
    if FASTLANE_SCREENSHOTS.exists():
        shutil.rmtree(FASTLANE_SCREENSHOTS)
    FASTLANE_SCREENSHOTS.mkdir(parents=True)

    print(f"\nOutput: {FASTLANE_SCREENSHOTS}")
    print(f"iPhone target: {IPHONE_SIZE[0]}x{IPHONE_SIZE[1]}")
    print(f"iPad target: {IPAD_SIZE[0]}x{IPAD_SIZE[1]}")
    print(f"Workers: {MAX_WORKERS}")
    print()

    # Process locales in parallel
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        futures = {executor.submit(process_locale, locale): locale for locale in LOCALES}

        completed = 0
        for future in as_completed(futures):
            locale = futures[future]
            try:
                loc, iphone_count, ipad_count = future.result()
                completed += 1
                log(f"[{completed:2d}/{len(LOCALES)}] {loc}: {iphone_count} iPhone, {ipad_count} iPad")
            except Exception as e:
                log(f"[ERROR] {locale}: {e}")

    print("\n" + "=" * 60)
    print("Done! Screenshots prepared in fastlane/screenshots/")
    print("\nTo upload to App Store Connect:")
    print("  cd /Users/semanticist/Documents/code/wallnut")
    print("  fastlane screenshots")
    print("=" * 60)


if __name__ == "__main__":
    main()
