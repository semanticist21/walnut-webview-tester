# Wallnut (wina) - iOS WKWebView Tester App

## Project Overview

**Wallnut (wina)** is an iOS developer tool built with SwiftUI (targeting iOS 16.0+) designed to test `WKWebView` configurations and behaviors in real-time.

**Key Features:**
*   **WebView Testing:** Toggle between `WKWebView` and `SFSafariViewController`.
*   **DevTools:** Built-in console logger, network inspector, storage viewer, performance metrics, and source code viewer.
*   **Capabilities:** Detects and tests API capabilities (Camera, Microphone, Geolocation, etc.).
*   **Utilities:** User Agent customization, dark mode support, and screenshot functionality.

## Architecture

The project follows a feature-based architecture where each major functional area has its own directory in `Features/`.

### Directory Structure

*   `wina/`
    *   `winaApp.swift`: App entry point. Initializes key managers (`AdManager`, `StoreManager`).
    *   `ContentView.swift`: Main view composition.
    *   `Features/`: Contains feature-specific logic and views.
        *   `Ad/`: Google AdMob integration.
        *   `Console/`: JavaScript console capture and display.
        *   `Network/`: Network request monitoring and inspection.
        *   `Sources/`: Source code viewer (DOM, CSS, Scripts) using Runestone.
        *   `Web/`: WebView wrapper and navigation logic.
        *   `...` (About, Info, Settings, Storage, etc.)
    *   `Shared/`: Reusable components (`GlassButton`, etc.) and extensions.
    *   `Resources/`: Assets and icons.

## Building and Running

### Prerequisites
*   Xcode 14+ (Targeting iOS 16.0+)
*   SwiftLint (for linting)

### Commands

*   **Open Project:**
    ```bash
    open wina.xcodeproj
    ```
    Then press `Cmd+R` to build and run in the simulator or on a device.

*   **Run Tests:**
    ```bash
    xcodebuild test -project wina.xcodeproj -scheme wina -destination 'platform=iOS Simulator,name=iPhone 16'
    ```

*   **Linting:**
    ```bash
    swiftlint lint
    ```

## Development Conventions

### Coding Style
*   **Naming:** PascalCase for types/files, camelCase for variables/functions.
*   **Logging:** Use `os_log` or `Logger`. Avoid `print()` in production code.
*   **SwiftUI:**
    *   Use `@State` sparingly.
    *   Use `LazyVStack` for long lists (1000+ items).
    *   Prefer `struct` over `class` for simple data models.
*   **Files:** One component per file recommended. Limit files to ~150 lines where possible.

### Core Patterns

*   **WebView Management:** A new `WKWebView` instance is created when configurations change (using a UUID as an ID).
*   **Settings:** Settings are stored in `AppStorage` but applied explicitly via an "Apply" action to trigger a WebView reload.
*   **DevTools:** `ConsoleManager`, `NetworkManager`, etc., inject JavaScript to capture data from the WebView.
*   **Screenshots:** Implemented for `WKWebView` using `takeSnapshot`. (Not available for `SFSafariViewController`).

## Key Implementation Details

*   **CORS Limitations:** `WKWebView` enforces CORS. External script fetching via `evaluateJavaScript` will fail. Inline scripts are used for inspection.
*   **Resource Timing:** Cross-origin resources often return 0 bytes for size metrics due to security restrictions.
*   **Permissions:** The `Info.plist` includes usage descriptions for Camera, Microphone, Location, and Photo Library access to support testing these web capabilities.
