#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create frameworks directory if it doesn't exist
mkdir -p "Noislume/Frameworks"

# Remove existing framework if it exists
echo -e "${YELLOW}Cleaning existing framework...${NC}"
rm -rf "Noislume/Frameworks/LibRawKit.xcframework"

# Copy LibRawKit XCFramework
echo -e "${YELLOW}Copying LibRawKit XCFramework...${NC}"
cp -R "Librawpper/Products/LibRawKit.xcframework" "Noislume/Frameworks/"

# Verify framework structure
if [ ! -d "Noislume/Frameworks/LibRawKit.xcframework" ]; then
    echo -e "${RED}Error: LibRawKit.xcframework not found${NC}"
    exit 1
fi

# Set proper permissions
echo -e "${YELLOW}Setting permissions...${NC}"
find "Noislume/Frameworks/LibRawKit.xcframework" -type f -exec chmod 644 {} \;
find "Noislume/Frameworks/LibRawKit.xcframework" -type d -exec chmod 755 {} \;

# Verify the copy
echo -e "${YELLOW}Verifying framework structure...${NC}"
if [ ! -f "Noislume/Frameworks/LibRawKit.xcframework/Info.plist" ]; then
    echo -e "${RED}Error: Info.plist not found in XCFramework${NC}"
    exit 1
fi

if [ ! -f "Noislume/Frameworks/LibRawKit.xcframework/macos-arm64_x86_64/libLibRawKit.a" ]; then
    echo -e "${RED}Error: macOS binary not found in XCFramework${NC}"
    exit 1
fi

if [ ! -f "Noislume/Frameworks/LibRawKit.xcframework/ios-arm64/libLibRawKit.a" ]; then
    echo -e "${RED}Error: iOS binary not found in XCFramework${NC}"
    exit 1
fi

# Sign the framework
echo -e "${YELLOW}Signing LibRawKit XCFramework...${NC}"
find "Noislume/Frameworks/LibRawKit.xcframework" -name "*.dylib" -o -name "*.a" | while read -r file; do
    echo "Signing $file"
    codesign --force --sign - --timestamp=none "$file"
done

echo -e "${GREEN}Framework update complete!${NC}"
echo -e "${YELLOW}Please clean and rebuild your Xcode project.${NC}" 