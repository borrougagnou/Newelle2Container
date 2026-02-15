#!/bin/bash
# Newelle AppImage Builder
# Bundles GNOME runtime in case user isn't on gnome
# Usage: ./build-newelle-appimage.sh

set -e

echo "Building Newelle AppImage"
echo "========================================="

# --- CONFIGURATION ---
#### APP
APP_NAME="Newelle"
APP_VERSION="1.2.5"
#BRANCH="master"
#TODO DEBUG
BRANCH="appimage"
#TODO DEBUG
REPO_URL="https://github.com/borrougagnou/Newelle2Container.git"
#### PYTHON
PYTHON_VERSION="3.13.12"
#### BUILD
BUILDDIR="/tmp/Newelle-build"
APPDIR="/tmp/Newelle.AppDir"
OUTPUT="/tmp/Newelle-$APP_VERSION-x86_64.AppImage"


#############################
# STEP 6: Bundle GNOME     #
#############################

echo ""
echo "### Step 6/10: Bundling GNOME Platform libraries..."
echo "  (Required for XFCE/KDE/LXDE/... compatibility)"

cd "$BUILDDIR"
mkdir -p "$APPDIR/usr/lib" "$APPDIR/usr/lib/girepository-1.0"

# Copy GTK4 and GNOME libraries
echo "  - GTK4/Libadwaita libraries..."
for lib in libgtk-4 libadwaita-1 libgtksourceview-5 libwebkitgtk-6.0 libvte-2.91-gtk4; do
    find /usr/lib/x86_64-linux-gnu -name "${lib}.so.*" -exec cp -L {} "$APPDIR/usr/lib/" \; 2>/dev/null || true
done

# Copy critical dependencies
echo "  - Core GNOME dependencies..."
for lib in libgraphene libpangocairo libpango libcairo libgdk_pixbuf libgio libgobject libglib; do
    find /usr/lib/x86_64-linux-gnu -name "${lib}*.so.*" -exec cp -L {} "$APPDIR/usr/lib/" \; 2>/dev/null || true
done

# Copy GObject Introspection typelibs (critical for PyGObject)
echo "  - GObject Introspection typelibs..."
for typelib in Gtk-4.0 Adw-1 GtkSource-5 Vte-3.91 WebKit-6.0 GLib-2.0 GObject-2.0 Gio-2.0; do
    find /usr/lib/x86_64-linux-gnu/girepository-1.0 -name "${typelib}.typelib" \
        -exec cp {} "$APPDIR/usr/lib/girepository-1.0/" \; 2>/dev/null || true
done
find /usr/lib -name "libffi.so*"   -type f -exec cp {} $APPDIR/usr/lib/ \;
find /usr/lib -name "libexpat.so*" -type f -exec cp {} $APPDIR/usr/lib/ \;
find /usr/lib -name "libz.so*"     -type f -exec cp {} $APPDIR/usr/lib/ \;
find /usr/lib -name "libuuid.so*"  -type f -exec cp {} $APPDIR/usr/lib/ \;

find /usr/lib -name "libgirepository-1.0.so*" -type f -exec cp {} $APPDIR/usr/lib/ \;
find /usr/lib -name "libgirepository-2.0.so*" -type f -exec cp {} $APPDIR/usr/lib/ \;
find /usr/lib -name "libportaudio.so.2*"      -type f -exec cp {} $APPDIR/usr/lib/ \;

