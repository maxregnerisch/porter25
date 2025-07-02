# Workflow Examples

This document provides practical examples of common workflows using the S906B enhanced porting tool.

## Table of Contents

1. [Basic Porting Workflows](#basic-porting-workflows)
2. [Enhanced Processing Workflows](#enhanced-processing-workflows)
3. [Reverse Porting Workflows](#reverse-porting-workflows)
4. [Custom Modification Workflows](#custom-modification-workflows)
5. [Troubleshooting Workflows](#troubleshooting-workflows)

## Basic Porting Workflows

### Example 1: Standard S24 to S906B Port

**Scenario**: Porting Samsung Galaxy S24 OneUI 6 ROM to Galaxy S22 Plus (S906B)

```bash
# 1. Prepare files
# - S906B_Base_OneUI6.zip (base firmware)
# - S24_OneUI6_Source.zip (source ROM)
# - OneUI6_Update.zip (update package)

# 2. Execute basic porting
./gen_s906b.sh S906B_Base_OneUI6.zip S24_OneUI6_Source.zip OneUI6_Update.zip v1.0

# 3. Expected output
# out/S906B-OneUI6-basic-v1.0.zip
# out/S906B-OneUI6-basic-v1.0.zip.info
# out/S906B-OneUI6-basic-v1.0.zip.sha256
```

**Features included:**
- 64-bit only vendor
- S906B device properties
- Dolby Atmos support
- Camera optimizations
- Performance tweaks

### Example 2: Cross-Device Porting (S23 Ultra to S906B)

**Scenario**: Porting S23 Ultra features to S906B with compatibility adjustments

```bash
# 1. Download required files
# - S906B_Base.zip
# - S23Ultra_Source.zip

# 2. Execute with enhanced mode for better compatibility
./gen_s906b.sh S906B_Base.zip S23Ultra_Source.zip - v1.0 enhanced

# 3. Review compatibility warnings
cat analysis/stock/compatibility_report.txt
```

**Special considerations:**
- Display resolution differences
- Hardware feature variations
- S-Pen related features (will be disabled)

### Example 3: Quick Update Port

**Scenario**: Applying security update to existing custom ROM

```bash
# 1. Prepare files
# - Current_Custom_ROM.zip
# - Security_Update.zip

# 2. Execute basic port
./gen_s906b.sh Current_Custom_ROM.zip Current_Custom_ROM.zip Security_Update.zip v1.1

# 3. Verify security patch level
unzip -p out/S906B-OneUI6-basic-v1.1.zip system.img | \
  strings | grep "ro.build.version.security_patch"
```

## Enhanced Processing Workflows

### Example 4: Deep System Analysis and Optimization

**Scenario**: Creating highly optimized ROM with detailed analysis

```bash
# 1. Execute enhanced porting
./gen_s906b.sh S906B_Base.zip S24_Source.zip Update.zip v2.0 enhanced

# 2. Review analysis reports
echo "=== Super.img Analysis ==="
cat analysis/port/super_analysis/partition_layout.txt

echo "=== System.img Analysis ==="
cat analysis/port/system_analysis/apk_list.txt | wc -l
echo "APKs found"

echo "=== OneUI Files ==="
cat analysis/port/system_analysis/oneui_files.txt | head -10

# 3. Check optimization results
ls -lh out/S906B-OneUI6-enhanced-v2.0.zip
```

**Enhanced features:**
- Detailed partition analysis
- Optimized super.img creation
- System.img validation
- Performance profiling

### Example 5: Custom Partition Layout

**Scenario**: Creating ROM with modified partition sizes

```bash
# 1. Analyze current partition usage
./bin/super_manager.sh analyze S906B_Base_super.img analysis/

# 2. Create custom partition modification
cat > custom_partitions.txt << EOF
RESIZE:system:7G
RESIZE:vendor:1.5G
RESIZE:product:800M
EOF

# 3. Extract and modify super.img
./bin/super_manager.sh extract S906B_Base_super.img extracted/ all raw
./bin/super_manager.sh modify extracted/super.img custom_partitions.txt custom_super.img

# 4. Use in enhanced porting
# (Replace super.img in base ROM with custom_super.img)
./gen_s906b.sh Modified_Base.zip Source.zip - v2.0 enhanced
```

### Example 6: Selective System Processing

**Scenario**: Extracting only specific components from source ROM

```bash
# 1. Extract only Samsung apps from source
./bin/system_processor.sh extract Source_system.img samsung_apps/ selective "*samsung*"

# 2. Extract camera-related files
./bin/system_processor.sh extract Source_system.img camera_files/ selective "*camera*"

# 3. Create modification package
mkdir -p modifications/overlay/priv-app/
cp -r samsung_apps/* modifications/overlay/priv-app/
cp -r camera_files/* modifications/overlay/

# 4. Apply to base system
./bin/system_processor.sh modify Base_system.img modifications/ modified_system.img lz4hc

# 5. Integrate into ROM
# (Replace system.img in base ROM)
```

## Reverse Porting Workflows

### Example 7: Feature Extraction from Custom ROM

**Scenario**: Extracting useful features from LineageOS for S906B

```bash
# 1. Analyze LineageOS ROM for features
./bin/reverse_porter.sh analyze LineageOS_ROM/ analysis/lineage/ S906B_Stock/

# 2. Review detected features
echo "=== Detected Features ==="
cat analysis/lineage/detected_features.txt

echo "=== Detected Modifications ==="
cat analysis/lineage/detected_modifications.txt

# 3. Create selective feature list
cat > wanted_features.txt << EOF
custom_launcher
privacy_mods
performance_mods
custom_themes
EOF

# 4. Extract selected features
./bin/reverse_porter.sh extract LineageOS_ROM/ wanted_features.txt extracted_features/ copy

# 5. Apply to S906B ROM
./bin/reverse_porter.sh apply S906B_Base/ extracted_features/extracted_features/ "" backup/

# 6. Create final ROM
./gen_s906b.sh Modified_S906B_Base.zip S906B_Base.zip - v3.0
```

### Example 8: Cross-ROM Feature Porting

**Scenario**: Porting Pixel camera features to S906B

```bash
# 1. Analyze Pixel ROM
./bin/reverse_porter.sh analyze Pixel_ROM/ analysis/pixel/

# 2. Extract camera features
echo "custom_camera" > camera_features.txt
./bin/reverse_porter.sh extract Pixel_ROM/ camera_features.txt pixel_camera/ package

# 3. Create application configuration
cat > camera_config.txt << EOF
APPLY:custom_camera:system/priv-app
EOF

# 4. Apply to S906B
./bin/reverse_porter.sh apply S906B_Base/ pixel_camera/extracted_features/ camera_config.txt backup/

# 5. Test compatibility
./bin/system_processor.sh validate Modified_S906B/system.img
```

### Example 9: Multi-ROM Feature Combination

**Scenario**: Combining features from multiple custom ROMs

```bash
# 1. Extract launcher from ROM A
echo "custom_launcher" > launcher.txt
./bin/reverse_porter.sh extract ROM_A/ launcher.txt features_a/ copy

# 2. Extract audio enhancements from ROM B
echo "audio_enhancements" > audio.txt
./bin/reverse_porter.sh extract ROM_B/ audio.txt features_b/ copy

# 3. Extract performance mods from ROM C
echo "performance_mods" > performance.txt
./bin/reverse_porter.sh extract ROM_C/ performance.txt features_c/ copy

# 4. Combine all features
mkdir -p combined_features/extracted_features/
cp -r features_a/extracted_features/* combined_features/extracted_features/
cp -r features_b/extracted_features/* combined_features/extracted_features/
cp -r features_c/extracted_features/* combined_features/extracted_features/

# 5. Apply combined features
./bin/reverse_porter.sh apply S906B_Base/ combined_features/extracted_features/ "" backup/

# 6. Create final ROM
./gen_s906b.sh Modified_S906B_Base.zip S906B_Base.zip - v4.0
```

## Custom Modification Workflows

### Example 10: Debloating Workflow

**Scenario**: Creating a debloated S906B ROM

```bash
# 1. Create removal list
cat > debloat_remove.txt << EOF
# Social media apps
priv-app/Facebook
app/Instagram
app/WhatsApp

# Carrier bloatware
app/MyVerizon
app/VZMessages

# Unused Samsung apps
app/SamsungMembers
app/SmartThings
app/SamsungNotes

# Google apps (optional)
app/YouTube
app/GooglePlay*
priv-app/Gmail
EOF

# 2. Create modification structure
mkdir -p debloat_mods/
cp debloat_remove.txt debloat_mods/remove.txt

# 3. Extract and modify system
./bin/system_processor.sh extract S906B_system.img work/ full
./bin/system_processor.sh modify S906B_system.img debloat_mods/ debloated_system.img lz4hc

# 4. Validate debloated system
./bin/system_processor.sh validate debloated_system.img

# 5. Create debloated ROM
# (Replace system.img in base ROM)
./gen_s906b.sh Debloated_Base.zip S906B_Base.zip - v1.0-debloated
```

### Example 11: Custom Boot Animation

**Scenario**: Adding custom boot animation to S906B ROM

```bash
# 1. Prepare custom boot animation
# Create bootanimation.zip with custom animation

# 2. Create modification overlay
mkdir -p custom_boot/overlay/media/
cp custom_bootanimation.zip custom_boot/overlay/media/bootanimation.zip

# 3. Apply modification
./bin/system_processor.sh modify S906B_system.img custom_boot/ custom_system.img lz4hc

# 4. Create ROM with custom boot animation
# (Replace system.img in base ROM)
./gen_s906b.sh Custom_Boot_Base.zip S906B_Base.zip - v1.0-custom-boot
```

### Example 12: Performance Optimization Workflow

**Scenario**: Creating performance-optimized S906B ROM

```bash
# 1. Create performance optimization script
cat > perf_optimization.sh << '#!/bin/bash
# Remove performance-limiting apps
rm -rf priv-app/PowerSaving*
rm -rf app/AdaptiveBrightness*

# Optimize build.prop
echo "ro.config.low_ram=false" >> build.prop
echo "ro.config.zram=true" >> build.prop
echo "dalvik.vm.heapsize=512m" >> build.prop

# Enable performance governor
mkdir -p etc/init.d/
cat > etc/init.d/99performance << "EOF"
#!/system/bin/sh
echo performance > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo performance > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
EOF
chmod 755 etc/init.d/99performance
EOF

# 2. Create modification package
mkdir -p perf_mods/
cp perf_optimization.sh perf_mods/custom_script.sh
chmod +x perf_mods/custom_script.sh

# 3. Apply performance modifications
./bin/system_processor.sh modify S906B_system.img perf_mods/ perf_system.img lz4hc

# 4. Create performance ROM
./gen_s906b.sh Perf_Base.zip S906B_Base.zip - v1.0-performance enhanced
```

## Troubleshooting Workflows

### Example 13: Boot Loop Recovery

**Scenario**: ROM boots but gets stuck in boot loop

```bash
# 1. Analyze the problematic ROM
./bin/system_processor.sh analyze problematic_system.img analysis/problem/

# 2. Compare with working ROM
./bin/reverse_porter.sh compare problematic_rom/ working_rom/ analysis/comparison/

# 3. Check for missing essential files
echo "=== Missing Essential Files ==="
diff analysis/problem/apk_list.txt analysis/working/apk_list.txt

# 4. Extract essential files from working ROM
./bin/system_processor.sh extract working_system.img essential_files/ selective "*framework*"

# 5. Create fix modification
mkdir -p bootloop_fix/overlay/
cp -r essential_files/* bootloop_fix/overlay/

# 6. Apply fix
./bin/system_processor.sh modify problematic_system.img bootloop_fix/ fixed_system.img lz4hc

# 7. Create fixed ROM
./gen_s906b.sh Fixed_Base.zip Working_Base.zip - v1.0-fixed
```

### Example 14: Camera Not Working Fix

**Scenario**: Camera app crashes or doesn't work after porting

```bash
# 1. Extract camera-related files from working stock ROM
./bin/system_processor.sh extract stock_system.img camera_fix/ selective "*camera*"

# 2. Extract camera libraries
find stock_vendor/ -name "*camera*" -type f > camera_libs.txt
find stock_vendor/ -name "*snap*" -type f >> camera_libs.txt

# 3. Create camera fix package
mkdir -p camera_fix_mod/overlay/
cp -r camera_fix/* camera_fix_mod/overlay/

# Copy vendor libraries to system
mkdir -p camera_fix_mod/overlay/lib64/
while read lib; do
    cp "$lib" camera_fix_mod/overlay/lib64/
done < camera_libs.txt

# 4. Apply camera fix
./bin/system_processor.sh modify broken_system.img camera_fix_mod/ fixed_system.img lz4hc

# 5. Test camera functionality
# Flash and test camera app
```

### Example 15: Partition Size Issues

**Scenario**: System partition too small for ported ROM

```bash
# 1. Analyze current partition usage
./bin/super_manager.sh analyze current_super.img analysis/size/

# 2. Check system size requirements
du -sh ported_system/
echo "Current system partition size:"
grep "system" analysis/size/partition_layout.txt

# 3. Create resized partition layout
cat > resize_partitions.txt << EOF
RESIZE:system:8G
RESIZE:vendor:1.8G
RESIZE:product:900M
EOF

# 4. Apply partition resize
./bin/super_manager.sh extract current_super.img extracted/ all raw
./bin/super_manager.sh modify extracted/super.img resize_partitions.txt resized_super.img

# 5. Validate new layout
./bin/super_manager.sh validate resized_super.img

# 6. Use resized super.img in ROM
# (Replace super.img in base ROM)
```

## Advanced Automation Workflows

### Example 16: Automated Testing Pipeline

**Scenario**: Automated ROM building and testing

```bash
#!/bin/bash
# automated_build.sh

# Configuration
BASE_ROM="S906B_Base.zip"
SOURCE_ROM="S24_Source.zip"
UPDATE_ZIP="OneUI6_Update.zip"
VERSION="auto-$(date +%Y%m%d)"

# 1. Build ROM
echo "Building ROM version $VERSION..."
./gen_s906b.sh "$BASE_ROM" "$SOURCE_ROM" "$UPDATE_ZIP" "$VERSION" enhanced

# 2. Validate output
if [ -f "out/S906B-OneUI6-enhanced-$VERSION.zip" ]; then
    echo "✅ ROM built successfully"
    
    # 3. Run integrity checks
    echo "Running integrity checks..."
    unzip -t "out/S906B-OneUI6-enhanced-$VERSION.zip" > /dev/null
    if [ $? -eq 0 ]; then
        echo "✅ ROM archive integrity OK"
    else
        echo "❌ ROM archive corrupted"
        exit 1
    fi
    
    # 4. Check file sizes
    ROM_SIZE=$(stat -c%s "out/S906B-OneUI6-enhanced-$VERSION.zip")
    if [ $ROM_SIZE -gt 3000000000 ] && [ $ROM_SIZE -lt 8000000000 ]; then
        echo "✅ ROM size acceptable: $(($ROM_SIZE/1024/1024))MB"
    else
        echo "⚠️ ROM size unusual: $(($ROM_SIZE/1024/1024))MB"
    fi
    
    # 5. Generate build report
    cat > "out/build_report_$VERSION.txt" << EOF
Build Report - $VERSION
========================
Build Date: $(date)
Base ROM: $BASE_ROM
Source ROM: $SOURCE_ROM
Update ZIP: $UPDATE_ZIP
ROM Size: $(($ROM_SIZE/1024/1024))MB
SHA256: $(sha256sum "out/S906B-OneUI6-enhanced-$VERSION.zip" | cut -d' ' -f1)

Build Status: SUCCESS
EOF
    
    echo "✅ Build completed successfully"
    echo "📦 ROM: out/S906B-OneUI6-enhanced-$VERSION.zip"
    echo "📋 Report: out/build_report_$VERSION.txt"
    
else
    echo "❌ ROM build failed"
    exit 1
fi
```

### Example 17: Batch Processing Multiple ROMs

**Scenario**: Processing multiple ROM variants

```bash
#!/bin/bash
# batch_process.sh

# ROM configurations
declare -A ROMS=(
    ["s24_basic"]="S24_Source.zip basic"
    ["s24_enhanced"]="S24_Source.zip enhanced"
    ["s23_ultra"]="S23Ultra_Source.zip enhanced"
    ["pixel_reverse"]="Pixel_Source.zip reverse"
)

BASE_ROM="S906B_Base.zip"
UPDATE_ZIP="OneUI6_Update.zip"

for rom_name in "${!ROMS[@]}"; do
    echo "Processing $rom_name..."
    
    # Parse configuration
    config=(${ROMS[$rom_name]})
    source_rom="${config[0]}"
    mode="${config[1]}"
    
    # Build ROM
    ./gen_s906b.sh "$BASE_ROM" "$source_rom" "$UPDATE_ZIP" "v1.0-$rom_name" "$mode"
    
    # Check result
    if [ $? -eq 0 ]; then
        echo "✅ $rom_name completed successfully"
    else
        echo "❌ $rom_name failed"
    fi
    
    echo "---"
done

echo "Batch processing completed"
ls -lh out/
```

These workflow examples demonstrate the flexibility and power of the S906B enhanced porting tool. Each example can be adapted to specific requirements and combined to create complex custom ROM development workflows.

