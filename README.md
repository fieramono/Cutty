# Cutty - Native iOS Audio Trimmer

Cutty is a premium, modern, and lightweight iOS application designed specifically to trim audio files (`mp3`, `wav`, `m4a`, `aac`, etc.) and apply native volume fades (Fade-In/Fade-Out). 

Built using **SwiftUI** and **AVFoundation**, it features a fully interactive glassmorphic interface and a visual sound waveform custom renderer.

---

## Key Features

1. **Multi-Format Decoders**: Seamlessly load any audio format natively decodable by iOS (`mp3`, `wav`, `m4a`, `caf`, etc.).
2. **Interactive Waveform Chart**: Renders a beautiful visual representation of the audio amplitudes. You can slide the start and end handles directly on the graph to set the trim boundaries.
3. **High-Precision Time Offsets**: Adjust crop intervals via sliders or fine-tune them using incremental `+` and `-` buttons (down to 0.5-second intervals).
4. **Dynamic Volume Fades**: Enable and customize Fade-In and/or Fade-Out duration (defaults to 2.0s). Volume curves are applied using hardware-accelerated `AVMutableAudioMix` volume ramps.
5. **Output Configuration**: Customize output filename (defaults to `[original]_(demo)`) and choose your saving destination.
6. **Resilient Saving & Sandbox Fallback**: Tries to write output directly to the original file directory. If macOS/iOS sandboxing restricts folder access, it automatically falls back to launch the system's native `.fileExporter` picker sheet.

---

## Technical Overview

* **Deployment Target**: iOS 16.0+
* **Language**: Swift 5.9 / SwiftUI
* **Frameworks**: 
  * `AVFoundation` (specifically `AVURLAsset`, `AVAudioFile`, `AVAudioPCMBuffer` for analysis, and `AVMutableComposition` / `AVAssetExportSession` for rendering).
  * `UniformTypeIdentifiers` for secure file sharing.
* **Project Generation**: Configured using **XcodeGen** for clean, reproducible project files.

---

## Quick Start (How to Run)

### 1. Generate the Xcode Project
Since this project uses XcodeGen to avoid `.xcodeproj` version conflicts, you need to generate the project file first. A portable XcodeGen binary is included in the project directory:

```bash
# Run this command in the project root directory
./xcodegen/bin/xcodegen generate
```

This will automatically create `Cutty.xcodeproj`.

### 2. Open and Build in Xcode
1. Double-click the newly created **`Cutty.xcodeproj`** file to open it in Xcode.
2. Select your target destination (e.g., a simulator like *iPhone 15* or your connected physical device) in the top scheme selector.
3. Click the **Play** button (or press `Cmd + R` on your keyboard) to build and launch the application.

---

## Installing on a Physical iPhone

To run the application on your physical device, follow these quick steps:

1. **Enable Developer Mode** on your iPhone:
   * Go to **Settings** > **Privacy & Security** > scroll to bottom and tap **Developer Mode**.
   * Turn the switch ON, restart your iPhone, and enter your passcode to confirm.
2. **Connect your iPhone** to your Mac using a USB cable and unlock it. Tap "Trust this computer" if prompted.
3. In Xcode, click the **Cutty** project node in the left navigator bar.
4. Select the **Cutty** target, go to the **Signing & Capabilities** tab, check **Automatically manage signing**, and select your personal **Team** (Apple ID account).
5. Change the target device in the top destination selector to your physical iPhone.
6. Press `Cmd + R` to compile and run.
7. *First time only*: Go to your iPhone's **Settings** > **General** > **VPN & Device Management**, tap your Apple ID email, and select **Trust**.

---

## License

This project is created for personal use. Feel free to copy, modify, and distribute.
