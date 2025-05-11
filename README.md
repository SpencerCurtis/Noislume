# Noislume

A macOS application for RAW image processing and noise reduction.

## Prerequisites

- macOS 15.3 or later
- Xcode 16.3 or later (for development only)

## Setup

### For Users
Simply download and run the app - all required frameworks are bundled with the application.

### For Developers

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/Noislume.git
   cd Noislume
   ```

2. Set up the framework:
   ```bash
   chmod +x update_frameworks.sh
   ./update_frameworks.sh
   ```
   This script will copy the LibRawKit XCFramework into the app bundle.

3. Open the project in Xcode:
   ```bash
   open Noislume.xcodeproj
   ```

4. Clean and build:
   - In Xcode, select Product → Clean Build Folder
   - Build the project (⌘B)

## Framework Management

The project uses the LibRawKit XCFramework for RAW image processing:
- Embedded in the app bundle
- Not required to be installed on the user's system
- Automatically loaded when the app launches

For development, the framework is not included in the repository but can be copied using the `update_frameworks.sh` script. This approach:
- Keeps the repository size manageable
- Ensures consistent framework versions across all developers
- Makes it easy to update to new versions

### Updating the Framework

To update the framework:

1. Run the update script:
   ```bash
   ./update_frameworks.sh
   ```

2. After the script completes:
   - Clean the Xcode build folder
   - Rebuild the project

## Project Structure

```
Noislume/
├── Frameworks/           # Generated frameworks (not in git)
├── Views/               # SwiftUI views
├── ViewModels/          # View models
├── Models/              # Data models
├── Utils/               # Utility classes
├── Assets.xcassets/     # App assets
└── update_frameworks.sh # Framework management script
```

## Development

- The project uses SwiftUI for the user interface
- Framework verification is built into the app startup
- Logs can be viewed in Console.app by filtering for "com.SpencerCurtis.Noislume"

## License

[Your License Here]

## Framework Dependencies

### LibRawKit
- Version: Latest from main branch
- Source: https://github.com/SpencerCurtis/LibRawKit
- Type: XCFramework
- Location: Noislume/Frameworks/LibRawKit.xcframework 