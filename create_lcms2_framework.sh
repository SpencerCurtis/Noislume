#!/bin/bash

# Source files
LCMS2_DYLIB="/usr/local/Cellar/little-cms2/2.17/lib/liblcms2.2.dylib"
LCMS2_HEADERS="/usr/local/Cellar/little-cms2/2.17/include"

if [ ! -f "$LCMS2_DYLIB" ]; then
    echo "Error: liblcms2 dylib not found at $LCMS2_DYLIB"
    exit 1
fi

if [ ! -d "$LCMS2_HEADERS" ]; then
    echo "Error: liblcms2 headers not found at $LCMS2_HEADERS"
    exit 1
fi

# Create framework directory structure
FRAMEWORK_DIR="Noislume/Frameworks/liblcms2.framework"
VERSION_DIR="$FRAMEWORK_DIR/Versions/A"

# Remove existing framework if it exists
rm -rf "$FRAMEWORK_DIR"

# Create directories
mkdir -p "$VERSION_DIR"
mkdir -p "$VERSION_DIR/Resources"
mkdir -p "$VERSION_DIR/Headers"

# Create Info.plist
cat > "$VERSION_DIR/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>liblcms2</string>
    <key>CFBundleIdentifier</key>
    <string>com.littlecms.lcms2</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>liblcms2</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>2.17</string>
    <key>CFBundleVersion</key>
    <string>2.17</string>
    <key>NSPrincipalClass</key>
    <string></string>
</dict>
</plist>
EOF

# Copy the dylib
cp "$LCMS2_DYLIB" "$VERSION_DIR/liblcms2"

# Copy headers
cp -R "$LCMS2_HEADERS"/lcms2*.h "$VERSION_DIR/Headers/"

# Create symbolic links
cd "$FRAMEWORK_DIR"
ln -sf Versions/A/liblcms2 liblcms2
ln -sf Versions/A/Resources Resources
ln -sf Versions/A/Headers Headers
cd Versions
ln -sf A Current

# Set permissions
chmod 755 "$VERSION_DIR/liblcms2"

echo "Framework created successfully at $FRAMEWORK_DIR" 