# C. Handle Typelibs (Required for GTK)
echo "--> Bundling Typelibs..."
mkdir -p AppDir/usr/lib/girepository-1.0
# Try standard paths
cp -r /usr/lib/x86_64-linux-gnu/girepository-1.0/* AppDir/usr/lib/girepository-1.0/ 2>/dev/null || true
cp -r /usr/lib/girepository-1.0/* AppDir/usr/lib/girepository-1.0/ 2>/dev/null || true


# Copy and Compile GSettings schemas
echo "  - GSettings schemas..."
mkdir -p "$APPDIR/usr/share/glib-2.0/schemas"
#cp /usr/share/glib-2.0/schemas/org.gnome*.xml "$APPDIR/usr/share/glib-2.0/schemas/" 2>/dev/null || true
#cp /usr/share/glib-2.0/schemas/org.gtk*.xml "$APPDIR/usr/share/glib-2.0/schemas/" 2>/dev/null || true

#cp "$APPDIR/usr/share/glib-2.0/schemas/"*.xml "$APPDIR/usr/share/glib-2.0/schemas/" 2>/dev/null || true
glib-compile-schemas "$APPDIR/usr/share/glib-2.0/schemas/"

# Copy Adwaita icons (essential for GTK4 apps)
echo "  - Adwaita icon theme..."
mkdir -p "$APPDIR/usr/share/icons"
if [ -d "/usr/share/icons/Adwaita" ]; then
    cp -r /usr/share/icons/Adwaita "$APPDIR/usr/share/icons/"
fi

## We need that because the app search for AppDir/share not AppDir/usr/share
#if [ -d "AppDir/usr/share" ]; then
#    ln -s usr/share AppDir/share
#fi

##########################
# STEP 7: Patches        #
##########################

echo ""
echo "### Step 7/10: Applying patches..."

echo "No Patch"



##########################
# STEP 8: Create AppRun  #
##########################

echo ""
echo "### Step 8/10: Creating AppRun script..."

cat > "$APPDIR/AppRun" << 'APPRUN_EOF'
#!/bin/bash
# AppRun script for Newelle
# Provides isolated environment with GNOME runtime

echo "DEBUG: Finding libraries..."
find "$HERE/usr/lib" -name "libexpat.so*"
find "$HERE/usr/lib" -name "libffi.so*"
echo "DEBUG: Current LD_PRELOAD is: $LD_PRELOAD"

set -e

SELF=$(readlink -f "$0")
HERE=${SELF%/*}

echo "Starting Newelle AppImage" >&2
echo "   APPDIR: $HERE" >&2

# APPDIR for application path detection
export APPDIR="$HERE/usr"

export PATH="$HERE/usr/bin:${PATH}"

# Python environment
export PYTHONHOME="$HERE/usr"
export PYTHONPATH="$HERE/usr/lib/python3.13/site-packages:$HERE/usr/share/newelle:${PYTHONPATH}"
#export PYTHONUSERBASE="$HOME/.config/Newelle/pip"  # Runtime pip goes here

# GTK/GNOME runtime
export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib/python3.13/lib:${LD_LIBRARY_PATH}"
#export LD_LIBRARY_PATH="$HERE/usr/lib:\$HERE/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"
#export LD_LIBRARY_PATH="\$HERE/usr/lib/extras:\$HERE/usr/lib/python/lib\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"

export GDK_BACKEND=wayland,x11  # Wayland preferred, X11 fallback
export GI_TYPELIB_PATH="$HERE/usr/lib/girepository-1.0"
export GDK_PIXBUF_MODULEDIR="$HERE/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders"
export GDK_PIXBUF_MODULE_FILE="$HERE/usr/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"

# User data directories (stays in home)
export XDG_DATA_DIRS="$HERE/usr/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# GSettings
export GSETTINGS_SCHEMA_DIR="$HERE/usr/share/glib-2.0/schemas:${GSETTINGS_SCHEMA_DIR}"

# Audio
export SDL_AUDIODRIVER=pulseaudio

# Disable Flatpak-specific code
export FLATPAK_DISABLE=1

# Vulkan (for llama-cpp-python GPU acceleration)
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/nvidia_icd.json:/usr/share/vulkan/icd.d/radeon_icd.json

# Verify critical files
if [ ! -f "$HERE/usr/bin/newelle" ]; then
    echo "ERROR: newelle: $HERE/usr/bin/newelle: file not found!" >&2
    exit 1
fi

if [ ! -f "$HERE/usr/share/newelle/newelle.gresource" ]; then
    echo "ERROR: GResource: $HERE/usr/share/newelle/newelle.gresource: file not found!" >&2
    exit 1
fi

echo "XDG_DATA_DIRS:$XDG_DATA_DIRS"

# Execute application
exec "$HERE/usr/bin/python3" "$HERE/usr/bin/newelle" "$@"
APPRUN_EOF

chmod +x "$APPDIR/AppRun"



############################
# STEP 9: Optimization     #
############################

echo ""
echo "### Step 9/10: Optimizing AppImage size..."

# Strip debug symbols
echo "  - Stripping debug symbols..."
find "$APPDIR" -type f -executable -exec strip --strip-debug {} \; 2>/dev/null || true

# Remove Python cache
echo "  - Removing Python cache..."
find "$APPDIR" -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
find "$APPDIR" -type f -name "*.pyc" -delete 2>/dev/null || true
find "$APPDIR" -type f -name "*.pyo" -delete 2>/dev/null || true

# Remove unnecessary files
echo "  - Removing docs and tests..."
rm -rf "$APPDIR/usr/share/doc" "$APPDIR/usr/share/man" 2>/dev/null || true
find "$APPDIR/usr/lib" -type d -name test -exec rm -rf {} + 2>/dev/null || true



###############################
# STEP 10: Create AppImage    #
###############################

echo ""
echo "### Step 10/10: Creating final AppImage..."

cd /tmp

# Download appimagetool
if [ ! -f "appimagetool-x86_64.AppImage" ]; then
    wget -q https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
    chmod +x appimagetool-x86_64.AppImage
fi

# Give the FUSE3 support for appimagetool instead of FUSE2
if [ ! -f "runtime-x86_64" ]; then
    wget -q https://github.com/AppImage/type2-runtime/releases/download/continuous/runtime-x86_64
fi

# Extract to avoid FUSE issues during build
if [ ! -d "appimagetool" ]; then
    ./appimagetool-x86_64.AppImage --appimage-extract
    mv squashfs-root appimagetool
fi

#TODO DEBUG
rm -rf $APPDIR-tmp
cp -r $APPDIR $APPDIR-tmp
#TODO DEBUG

# Create AppImage with compression
echo "  - Packaging (this may take several minutes)..."
ARCH=x86_64 ./appimagetool/AppRun --runtime-file /tmp/runtime-x86_64 "$APPDIR" "$OUTPUT"

chmod +x "$OUTPUT"



echo ""
echo "========================================="
echo "BUILD COMPLETE!"
echo "========================================="
echo ""
echo "AppImage location: $OUTPUT"
echo "Size: $(du -h "$OUTPUT" | cut -f1)"
echo ""
echo "To test:"
echo "  $OUTPUT"
echo ""
echo "To install system-wide:"
echo "  sudo cp $OUTPUT /opt/"
echo "  sudo chmod +x /opt/$(basename "$OUTPUT")"
echo ""

