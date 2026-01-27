#!/bin/bash

# --- CONFIGURATION ---
APP_NAME="Newelle"
APP_VERSION="1.2.5"
PYTHON_VERSION="3.13.10"
STANDALONE_TAG="20251202"

# Your main python script (change this if yours is named differently)
MAIN_SCRIPT="main.py"




echo "=== Starting AppImage Build for $APP_NAME ==="

# 1. CLEANUP PREVIOUS BUILD
rm -rf AppDir $APP_NAME-x86_64.AppImage
mkdir -p AppDir/usr/bin
mkdir -p AppDir/usr/lib

# 2. DOWNLOAD PORTABLE PYTHON
# We use 'python-build-standalone' which is pre-patched to work anywhere
echo "--> Downloading Portable Python $PYTHON_VERSION..."
PYTHON_URL="https://github.com/indygreg/python-build-standalone/releases/download/$STANDALONE_TAG/cpython-$PYTHON_VERSION+${STANDALONE_TAG}-x86_64-unknown-linux-gnu-install_only.tar.gz"
wget -q --show-progress $PYTHON_URL -O python.tar.gz

echo "--> Extracting Python..."
tar -xzf python.tar.gz
# Move the 'python' folder into the AppDir
mv python AppDir/usr/lib/python
rm python.tar.gz

# 3. INSTALL DEPENDENCIES
# We install your requirements directly into the bundled Python
if [ -f "requirements.txt" ]; then
    echo "--> Installing dependencies from requirements.txt..."
    ./AppDir/usr/lib/python/bin/python3 -m pip install -r requirements.txt
else
    echo "--> No requirements.txt found, skipping pip install."
fi

# 4. COPY YOUR CODE
echo "--> Copying your source code..."
# Copy your main script to the bin folder
cp "$MAIN_SCRIPT" AppDir/usr/bin/
# If you have other folders/files, copy them here too:
# cp -r my_module AppDir/usr/bin/







# 5. CREATE THE ENTRY POINT (AppRun)
# This script runs when you double-click the AppImage
echo "--> Creating AppRun..."
cat <<EOF > AppDir/AppRun
#!/bin/bash
# Calculate where the AppImage is mounted
HERE="\$(dirname "\$(readlink -f "\${0}")")"

# Set up the environment to use the bundled Python
export PATH="\$HERE/usr/lib/python/bin:\$PATH"
export PYTHONHOME="\$HERE/usr/lib/python"
export PYTHONPATH="\$HERE/usr/bin:\$PYTHONPATH"

# Run the python program
exec "\$HERE/usr/lib/python/bin/python3" "\$HERE/usr/bin/$MAIN_SCRIPT" "\$@"
EOF

chmod +x AppDir/AppRun







# 6. CREATE METADATA
echo "--> Creating Desktop file and Icon..."
# Create a dummy icon if you don't have one
touch AppDir/$APP_NAME.png

# Create the .desktop file
cat <<EOF > AppDir/$APP_NAME.desktop
[Desktop Entry]
Name=$APP_NAME
Exec=AppRun
Icon=$APP_NAME
Type=Application
Categories=Utility;
EOF

# 7. BUILD THE APPIMAGE
echo "--> Downloading AppImageTool..."
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    wget -q https://github.com/AppImage/AppImageKit/releases/download/13/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

echo "--> Packaging final AppImage..."
# ARCH=x86_64 is required for appimagetool to run in some environments
ARCH=x86_64 ./appimagetool-x86_64.AppImage AppDir

echo "=== SUCCESS! ==="
echo "Your app is ready: $APP_NAME-x86_64.AppImage"


