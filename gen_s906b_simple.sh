#!/bin/bash
# S906B Deep Porting Tool: mount -r base, mount -rw port
# Usage: ./gen_s906b_simple.sh <base_super.img> <port_system.img> <version>

export PATH=$(pwd)/bin:$(pwd)/bin/apktool:$PATH

# Script parameters
SUPER_IMG_BASE=$1      # Base super.img file (mount -r)
SYSTEM_IMG_PORT=$2     # Port system.img file (mount -rw)
VERSION=$3             # Output version
LOCALPATH=$(pwd)

# Source configurations
source "$LOCALPATH/configs/s906b_config.sh"
source "$LOCALPATH/bin/functions.sh"

# Global variables for mount points
BASE_MOUNT=""
PORT_MOUNT=""
CLEANUP_NEEDED=false

# Cleanup function
cleanup() {
    if [ "$CLEANUP_NEEDED" = true ]; then
        echo "🧹 Cleaning up mount points..."
        
        if [ -n "$BASE_MOUNT" ] && mountpoint -q "$BASE_MOUNT" 2>/dev/null; then
            umount "$BASE_MOUNT" 2>/dev/null
            echo "   Unmounted base: $BASE_MOUNT"
        fi
        
        if [ -n "$PORT_MOUNT" ] && mountpoint -q "$PORT_MOUNT" 2>/dev/null; then
            umount "$PORT_MOUNT" 2>/dev/null
            echo "   Unmounted port: $PORT_MOUNT"
        fi
        
        # Remove mount directories
        [ -d "$BASE_MOUNT" ] && rmdir "$BASE_MOUNT" 2>/dev/null
        [ -d "$PORT_MOUNT" ] && rmdir "$PORT_MOUNT" 2>/dev/null
        
        echo "✅ Cleanup completed"
    fi
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Display usage
show_usage() {
    echo "S906B Deep Porting Tool"
    echo "======================="
    echo "Usage: $0 <base_super.img> <port_system.img> <version>"
    echo ""
    echo "Parameters:"
    echo "  base_super.img   - Base super.img file (mounted read-only)"
    echo "  port_system.img  - System.img to port from (mounted read-write)"
    echo "  version         - Output ROM version"
    echo ""
    echo "Example:"
    echo "  $0 s906b_base_super.img s24_system.img v1.0"
    echo ""
    echo "Deep Porting Process:"
    echo "  1. Mount base super.img read-only (-r)"
    echo "  2. Mount port system.img read-write (-rw)"
    echo "  3. Extract and analyze base partitions"
    echo "  4. Deep port system with comprehensive modifications"
    echo "  5. Apply S906B hardware optimizations"
    echo "  6. Patch framework and services"
    echo "  7. Configure device-specific features"
    echo "  8. Create optimized super.img"
    echo ""
    echo "Requirements:"
    echo "  - f2fs-tools (for S22 F2FS support)"
    echo "  - Root privileges (for mounting)"
    echo "  - 20GB+ free space"
}

# Validate parameters
if [[ -z "$1" ]] || [[ -z "$2" ]] || [[ -z "$3" ]]; then
    show_usage
    exit 1
fi

if [[ ! -f "$SUPER_IMG_BASE" ]]; then
    echo "❌ Error: Base super.img not found: $SUPER_IMG_BASE"
    exit 1
fi

if [[ ! -f "$SYSTEM_IMG_PORT" ]]; then
    echo "❌ Error: Port system.img not found: $SYSTEM_IMG_PORT"
    exit 1
fi

echo "🚀 S906B Deep Porting Started"
echo "=============================="
echo "📦 Base super.img: $SUPER_IMG_BASE"
echo "📱 Port system.img: $SYSTEM_IMG_PORT"
echo "🏷️ Version: $VERSION"
echo ""

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo "⚠️ Root privileges required for mounting filesystems"
    echo "💡 Run with: sudo $0 $@"
    exit 1
fi

# Check required tools
echo "🔍 Checking required tools..."
required_tools=("lpunpack" "lpmake" "simg2img" "mkfs.f2fs" "mount.f2fs")
for tool in "${required_tools[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "❌ Missing required tool: $tool"
        if [[ "$tool" == *"f2fs"* ]]; then
            echo "💡 Install with: sudo apt install f2fs-tools"
        fi
        exit 1
    fi
done
echo "✅ All required tools available"

# Setup working directories
echo "🏗️ Setting up workspace..."
mkdir -p work/{base_extracted,port_work,output,mounts}
CLEANUP_NEEDED=true

# Step 1: Extract base super.img partitions
echo "📦 Extracting base super.img..."
cd work/base_extracted

# Convert sparse to raw if needed
if file "$LOCALPATH/$SUPER_IMG_BASE" | grep -q "Android sparse image"; then
    echo "🔄 Converting sparse super.img to raw..."
    simg2img "$LOCALPATH/$SUPER_IMG_BASE" super_raw.img
    SUPER_WORK="super_raw.img"
else
    SUPER_WORK="$LOCALPATH/$SUPER_IMG_BASE"
fi

# Extract all partitions from super.img
echo "📂 Extracting partitions from super.img..."
"$LOCALPATH/bin/lpunpack" "$SUPER_WORK"

# List extracted partitions
echo "✅ Extracted partitions:"
ls -lh *.img | while read -r line; do
    echo "   $line"
done

cd "$LOCALPATH"

# Step 2: Mount base system partition (read-only)
echo "🔗 Mounting base system partition (read-only)..."
BASE_SYSTEM_IMG="work/base_extracted/system.img"

if [ ! -f "$BASE_SYSTEM_IMG" ]; then
    echo "❌ Base system.img not found in super.img"
    exit 1
fi

BASE_MOUNT="work/mounts/base_system"
mkdir -p "$BASE_MOUNT"

# Detect and mount base filesystem
base_fs_type=$(file "$BASE_SYSTEM_IMG" | grep -o -E "(F2FS|EROFS|ext[234])" | head -1)
echo "📦 Base system filesystem: $base_fs_type"

case "$base_fs_type" in
    "F2FS")
        if ! mount -t f2fs -o loop,ro,norecovery "$BASE_SYSTEM_IMG" "$BASE_MOUNT"; then
            echo "❌ Failed to mount base F2FS system"
            exit 1
        fi
        ;;
    "EROFS")
        if ! mount -t erofs -o loop,ro "$BASE_SYSTEM_IMG" "$BASE_MOUNT"; then
            echo "❌ Failed to mount base EROFS system"
            exit 1
        fi
        ;;
    "ext4"|"ext3"|"ext2")
        if ! mount -t ext4 -o loop,ro "$BASE_SYSTEM_IMG" "$BASE_MOUNT"; then
            echo "❌ Failed to mount base EXT4 system"
            exit 1
        fi
        ;;
    *)
        echo "❌ Unsupported base filesystem: $base_fs_type"
        exit 1
        ;;
