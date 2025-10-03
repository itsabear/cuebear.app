# CueBearBridgeClean

A clean rebuild of the Cue Bear Bridge app (macOS SwiftUI) with a bundled `iproxy` flow.

## How to use
1. Drop your `iproxy` binary in `CueBearBridgeClean/Resources/Helpers/iproxy` and make it executable (755).
2. Open `CueBearBridgeClean.xcodeproj` in Xcode 15+.
3. Build & Run. The app will start `iproxy`, wait until it's listening, connect, send a handshake, and keep retrying with a timeout if the iPad isn't ready.

## Bundling note
For shipping, codesign the helper and any dylibs in a Run Script (not included here to keep the sample minimal).
