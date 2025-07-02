#!/bin/bash
# Simple S906B Porting: system.img (port) + super.img (base) workflow
# Usage: ./gen_s906b_simple.sh <super.img> <system.img> <version>

export PATH=$(pwd)/bin:$(pwd)/bin/apktool:$PATH

# Script parameters
SUPER_IMG_BASE=$1      # Base super.img file
SYSTEM_IMG_PORT=$2     # Port system.img file  
VERSION=$3             # Output version
LOCALPATH=$(pwd)

# Source configurations
source "$LOCALPATH/configs/s906b_config.sh"
source "$LOCALPATH/bin/functions.sh"

# Display usage
show_usage() {
    echo "Simple S906B Porting Tool"
    echo "========================="
    echo "Usage: $0 <base_super.img> <port_system.img> <version>"
    echo ""
    echo "Parameters:"
    echo "  base_super.img   - Base super.img file (S906B compatible)"
    echo "  port_system.img  - System.img to port from"
    echo "  version         - Output ROM version"
    echo ""
    echo "Example:"
    echo "  $0 s906b_base_super.img s24_system.img v1.0"
    echo ""
    echo "This will:"
    echo "  1. Extract partitions from base super.img"
    echo "  2. Replace system partition with port system.img"
    echo "  3. Apply S906B optimizations"
    echo "  4. Create new super.img with ported system"
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

echo "🚀 S906B Simple Porting Started"
echo "================================"
echo "📦 Base super.img: $SUPER_IMG_BASE"
echo "📱 Port system.img: $SYSTEM_IMG_PORT"
echo "🏷️ Version: $VERSION"
echo ""

# Setup working directories
echo "🏗️ Setting up workspace..."
mkdir -p work/{base_extracted,system_work,output}

# Step 1: Extract base super.img
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
ls -lh *.img

cd "$LOCALPATH"

# Step 2: Process port system.img
echo "🛠️ Processing port system.img..."
cd work/system_work

# Extract port system.img
echo "📂 Extracting port system.img..."
if file "$LOCALPATH/$SYSTEM_IMG_PORT" | grep -q "EROFS"; then
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
        # Alternative extraction method would go here
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

# Create EROFS system.img
mkfs_cmd="mkfs.erofs -zlz4hc --ignore-mtime"
if [ -n "$file_contexts" ]; then
    mkfs_cmd="$mkfs_cmd --file-contexts=$file_contexts"
fi
mkfs_cmd="$mkfs_cmd system.img ../system_work/system_content/"

echo "🔨 Running: $mkfs_cmd"
eval "$mkfs_cmd"

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
echo "🎉 S906B Porting Completed Successfully!"
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
