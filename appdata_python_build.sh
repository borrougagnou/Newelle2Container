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


# --- CLEANUP ---
#TODO
#rm -rf "$BUILDDIR"
#rm -rf "$APPDIR"
rm -rf  "$OUTPUT" build _build /tmp/squashfs-root/
#TODO DEBUG
rm -rf $APPDIR-tmp
#TODO DEBUG

# --- CREATE ---
mkdir -p "$BUILDDIR" "$APPDIR"

########################################
## STEP 1: Install Build Dependencies  #
########################################
#
#echo ""
#echo "### Step 1/10: Installing build dependencies..."
#
#sudo apt-get update
#
## Build essentials
#sudo apt-get install -y --no-install-recommends build-essential meson ninja-build pkg-config git wget \
#  gettext libssl-dev
#
## Python (would like to use venv but there is an incompatibility problem :c)
#sudo apt-get install -y --no-install-recommends python3-dev python3-pip python3-venv \
#  python3-gi python3-gi-cairo
#
## GTK4/GNOME development
#sudo apt-get install -y --no-install-recommends libgtk-4-dev libadwaita-1-dev libgtksourceview-5-dev \
#  libwebkitgtk-6.0-dev libvte-2.91-gtk4-dev libgirepository1.0-dev \
#  gir1.2-gtk-4.0 gir1.2-adw-1 gir1.2-gtksource-5 gir1.2-vte-3.91 gir1.2-webkit-6.0
#
## SDL2 for pygame
#sudo apt-get install -y --no-install-recommends libsdl2-dev libsdl2-image-dev libsdl2-mixer-dev libsdl2-ttf-dev
#
## Audio libraries
#sudo apt-get install -y --no-install-recommends libportaudio2 portaudio19-dev libpulse-dev libasound2-dev \
#  ffmpeg
#
## Image processing
#sudo apt-get install -y --no-install-recommends libjpeg62-turbo-dev libpng-dev zlib1g-dev libfreetype-dev \
#  libgdk-pixbuf-2.0-dev librsvg2-dev
#
## Additional
#sudo apt-get install -y --no-install-recommends libqhull-dev rustc cargo desktop-file-utils libglib2.0-bin \
#  appstream-util
#
#sudo apt clean
#sudo rm -rf /var/lib/apt/lists/*



###########################
# STEP 2.1: Build App     #
###########################

echo ""
echo "### Step 2.1/10: Building application with Meson..."

cd "$BUILDDIR"
if [ ! -d "$BUILDDIR/Newelle2Container" ]; then
echo "--> clone from branch $BRANCH"
    git clone --depth 1 -b "$BRANCH" "$REPO_URL"
fi
cd Newelle2Container

# Build translations
echo "--> Build translations"
chmod +x build_locale.sh
./build_locale.sh || true

# Configure and build
echo "--> Configure and build"
rm -rf _build
meson setup _build --prefix=/usr --buildtype=release
meson compile -C _build
# Install to AppDir
echo "--> Install to AppDir"
meson install -C _build --destdir "$APPDIR"



###########################
# STEP 2.2: Build Python  #
###########################

echo ""
echo "### Step 2.2/10: Prepare Python"

if [ ! -f "/tmp/python.tgz" ]; then
    echo "--> Downloading Python Source $PYTHON_VERSION..."
    PYTHON_URL="https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tgz"
    wget -q --show-progress $PYTHON_URL -O /tmp/python.tgz
fi

# if python3 isn't on appdir, then we need to rebuild everything unfortunately...
if [ ! -f "$APPDIR/usr/bin/python3" ]; then
    rm -rf "$BUILDDIR/Python-$PYTHON_VERSION"

    echo "--> Extracting Python..."
    tar -xf /tmp/python.tgz -C $BUILDDIR

    cd "$BUILDDIR/Python-$PYTHON_VERSION"
    echo "--> Compiling Python (This will take a few minutes)..."
    # The Magic Flag: '-Wl,-rpath=\$$ORIGIN/../lib' will makes the binary relocatable!
    ./configure \
        --prefix=/usr \
        --enable-shared \
        --enable-optimizations \
        --with-system-ffi \
        --with-ssl-default-suites=openssl \
        LDFLAGS="-Wl,-rpath='\$\$ORIGIN/../lib'"

    # Compile using all CPU cores
    make -j$(nproc)

    echo "--> Installing Python to AppDir..."
    make install DESTDIR=$APPDIR
fi

