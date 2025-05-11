#!/bin/bash

# Source files
LIBRAW_DYLIB="/usr/local/Cellar/libraw/0.21.4/lib/libraw.23.dylib"
LIBRAW_HEADERS="/usr/local/Cellar/libraw/0.21.4/include/libraw"

if [ ! -f "$LIBRAW_DYLIB" ]; then
    echo "Error: libraw dylib not found at $LIBRAW_DYLIB"
    exit 1
fi

if [ ! -d "$LIBRAW_HEADERS" ]; then
    echo "Error: libraw headers not found at $LIBRAW_HEADERS"
    exit 1
fi

# Create framework directory structure
FRAMEWORK_DIR="Noislume/Frameworks/libraw.framework"
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
    <string>libraw</string>
    <key>CFBundleIdentifier</key>
    <string>com.libraw.libraw</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>libraw</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.21.4</string>
    <key>CFBundleVersion</key>
    <string>0.21.4</string>
    <key>NSPrincipalClass</key>
    <string></string>
</dict>
</plist>
EOF

# Copy the dylib
cp "$LIBRAW_DYLIB" "$VERSION_DIR/libraw"

# Copy headers
cp -R "$LIBRAW_HEADERS"/* "$VERSION_DIR/Headers/"

# Create symbolic links
cd "$FRAMEWORK_DIR"
ln -sf Versions/A/libraw libraw
ln -sf Versions/A/Resources Resources
ln -sf Versions/A/Headers Headers
cd Versions
ln -sf A Current

# Set permissions
chmod 755 "$VERSION_DIR/libraw"

echo "Framework created successfully at $FRAMEWORK_DIR" 