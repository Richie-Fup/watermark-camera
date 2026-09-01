# Chronos Lens

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![iOS](https://img.shields.io/badge/iOS-17.0+-black.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)

Native iOS watermark camera. Overlay time, place, weekday, weather, and temperature while shooting — or stamp existing library media using EXIF / GPS metadata.

---

## Features

- **Live watermark** — overlays the watermark on the camera preview for photos and videos, saved to the system photo library
- **Historical stamping** — import from the library, read capture time and GPS, reverse-lookup the weather, then export
- **Customizable templates** — field toggles, nine-grid position, color, font size, opacity, background style
- **Privacy-first** — location and weather are used only on-device to generate watermarks and are never uploaded to third-party servers
- **Bilingual** — follows the system language: Chinese for `zh-Hans`, English otherwise

## Tech Stack

| Area | Choice |
|------|--------|
| UI | SwiftUI (+ `UIViewRepresentable` camera preview) |
| Camera / Video | AVFoundation |
| Photos | PhotoKit / PhotosUI |
| Location | CoreLocation |
| Weather | WeatherKit |
| Persistence | SwiftData |
| Architecture | MVVM + Feature / Domain / Service / Data |

## Requirements

- macOS + **Xcode 15+** and [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- A device or simulator running **iOS 17.0+**
- An Apple Developer account (WeatherKit requires the capability to be enabled)

## Getting Started

1. Clone the repo, then generate the Xcode project from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

   ```bash
   brew install xcodegen
   xcodegen generate
   ```

2. Open the generated `WatermarkCamera.xcodeproj` in Xcode.
3. Enable **WeatherKit** for your App ID in [Apple Developer](https://developer.apple.com), and confirm the entitlement in Xcode Signing & Capabilities.
4. Confirm the Bundle Identifier is `com.yeex.watermarkcamera` (select your own team under Signing).
5. Run on a device or simulator.

> WeatherKit has call quotas. When offline, without coordinates, or outside the historical weather range, the weather and temperature fields are hidden automatically while the other fields render as usual.

The root `project.yml` is the single source of truth for the project — `WatermarkCamera.xcodeproj` is generated from it and is not checked in. Run `xcodegen generate` again whenever you change the project structure.

## Project Structure

```
WatermarkCamera/
├── App/                 # entry point, dependency injection, root navigation
├── Features/            # Camera / Library / Editor / Templates / Settings
├── Domain/              # models and use cases
├── Services/            # camera, location, weather, rendering, export, etc.
├── Data/                # SwiftData and template seed data
├── Core/                # shared extensions
└── Resources/           # assets, Info.plist, localization, entitlements
```

## Localization

- `en` — English
- `zh-Hans` — Simplified Chinese

The development language is English. Chinese is used when the system language is Chinese, with English as the fallback. Strings live under `WatermarkCamera/Resources/Localization/`.

## Privacy & Support

Camera, microphone, location, and photo library permissions are used only for watermark features. The legal and support pages are hosted in the public repo [`Richie-Fup/common-pages`](https://github.com/Richie-Fup/common-pages) (GitHub Pages), under `watermark-camera/`:

| Purpose | URL |
|---------|-----|
| **Support** (App Store Support URL) | https://richie-fup.github.io/common-pages/watermark-camera/ |
| Privacy Policy | https://richie-fup.github.io/common-pages/watermark-camera/privacy.html |
| Terms of Use | https://richie-fup.github.io/common-pages/watermark-camera/terms.html |

In the `common-pages` repo, go to **Settings → Pages** and choose **Deploy from a branch**, selecting branch `main` and folder `/ (root)`.

## Contributing

Issues and pull requests are welcome. For larger changes, please open an issue to discuss the approach first. Make sure the project builds before submitting, and keep changes consistent with the existing layering.

## License

This project is open source under the [MIT License](LICENSE).

When using WeatherKit / Apple Weather data, please comply with [Apple's attribution and terms](https://weatherkit.apple.com/legal-attribution.html).