echo "Done"

################################
# STEP 3: Python Environment   #
################################

echo ""
echo "### Step 3/10: Install Python dependencies..."

cd "$APPDIR"
echo "Installing Python packages..."

PYTHON_BIN="$APPDIR/usr/bin/python3"
PIP_BIN="$APPDIR/usr/bin/python3 -m pip"
#CC=gcc
#CMAKE_CXX_COMPILER=gcc

$PIP_BIN install --no-cache-dir --upgrade pip setuptools wheel

CC="gcc" CMAKE_C_COMPILER="gcc" CMAKE_CXX_COMPILER="g++" CXX="g++" $PIP_BIN install --prefix=/usr --root=$APPDIR --no-cache-dir \
    https://gitlab.gnome.org/GNOME/pygobject/-/archive/3.50.2/pygobject-3.50.2.tar.gz \
    cssselect \
    curl_cffi \
    duckduckgo-search \
    edge-tts \
    expandvars \
    faiss-cpu \
    g4f==0.3.3.4 \
    gpt4all==2.8.2 \
    gtts==2.5.4 \
    livepng \
    llama-cpp-python \
    llama-index-core==0.12.38 \
    llama-index-readers-file \
    lxml \
    lxml-html-clean \
    markdownify \
    matplotlib \
    'mcp[cli]==1.25.0' \
    model2vec \
    newspaper3k \
    ollama \
    openai==1.84.0 \
    packaging \
    pillow \
    pyaudio \
    pydub \
    pygame \
    pylatexenc \
    python-dateutil \
    requests \
    requests-toolbelt \
    scikit-learn \
    six \
    speechrecognition \
    tiktoken \
    voicevox-client==0.4.1 \
    wordllama==0.3.9



######################################
# STEP 4: Assets and External Assets #
######################################

echo ""
echo "### Step 4/10: Downloading external assets..."

echo "No External Asset"


#######################################
# Step 5: Copy Icons and Desktop File #
#######################################

echo ""
echo "### Step 5/10: Preparing desktop file for AppImage..."
# Copy the installed desktop file to AppDir root
mkdir -p $APPDIR/usr/share/icons/hicolor/scalable/apps
cp "$APPDIR/usr/share/icons/hicolor/scalable/apps/io.github.qwersyk.Newelle.svg" "$APPDIR/"
cp "$APPDIR/usr/share/applications/io.github.qwersyk.Newelle.desktop" "$APPDIR/"

exit

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
#echo "  - GObject Introspection typelibs..."
#for typelib in Gtk-4.0 Adw-1 GtkSource-5 Vte-3.91 WebKit-6.0 GLib-2.0 GObject-2.0 Gio-2.0; do
#    find /usr/lib/x86_64-linux-gnu/girepository-1.0 -name "${typelib}.typelib" \
#        -exec cp {} "$APPDIR/usr/lib/girepository-1.0/" \; 2>/dev/null || true
#done
#find /usr/lib -name "libffi.so*"              -type f -exec cp {} $APPDIR/usr/lib/ \;
#find /usr/lib -name "libgirepository-1.0.so*" -type f -exec cp {} $APPDIR/usr/lib/ \;
#find /usr/lib -name "libgirepository-2.0.so*" -type f -exec cp {} $APPDIR/usr/lib/ \;


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

set -e

SELF=$(readlink -f "$0")
HERE=${SELF%/*}

echo "Starting Newelle AppImage" >&2
echo "   APPDIR: $HERE" >&2

# APPDIR for application path detection
export APPDIR="$HERE"

export PATH="$HERE/usr/lib/python/bin:\$PATH"

# Python environment
export PYTHONHOME="$HERE/usr/lib/python"
export PYTHONPATH="$HERE/usr/share/newelle:$HERE/usr/bin:$HERE/usr/lib/python/lib/python3.13/site-packages:${PYTHONPATH}"
export PYTHONUSERBASE="$HOME/.config/Newelle/pip"  # Runtime pip goes here

# GTK/GNOME runtime
export GDK_BACKEND=wayland,x11  # Wayland preferred, X11 fallback
export GI_TYPELIB_PATH="$HERE/usr/lib/girepository-1.0:${GI_TYPELIB_PATH}"
export LD_LIBRARY_PATH="$HERE/usr/lib:\$HERE/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH}"
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

# Execute application
exec "$HERE/usr/lib/python/bin/python3" "$HERE/usr/bin/newelle" "$@"
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

