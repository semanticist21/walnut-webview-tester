#!/usr/bin/env python3
"""
App Store Connect API - Screenshot Upload Script

Uploads screenshots directly using App Store Connect API.
Bypasses fastlane for better control and newer device support.
"""

import jwt
import time
import requests
import hashlib
import os
import sys
from pathlib import Path

# API Credentials
ISSUER_ID = "a7524762-b1db-463b-84a8-bbee51a37cc2"
KEY_ID = "74HC92L9NA"
PRIVATE_KEY_PATH = Path.home() / "Documents/API/AuthKey_74HC92L9NA.p8"

# App Store Connect API Base URL
BASE_URL = "https://api.appstoreconnect.apple.com/v1"

# App ID (com.kobbokkom.wina)
APP_ID = "6755930250"

# Screenshots directory
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent
SCREENSHOTS_DIR = PROJECT_ROOT / "fastlane" / "screenshots"

# Display types mapping from filename pattern to API type
DISPLAY_TYPES = {
    "iPhone67": "APP_IPHONE_67",          # 6.7"/6.9" (1320x2868)
    "iPadPro129": "APP_IPAD_PRO_3GEN_129",  # 12.9"/13" (2048x2732)
}

# Token cache
_cached_token = None
_token_expiry = 0


def generate_token():
    """Generate JWT token for App Store Connect API."""
    global _cached_token, _token_expiry

    # Return cached token if still valid (with 60s buffer)
    if _cached_token and time.time() < _token_expiry - 60:
        return _cached_token

    private_key = PRIVATE_KEY_PATH.read_text()

    # Token expires in 20 minutes
    expiry = int(time.time()) + 20 * 60

    payload = {
        "iss": ISSUER_ID,
        "iat": int(time.time()),
        "exp": expiry,
        "aud": "appstoreconnect-v1"
    }

    token = jwt.encode(
        payload,
        private_key,
        algorithm="ES256",
        headers={"kid": KEY_ID}
    )

    _cached_token = token
    _token_expiry = expiry
    return token


def api_request(method, endpoint, data=None):
    """Make authenticated API request."""
    token = generate_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    url = f"{BASE_URL}{endpoint}"

    if method == "GET":
        response = requests.get(url, headers=headers)
    elif method == "POST":
        response = requests.post(url, headers=headers, json=data)
    elif method == "PATCH":
        response = requests.patch(url, headers=headers, json=data)
    elif method == "DELETE":
        response = requests.delete(url, headers=headers)
    else:
        raise ValueError(f"Unknown method: {method}")

    return response


def get_app_store_version():
    """Get the latest editable App Store version."""
    response = api_request(
        "GET",
        f"/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED,WAITING_FOR_REVIEW,PENDING_DEVELOPER_RELEASE,IN_REVIEW"
    )

    if response.status_code != 200:
        print(f"Error getting versions: {response.status_code}")
        print(response.text)
        return None

    data = response.json()
    versions = data.get("data", [])

    if not versions:
        print("No editable App Store version found")
        print("Make sure you have a version in 'Prepare for Submission' state")
        return None

    # Prefer PREPARE_FOR_SUBMISSION, then DEVELOPER_REJECTED
    for version in versions:
        state = version["attributes"]["appStoreState"]
        if state == "PREPARE_FOR_SUBMISSION":
            return version["id"], version["attributes"]["versionString"], state

    # Return first available
    v = versions[0]
    return v["id"], v["attributes"]["versionString"], v["attributes"]["appStoreState"]


def get_localizations(version_id):
    """Get all localizations for a version."""
    response = api_request("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations?limit=50")

    if response.status_code != 200:
        print(f"Error getting localizations: {response.status_code}")
        return {}

    data = response.json()
    localizations = {}

    for loc in data.get("data", []):
        locale = loc["attributes"]["locale"]
        localizations[locale] = loc["id"]

    return localizations


def get_screenshot_sets(localization_id):
    """Get existing screenshot sets for a localization."""
    response = api_request("GET", f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets")

    if response.status_code != 200:
        return {}

    data = response.json()
    sets = {}

    for s in data.get("data", []):
        display_type = s["attributes"]["screenshotDisplayType"]
        sets[display_type] = s["id"]

    return sets


def create_screenshot_set(localization_id, display_type):
    """Create a new screenshot set."""
    data = {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {
                "screenshotDisplayType": display_type
            },
            "relationships": {
                "appStoreVersionLocalization": {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": localization_id
                    }
                }
            }
        }
    }

    response = api_request("POST", "/appScreenshotSets", data)

    if response.status_code in [200, 201]:
        return response.json()["data"]["id"]
    elif response.status_code == 409:
        # Already exists, get the ID
        sets = get_screenshot_sets(localization_id)
        return sets.get(display_type)
    else:
        return None


