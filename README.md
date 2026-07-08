# RoyalDash iOS

RoyalDash iOS is an experimental iPhone companion for the Royal Enfield Himalayan 450 TFT/Tripper-style dash.

The first milestone is deliberately small:

1. Reproduce the frozen K1G control protocol.
2. Authenticate with the dash over its Wi-Fi network.
3. Send a minimal H.264/RTP projection stream.
4. Validate the behavior on a real iPhone 15 and the real motorcycle TFT.

This project is independent, unofficial, and based on community protocol research from `subtlesayak/open-dash`.

## Current Status

The repository starts with a pure Swift package:

- `RoyalDashCore`
- K1G packet building/parsing
- RSA/AES dash authentication state machine
- dash transport routing for frozen UDP control/RTP endpoints
- incoming dash dispatcher for auth, frame ACKs, and button ACKs
- receive loop glue that routes dispatcher replies through the transport
- high-level dash session facade for auth, incoming events, control commands, and RTP sends
- selected dash command bytes
- H.264 NAL processor for Annex-B/AVCC normalization, AUD/SEI filtering, and SPS/PPS caching
- RTP packetizer
- offline fake dash session and demo CLI
- unit tests for protocol-critical behavior

The SwiftUI iOS app shell and Xcode project are now present.
The first navigable screen prototype is documented in `docs/screen-prototype.md`.
The app prototype is connected to `RoyalDashCore` through a simulated app model documented in `docs/app-core-model.md`.

## CI

GitHub Actions is configured in:

- `.github/workflows/ios-ci.yml`

It runs on pull requests and manual dispatches. The workflow runs `swift test` and, with `RoyalDash.xcodeproj` present, builds and tests the iOS app on the simulator available in GitHub Actions.

## Hardware Testing

The simulator can validate UI and pure protocol tests, but the important tests require:

- iPhone 15
- Himalayan 450 TFT powered on
- dash Wi-Fi SSID/password
- real UDP broadcast/RTP validation
- screen-lock/background behavior checks

See:

- `docs/proposta-ios-himalayan-450.md`
- `docs/github-actions-ios.md`
- `docs/app-core-model.md`
- `docs/dash-session.md`
- `docs/h264-nal-processor.md`
- `docs/screen-prototype.md`