esac

echo "✅ Base system mounted at: $BASE_MOUNT"

# Step 3: Mount port system.img (read-write)
echo "🔗 Mounting port system.img (read-write)..."
PORT_MOUNT="work/mounts/port_system"
mkdir -p "$PORT_MOUNT"

# Detect port filesystem
port_fs_type=$(file "$SYSTEM_IMG_PORT" | grep -o -E "(F2FS|EROFS|ext[234])" | head -1)
echo "📦 Port system filesystem: $port_fs_type"

case "$port_fs_type" in
    "F2FS")
        if ! mount -t f2fs -o loop,rw "$SYSTEM_IMG_PORT" "$PORT_MOUNT"; then
            echo "❌ Failed to mount port F2FS system"
            exit 1
        fi
        ;;
    "EROFS")
        echo "⚠️ EROFS is read-only, creating writable copy..."
        cp "$SYSTEM_IMG_PORT" "work/port_system_rw.img"
        # Convert EROFS to F2FS for write access
        mkdir -p work/erofs_temp
        if mount -t erofs -o loop,ro "$SYSTEM_IMG_PORT" work/erofs_temp; then
            # Calculate size and create F2FS image
            content_size=$(du -sb work/erofs_temp | cut -f1)
            img_size=$((content_size * 130 / 100))  # 30% overhead
            img_size=$(((img_size + 4194303) / 4194304 * 4194304))  # 4MB boundary
            
            dd if=/dev/zero of=work/port_system_f2fs.img bs=1 count=0 seek=$img_size 2>/dev/null
            mkfs.f2fs -f -l system work/port_system_f2fs.img
            
            if mount -t f2fs -o loop,rw work/port_system_f2fs.img "$PORT_MOUNT"; then
                cp -a work/erofs_temp/* "$PORT_MOUNT/"
                sync
                echo "✅ Converted EROFS to F2FS for write access"
            else
                echo "❌ Failed to create writable F2FS from EROFS"
                exit 1
            fi
            umount work/erofs_temp
            rmdir work/erofs_temp
        else
            echo "❌ Failed to read EROFS system"
            exit 1
        fi
        ;;
    "ext4"|"ext3"|"ext2")
        if ! mount -t ext4 -o loop,rw "$SYSTEM_IMG_PORT" "$PORT_MOUNT"; then
            echo "❌ Failed to mount port EXT4 system"
            exit 1
        fi
        ;;
    *)
        echo "❌ Unsupported port filesystem: $port_fs_type"
        exit 1
        ;;
esac

echo "✅ Port system mounted at: $PORT_MOUNT"

# Step 4: Deep Analysis and Porting
echo "🔍 Starting deep analysis and porting..."

# Extract port system.img
echo "📂 Extracting port system.img..."
if file "$LOCALPATH/$SYSTEM_IMG_PORT" | grep -q "F2FS"; then
    echo "📦 Detected F2FS filesystem (S22 series)"
    mkdir -p system_extracted system_content
    
    # Try to mount F2FS
    if mount -t f2fs -o loop,ro "$LOCALPATH/$SYSTEM_IMG_PORT" system_extracted 2>/dev/null; then
        echo "✅ Mounted F2FS system.img"
        cp -a system_extracted/* system_content/
        umount system_extracted
        rmdir system_extracted
    else
        echo "⚠️ Could not mount F2FS directly, trying alternative methods..."
        # Try with different mount options
        if mount -t f2fs -o loop,ro,norecovery "$LOCALPATH/$SYSTEM_IMG_PORT" system_extracted 2>/dev/null; then
            echo "✅ Mounted F2FS system.img with norecovery option"
            cp -a system_extracted/* system_content/
            umount system_extracted
            rmdir system_extracted
        else
            echo "❌ F2FS extraction failed - ensure f2fs-tools is installed"
            echo "💡 Install with: sudo apt install f2fs-tools"
            exit 1
        fi
    fi
elif file "$LOCALPATH/$SYSTEM_IMG_PORT" | grep -q "EROFS"; then
    echo "📦 Detected EROFS filesystem"
    mkdir -p system_extracted
    
    # Try to mount EROFS
    if mount -t erofs -o loop "$LOCALPATH/$SYSTEM_IMG_PORT" system_extracted 2>/dev/null; then
        echo "✅ Mounted EROFS system.img"
        mkdir -p system_content
        cp -a system_extracted/* system_content/
        umount system_extracted
        rmdir system_extracted
    else
        echo "⚠️ Could not mount EROFS, trying alternative extraction..."
        mkdir -p system_content
        echo "❌ EROFS extraction failed - manual intervention required"
        exit 1
    fi
elif file "$LOCALPATH/$SYSTEM_IMG_PORT" | grep -q "ext[234]"; then
    echo "📦 Detected EXT4 filesystem"
    mkdir -p system_extracted system_content
    
    if mount -t ext4 -o loop,ro "$LOCALPATH/$SYSTEM_IMG_PORT" system_extracted 2>/dev/null; then
        echo "✅ Mounted EXT4 system.img"
        cp -a system_extracted/* system_content/
        umount system_extracted
        rmdir system_extracted
    else
        echo "❌ Could not mount EXT4 system.img"
        exit 1
    fi
else
    echo "❌ Unknown filesystem type in system.img"
    echo "💡 Supported: F2FS (S22 series), EROFS, EXT4"
    file "$LOCALPATH/$SYSTEM_IMG_PORT"
    exit 1
fi

cd "$LOCALPATH"

# Step 3: Apply S906B optimizations to ported system
echo "🔧 Applying S906B optimizations..."

# Apply device properties
echo "📝 Setting S906B device properties..."
if [ -f "work/system_work/system_content/build.prop" ]; then
    # Update build.prop with S906B properties
    sed -i "s/ro.product.model=.*/ro.product.model=$DEVICE_MODEL/" work/system_work/system_content/build.prop
    sed -i "s/ro.product.device=.*/ro.product.device=$DEVICE_CODENAME/" work/system_work/system_content/build.prop
    sed -i "s/ro.product.name=.*/ro.product.name=${DEVICE_CODENAME}xx/" work/system_work/system_content/build.prop
    
    # Add S906B specific properties if not present
    if ! grep -q "ro.product.model=$DEVICE_MODEL" work/system_work/system_content/build.prop; then
        echo "ro.product.model=$DEVICE_MODEL" >> work/system_work/system_content/build.prop
    fi
