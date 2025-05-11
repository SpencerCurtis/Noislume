#!/bin/bash

# Set up directories
WORKSPACE_DIR="$(pwd)"
BUILD_DIR="${WORKSPACE_DIR}/build"
LIBRAW_FRAMEWORK_DIR="${WORKSPACE_DIR}/Noislume/Frameworks/libraw.framework"
LCMS2_FRAMEWORK_DIR="${WORKSPACE_DIR}/Noislume/Frameworks/liblcms2.framework"

# Clean up any existing build
rm -rf "${BUILD_DIR}"
rm -rf "${LIBRAW_FRAMEWORK_DIR}"
rm -rf "${LCMS2_FRAMEWORK_DIR}"

# Create build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Get the development team identity
TEAM_ID=$(security find-identity -v -p codesigning | grep "Development" | awk '{print $2}')

if [ -z "$TEAM_ID" ]; then
    echo "Error: No development team identity found. Please make sure you have a valid development certificate in your keychain."
    exit 1
fi

# Build and install lcms2 first
curl -L https://github.com/mm2/Little-CMS/releases/download/lcms2.15/lcms2-2.15.tar.gz | tar xz
cd lcms2-2.15

# Create lcms2 framework structure
mkdir -p "${LCMS2_FRAMEWORK_DIR}/Versions/A/Headers"
mkdir -p "${LCMS2_FRAMEWORK_DIR}/Versions/A/Resources"

# Configure and build lcms2
CFLAGS="-arch arm64" CXXFLAGS="-arch arm64" LDFLAGS="-arch arm64" ./configure --enable-shared --prefix="${BUILD_DIR}/lcms2"
make
make install

# Copy lcms2 files to framework
cp "${BUILD_DIR}/lcms2/lib/liblcms2.2.dylib" "${LCMS2_FRAMEWORK_DIR}/Versions/A/liblcms2"
cp -r "${BUILD_DIR}/lcms2/include/lcms2"*.h "${LCMS2_FRAMEWORK_DIR}/Versions/A/Headers/"

# Create lcms2 framework symlinks
cd "${LCMS2_FRAMEWORK_DIR}/Versions"
ln -s A Current
cd "${LCMS2_FRAMEWORK_DIR}"
ln -s Versions/Current/Headers Headers
ln -s Versions/Current/Resources Resources
ln -s Versions/Current/liblcms2 liblcms2

# Create lcms2 Info.plist
cat > "${LCMS2_FRAMEWORK_DIR}/Versions/A/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>liblcms2</string>
    <key>CFBundleIdentifier</key>
    <string>com.SpencerCurtis.liblcms2</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>liblcms2</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>2.15</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>15.3</string>
</dict>
</plist>
EOF

# Fix lcms2 install name
install_name_tool -id "@rpath/liblcms2.framework/liblcms2" "${LCMS2_FRAMEWORK_DIR}/Versions/A/liblcms2"

# Sign lcms2 framework
codesign --force --sign "$TEAM_ID" --timestamp=none "${LCMS2_FRAMEWORK_DIR}/Versions/A/liblcms2"
codesign --force --sign "$TEAM_ID" --timestamp=none "${LCMS2_FRAMEWORK_DIR}"

# Now build libraw
cd "${BUILD_DIR}/LibRaw-0.21.4"

# Create libraw framework structure
mkdir -p "${LIBRAW_FRAMEWORK_DIR}/Versions/A/Headers"
mkdir -p "${LIBRAW_FRAMEWORK_DIR}/Versions/A/Resources"

# Configure and build libraw
CFLAGS="-arch arm64" CXXFLAGS="-arch arm64" LDFLAGS="-arch arm64" ./configure --enable-shared --prefix="${BUILD_DIR}/libraw" --with-lcms2="${BUILD_DIR}/lcms2"
make
make install

# Copy libraw files to framework
cp "${BUILD_DIR}/libraw/lib/libraw.23.dylib" "${LIBRAW_FRAMEWORK_DIR}/Versions/A/libraw"
cp -r "${BUILD_DIR}/libraw/include/libraw/"* "${LIBRAW_FRAMEWORK_DIR}/Versions/A/Headers/"

# Create libraw framework symlinks
cd "${LIBRAW_FRAMEWORK_DIR}/Versions"
ln -s A Current
cd "${LIBRAW_FRAMEWORK_DIR}"
ln -s Versions/Current/Headers Headers
ln -s Versions/Current/Resources Resources
ln -s Versions/Current/libraw libraw

# Create libraw Info.plist
cat > "${LIBRAW_FRAMEWORK_DIR}/Versions/A/Resources/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>libraw</string>
    <key>CFBundleIdentifier</key>
    <string>com.SpencerCurtis.libraw</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>libraw</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>0.21.4</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>15.3</string>
</dict>
</plist>
EOF

# Fix libraw install name and dependencies
install_name_tool -id "@rpath/libraw.framework/libraw" "${LIBRAW_FRAMEWORK_DIR}/Versions/A/libraw"
install_name_tool -change "/usr/local/lib/liblcms2.2.dylib" "@rpath/liblcms2.framework/liblcms2" "${LIBRAW_FRAMEWORK_DIR}/Versions/A/libraw"

# Sign libraw framework
codesign --force --sign "$TEAM_ID" --timestamp=none "${LIBRAW_FRAMEWORK_DIR}/Versions/A/libraw"
codesign --force --sign "$TEAM_ID" --timestamp=none "${LIBRAW_FRAMEWORK_DIR}"

# Clean up
cd "${WORKSPACE_DIR}"
rm -rf "${BUILD_DIR}" 