def delete_existing_screenshots(screenshot_set_id):
    """Delete all existing screenshots in a set."""
    response = api_request("GET", f"/appScreenshotSets/{screenshot_set_id}/appScreenshots")

    if response.status_code != 200:
        return 0

    data = response.json()
    count = 0
    for screenshot in data.get("data", []):
        screenshot_id = screenshot["id"]
        api_request("DELETE", f"/appScreenshots/{screenshot_id}")
        count += 1

    return count


def upload_screenshot(screenshot_set_id, file_path):
    """Upload a single screenshot."""
    file_size = os.path.getsize(file_path)
    file_name = os.path.basename(file_path)

    # Read file and calculate checksum
    with open(file_path, "rb") as f:
        file_data = f.read()
        checksum = hashlib.md5(file_data).hexdigest()

    # Step 1: Reserve upload
    reserve_data = {
        "data": {
            "type": "appScreenshots",
            "attributes": {
                "fileName": file_name,
                "fileSize": file_size
            },
            "relationships": {
                "appScreenshotSet": {
                    "data": {
                        "type": "appScreenshotSets",
                        "id": screenshot_set_id
                    }
                }
            }
        }
    }

    response = api_request("POST", "/appScreenshots", reserve_data)

    if response.status_code not in [200, 201]:
        return False

    reservation = response.json()["data"]
    screenshot_id = reservation["id"]
    upload_ops = reservation["attributes"].get("uploadOperations", [])

    if not upload_ops:
        return False

    # Step 2: Upload to each operation URL
    for op in upload_ops:
        upload_url = op["url"]
        offset = op["offset"]
        length = op["length"]
        request_headers = {h["name"]: h["value"] for h in op["requestHeaders"]}

        chunk = file_data[offset:offset + length]

        upload_response = requests.put(upload_url, headers=request_headers, data=chunk)

        if upload_response.status_code not in [200, 201]:
            return False

    # Step 3: Commit upload
    commit_data = {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {
                "uploaded": True,
                "sourceFileChecksum": checksum
            }
        }
    }

    response = api_request("PATCH", f"/appScreenshots/{screenshot_id}", commit_data)

    return response.status_code in [200, 201]


def process_locale(locale, localization_id):
    """Process all screenshots for a single locale."""
    locale_dir = SCREENSHOTS_DIR / locale

    if not locale_dir.exists():
        return 0, 0, "No directory"

    # Get or create screenshot sets
    existing_sets = get_screenshot_sets(localization_id)

    iphone_count = 0
    ipad_count = 0

    # Process each display type
    for device_prefix, display_type in DISPLAY_TYPES.items():
        # Find screenshots for this device
        pattern = f"*_{device_prefix}_*.png"
        screenshots = sorted(locale_dir.glob(pattern))

        if not screenshots:
            continue

        # Get or create screenshot set
        if display_type in existing_sets:
            set_id = existing_sets[display_type]
        else:
            set_id = create_screenshot_set(localization_id, display_type)
            if not set_id:
                continue

        # Delete existing screenshots
        delete_existing_screenshots(set_id)

        # Upload each screenshot
        for screenshot_path in screenshots:
            success = upload_screenshot(set_id, screenshot_path)
            if success:
                if "iPhone" in device_prefix:
                    iphone_count += 1
                else:
                    ipad_count += 1

    return iphone_count, ipad_count, "OK"


def main():
    print("=" * 60)
    print("App Store Connect Screenshot Upload (API)")
    print("=" * 60)
    sys.stdout.flush()

    # Check screenshots directory
    if not SCREENSHOTS_DIR.exists():
        print(f"Error: Screenshots directory not found: {SCREENSHOTS_DIR}")
        print("Run upload-screenshots.py first to generate PNGs")
        return

    # Get App Store version
    print("\n1. Getting App Store version...")
    sys.stdout.flush()
    result = get_app_store_version()
    if not result:
        print("Error: No editable App Store version found")
        return
    version_id, version_string, state = result
    print(f"   Version: {version_string} ({state})")
    print(f"   ID: {version_id}")
    sys.stdout.flush()

    # Get localizations
    print("\n2. Getting localizations...")
    sys.stdout.flush()
    localizations = get_localizations(version_id)
    print(f"   Found {len(localizations)} localizations")
    sys.stdout.flush()

    # Process each locale
    print("\n3. Uploading screenshots...")
    print()
    sys.stdout.flush()

    total_iphone = 0
    total_ipad = 0
    processed = 0

    for locale, loc_id in sorted(localizations.items()):
        processed += 1
        iphone, ipad, status = process_locale(locale, loc_id)
        total_iphone += iphone
        total_ipad += ipad

        print(f"[{processed:2d}/{len(localizations)}] {locale}: {iphone} iPhone, {ipad} iPad - {status}")
        sys.stdout.flush()

    print("\n" + "=" * 60)
    print(f"Done! Uploaded {total_iphone} iPhone + {total_ipad} iPad screenshots")
    print("=" * 60)


if __name__ == "__main__":
    main()