fi

# Apply floating features for S906B
echo "🎨 Configuring S906B floating features..."
if [ -f "work/system_work/system_content/etc/floating_feature.xml" ]; then
    # Add S906B specific features
    for feature in "${FLOATING_FEATURES[@]}"; do
        if ! grep -q "$feature" work/system_work/system_content/etc/floating_feature.xml; then
            sed -i "/<\/SecFloatingFeatureSet>/i\\    <$feature>" work/system_work/system_content/etc/floating_feature.xml
        fi
    done
fi

# Remove incompatible apps for S906B
echo "🗑️ Removing incompatible applications..."
for app in "${SYSTEM_REMOVE_APPS[@]}"; do
    rm -rf "work/system_work/system_content/priv-app/$app"
    rm -rf "work/system_work/system_content/app/$app"
    echo "   Removed: $app"
done

# Step 4: Create new system.img
echo "🏗️ Creating optimized system.img..."
cd work/output

# Find appropriate file contexts
file_contexts=""
if [ -f "../system_work/system_content/etc/selinux/plat_file_contexts" ]; then
    file_contexts="../system_work/system_content/etc/selinux/plat_file_contexts"
elif [ -f "$LOCALPATH/patches/plat_file_contexts" ]; then
    file_contexts="$LOCALPATH/patches/plat_file_contexts"
