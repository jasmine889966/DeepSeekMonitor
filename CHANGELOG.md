# Changelog

## 1.10 - 2026-05-27

- Added an official DeepSeek service status section with Apple-style 90-day component status bars.
- Added API Service and Web Chat Service uptime, recent incident history, and a link to the official status page.
- Updated the menu bar card with official service health and component-level status dots.
- Updated the menu bar icon color: white when services are healthy, red when service issues are detected.
- Kept official status refresh independent from login state, so service health still loads when the DeepSeek session is missing or expired.

## 1.0.0 - 2026-05-24

- Initial open-source release.
- Added macOS SwiftUI dashboard, menu bar summary, login capture, local credential storage, usage and cost views, model breakdowns, and alert thresholds.
- Added unit tests for decoding, formatting, credential storage, and alert deduplication.