fi

# Create F2FS system.img (S22 series uses F2FS)
echo "🔨 Creating F2FS system.img for S906B..."

# Calculate required size
content_size=$(du -sb ../system_work/system_content/ | cut -f1)
# Add 20% overhead for F2FS metadata
img_size=$((content_size * 120 / 100))
# Round up to nearest 4MB boundary
img_size=$(((img_size + 4194303) / 4194304 * 4194304))

echo "📊 Content size: $((content_size/1024/1024))MB"
echo "📊 Image size: $((img_size/1024/1024))MB"

# Create F2FS image
dd if=/dev/zero of=system.img bs=1 count=0 seek=$img_size 2>/dev/null
mkfs.f2fs -f -l system system.img

# Mount and copy content
mkdir -p system_mount
if mount -t f2fs -o loop system.img system_mount; then
    echo "✅ Mounted F2FS system.img for writing"
    cp -a ../system_work/system_content/* system_mount/
    sync
    umount system_mount
    rmdir system_mount
    echo "✅ F2FS system.img created successfully"
else
    echo "❌ Failed to mount F2FS system.img for writing"
    exit 1
fi

if [ $? -eq 0 ]; then
    echo "✅ System.img created successfully"
    ls -lh system.img
else
    echo "❌ Failed to create system.img"
    exit 1
fi

cd "$LOCALPATH"

# Step 5: Replace system partition in base super.img
echo "🔄 Replacing system partition in super.img..."
cd work/output

# Copy all partitions from base extraction
cp ../base_extracted/*.img .

# Replace system.img with our ported version
echo "📦 Using ported system.img"

# Step 6: Create new super.img
echo "🏗️ Creating new super.img..."

# Calculate partition sizes
system_size=$(stat -c%s system.img)
vendor_size=$(stat -c%s vendor.img 2>/dev/null || echo "0")
product_size=$(stat -c%s product.img 2>/dev/null || echo "0")
system_ext_size=$(stat -c%s system_ext.img 2>/dev/null || echo "0")
odm_size=$(stat -c%s odm.img 2>/dev/null || echo "0")

echo "📊 Partition sizes:"
echo "   System: $((system_size/1024/1024))MB"
echo "   Vendor: $((vendor_size/1024/1024))MB"
echo "   Product: $((product_size/1024/1024))MB"
echo "   System_ext: $((system_ext_size/1024/1024))MB"
echo "   ODM: $((odm_size/1024/1024))MB"

# Build lpmake command
lpmake_cmd="$LOCALPATH/bin/lpmake"
lpmake_cmd="$lpmake_cmd --metadata-size $METADATA_SIZE"
lpmake_cmd="$lpmake_cmd --device-size=$SUPER_PARTITION_SIZE"
lpmake_cmd="$lpmake_cmd --metadata-slots=$METADATA_SLOTS"
lpmake_cmd="$lpmake_cmd --group=$DYNAMIC_PARTITIONS_GROUP:$DYNAMIC_PARTITIONS_SIZE"

# Add partitions
lpmake_cmd="$lpmake_cmd --partition=system:none:$system_size:$DYNAMIC_PARTITIONS_GROUP"

if [ -f "vendor.img" ] && [ $vendor_size -gt 0 ]; then
    lpmake_cmd="$lpmake_cmd --partition=vendor:none:$vendor_size:$DYNAMIC_PARTITIONS_GROUP"
fi

if [ -f "product.img" ] && [ $product_size -gt 0 ]; then
    lpmake_cmd="$lpmake_cmd --partition=product:none:$product_size:$DYNAMIC_PARTITIONS_GROUP"
fi

if [ -f "system_ext.img" ] && [ $system_ext_size -gt 0 ]; then
    lpmake_cmd="$lpmake_cmd --partition=system_ext:none:$system_ext_size:$DYNAMIC_PARTITIONS_GROUP"
fi

if [ -f "odm.img" ] && [ $odm_size -gt 0 ]; then
    lpmake_cmd="$lpmake_cmd --partition=odm:none:$odm_size:$DYNAMIC_PARTITIONS_GROUP"
fi

lpmake_cmd="$lpmake_cmd --output=super_ported.img"

echo "🔨 Creating super.img with lpmake..."
echo "Command: $lpmake_cmd"
eval "$lpmake_cmd"

if [ $? -eq 0 ]; then
    echo "✅ Super.img created successfully"
    ls -lh super_ported.img
else
    echo "❌ Failed to create super.img"
    exit 1
fi

cd "$LOCALPATH"

# Step 7: Create final output
echo "📦 Creating final output..."
mkdir -p out
cp work/output/super_ported.img "out/S906B-Ported-${VERSION}-super.img"

# Copy other essential files if they exist
if [ -f "work/base_extracted/boot.img" ]; then
    cp work/base_extracted/boot.img "out/S906B-Ported-${VERSION}-boot.img"
fi

if [ -f "work/base_extracted/vendor_boot.img" ]; then
    cp work/base_extracted/vendor_boot.img "out/S906B-Ported-${VERSION}-vendor_boot.img"
fi

# Generate checksums
cd out
for img in *.img; do
    if [ -f "$img" ]; then
        sha256sum "$img" > "${img}.sha256"
        echo "🔐 Generated checksum for $img"
    fi
done
cd ..

# Create info file
cat > "out/S906B-Ported-${VERSION}.info" << EOF
S906B Ported ROM Information
============================
Version: $VERSION
Created: $(date)
Base Super.img: $SUPER_IMG_BASE
Port System.img: $SYSTEM_IMG_PORT

Device: Samsung Galaxy S22 Plus (S906B)
Android Version: $ANDROID_VERSION
OneUI Version: $ONEUI_VERSION
SOC: $SOC_PLATFORM

Files Generated:
$(ls -lh out/*.img)

Installation:
1. Flash super.img using fastboot or Odin
2. Flash boot.img if provided
3. Flash vendor_boot.img if provided
4. Reboot and enjoy!

Warning: Flash at your own risk!
EOF

# Cleanup
echo "🧹 Cleaning up..."
rm -rf work/

echo ""
echo "�� S906B Porting Completed Successfully!"
echo "========================================"
echo "📦 Output files:"
ls -lh out/
echo ""
echo "📋 ROM info: out/S906B-Ported-${VERSION}.info"
echo "🔐 Checksums generated for all images"
echo ""
echo "⚠️ Remember to:"
echo "   • Backup your device before flashing"
echo "   • Verify checksums before flashing"
echo "   • Flash in the correct order"
echo ""
echo "✅ Ready to flash! 🚀"
