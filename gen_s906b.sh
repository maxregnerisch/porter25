#!/bin/bash
# Enhanced S906B (Galaxy S22 Plus) Android 15 OneUI 6 Porting Script
# Deep porting with super.img and system.img manipulation capabilities

export PATH=$(pwd)/bin:$(pwd)/bin/apktool:$PATH

# Script parameters
BASEROMZIP=$1
PORTROMZIP=$2
UPDATEZIP=$3
VERSION=$4
OPERATION_MODE=$5  # "basic", "enhanced", "reverse_port"
LOCALPATH=$(pwd)

# Source configurations and modules
source "$LOCALPATH/configs/s906b_config.sh"
source "$LOCALPATH/bin/functions.sh"

# Enhanced modules
SUPER_MANAGER="$LOCALPATH/bin/super_manager.sh"
SYSTEM_PROCESSOR="$LOCALPATH/bin/system_processor.sh"
REVERSE_PORTER="$LOCALPATH/bin/reverse_porter.sh"

# Display banner
display_banner() {
    echo "╔══════════════════════════════════════════════════════════════════════════════╗"
    echo "║                    S906B Enhanced Porting Tool v2.0                         ║"
    echo "║                Galaxy S22 Plus Android 15 OneUI 6 Porter                    ║"
    echo "║                                                                              ║"
    echo "║  Features:                                                                   ║"
    echo "║  • Enhanced super.img manipulation                                           ║"
    echo "║  • Deep system.img processing                                                ║"
    echo "║  • Reverse porting capabilities                                              ║"
    echo "║  • S906B optimized configurations                                            ║"
    echo "║  • Well-organized custom ROM creation                                        ║"
    echo "╚══════════════════════════════════════════════════════════════════════════════╝"
    echo ""
}

# Display usage information
show_usage() {
    echo "Usage: $0 <BaseROM> <PortROM> <UpdateZip> <Version> [Mode]"
    echo ""
    echo "Parameters:"
    echo "  BaseROM    - Base ROM file (S906B firmware)"
    echo "  PortROM    - Port ROM file (Source ROM to port from)"
    echo "  UpdateZip  - Update ZIP file (OneUI 6 update)"
    echo "  Version    - Output ROM version identifier"
    echo "  Mode       - Operation mode (optional):"
    echo "               • basic      - Standard porting (default)"
    echo "               • enhanced   - Enhanced super.img/system.img processing"
    echo "               • reverse    - Reverse porting mode"
    echo ""
    echo "Examples:"
    echo "  $0 S906B_Base.zip S24_Port.zip OneUI6_Update.zip v1.0"
    echo "  $0 S906B_Base.zip S24_Port.zip OneUI6_Update.zip v1.0 enhanced"
    echo "  $0 CustomROM.zip S906B_Base.zip - v1.0 reverse"
    echo ""
    echo "Enhanced Features:"
    echo "  • Super.img analysis, extraction, modification, and creation"
    echo "  • System.img deep processing with selective extraction"
    echo "  • Reverse porting from custom ROMs"
    echo "  • S906B specific optimizations and patches"
    echo "  • Comprehensive validation and safety checks"
}

# Validate input parameters
validate_parameters() {
    if [[ -z "$1" ]]; then
        echo "❌ Error: Missing required parameters"
        show_usage
        exit 1
    fi
    
    # Set default operation mode
    if [[ -z "$OPERATION_MODE" ]]; then
        OPERATION_MODE="basic"
    fi
    
    echo "🔧 Operation Mode: $OPERATION_MODE"
    
    # Validate files exist (except for reverse mode)
    if [[ "$OPERATION_MODE" != "reverse" ]]; then
        if [[ ! -f "$BASEROMZIP" ]]; then
            echo "❌ Error: Base ROM file not found: $BASEROMZIP"
            exit 1
        fi
        
        if [[ ! -f "$PORTROMZIP" ]]; then
            echo "❌ Error: Port ROM file not found: $PORTROMZIP"
            exit 1
        fi
        
        if [[ "$UPDATEZIP" != "-" ]] && [[ ! -f "$UPDATEZIP" ]]; then
            echo "❌ Error: Update ZIP file not found: $UPDATEZIP"
            exit 1
        fi
    fi
    
    echo "✅ Parameters validated"
}

# Setup working environment
setup_environment() {
    echo "🏗️ Setting up working environment..."
    
    # Check required packages
    check_packages "git" "android-sdk-libsparse-utils" "erofs-utils" "xmlstarlet" "lz4"
    
    # Create working directories
    mkdir -p port stock ui7update out analysis backup
    mkdir -p enhanced/{super,system,reverse_port}
    
    # Apply S906B configuration
    apply_s906b_config
    
    echo "✅ Environment setup complete"
}

# Enhanced ROM extraction with analysis
enhanced_extract_rom() {
    local rom_file="$1"
    local dest_dir="$2"
    local analysis_dir="$3"
    
    echo "📦 Enhanced ROM extraction: $rom_file -> $dest_dir"
    
    # Standard extraction
    extract_rom "$rom_file" "$dest_dir"
    
    # Enhanced analysis if requested
    if [[ "$OPERATION_MODE" == "enhanced" ]]; then
        echo "🔍 Performing enhanced analysis..."
        
        # Analyze super.img
        if [[ -f "$dest_dir/super.img" ]]; then
            "$SUPER_MANAGER" analyze "$dest_dir/super.img" "$analysis_dir/super_analysis"
        fi
        
        # Analyze system.img
        if [[ -f "$dest_dir/system.img" ]]; then
            "$SYSTEM_PROCESSOR" analyze "$dest_dir/system.img" "$analysis_dir/system_analysis"
        fi
    fi
}

# Enhanced super.img processing
process_super_img() {
    local operation="$1"  # extract, modify, create
    local input="$2"
    local output="$3"
    local config="$4"
    
    echo "🔧 Enhanced super.img processing: $operation"
    
    case "$operation" in
        "extract")
            "$SUPER_MANAGER" extract "$input" "$output" "all" "raw"
            ;;
        "modify")
            "$SUPER_MANAGER" modify "$input" "$config" "$output"
            ;;
        "create")
            "$SUPER_MANAGER" create "$input" "$output" "s906b" "lz4hc"
            ;;
        "optimize")
            "$SUPER_MANAGER" optimize "$input" "$output" "basic"
            ;;
        *)
            echo "❌ Unknown super.img operation: $operation"
            return 1
            ;;
    esac
}

# Enhanced system.img processing
process_system_img() {
    local operation="$1"  # extract, modify, create, reverse_port
    local input="$2"
    local output="$3"
    local config="$4"
    
    echo "🔧 Enhanced system.img processing: $operation"
    
    case "$operation" in
        "extract")
            "$SYSTEM_PROCESSOR" extract "$input" "$output" "full"
            ;;
        "extract_selective")
            "$SYSTEM_PROCESSOR" extract "$input" "$output" "selective" "$config"
            ;;
        "modify")
            "$SYSTEM_PROCESSOR" modify "$input" "$config" "$output" "lz4hc"
            ;;
        "create")
            "$SYSTEM_PROCESSOR" create "$input" "$output" "lz4hc"
            ;;
        "reverse_port")
            "$SYSTEM_PROCESSOR" reverse_port "$input" "$output" "$config" "enhanced/reverse_port"
            ;;
        *)
            echo "❌ Unknown system.img operation: $operation"
            return 1
            ;;
    esac
}

# Reverse porting workflow
reverse_porting_workflow() {
    local source_rom="$1"
    local target_rom="$2"
    local version="$3"
    
    echo "🔄 Starting reverse porting workflow..."
    
    # Extract source ROM
    echo "📦 Extracting source ROM for analysis..."
    enhanced_extract_rom "$source_rom" "reverse_source" "analysis/reverse_source"
    
    # Extract target ROM
    echo "📦 Extracting target ROM..."
    enhanced_extract_rom "$target_rom" "reverse_target" "analysis/reverse_target"
    
    # Analyze source ROM for reverse porting opportunities
    echo "🔍 Analyzing source ROM for reverse porting..."
    "$REVERSE_PORTER" analyze "reverse_source" "analysis/reverse_analysis" "reverse_target"
    
    # Extract features based on analysis
    echo "📦 Extracting features from source ROM..."
    if [[ -f "analysis/reverse_analysis/detected_features.txt" ]]; then
        "$REVERSE_PORTER" extract "reverse_source" "analysis/reverse_analysis/detected_features.txt" "enhanced/reverse_port" "copy"
    fi
    
    # Apply extracted features to target ROM
    echo "🔧 Applying extracted features to target ROM..."
    "$REVERSE_PORTER" apply "reverse_target" "enhanced/reverse_port/extracted_features" "" "backup/reverse_backup"
    
    # Create reverse ported super.img
    echo "🏗️ Creating reverse ported super.img..."
    process_super_img "create" "reverse_target" "out/reverse_ported_super.img" ""
    
    echo "✅ Reverse porting workflow complete"
}

# Standard porting workflow (enhanced)
standard_porting_workflow() {
    echo "🚀 Starting standard porting workflow..."
    
    # Extract ROMs with enhanced analysis
    enhanced_extract_rom "$BASEROMZIP" "stock" "analysis/stock"
    enhanced_extract_rom "$PORTROMZIP" "port" "analysis/port"
    
    # Extract update if provided
    if [[ "$UPDATEZIP" != "-" ]]; then
        unpack_updatezip "ui7update"
        
        # Update images
        updateImage "system" "ui7update" "port"
        updateImage "system_ext" "ui7update" "port"
        updateImage "product" "ui7update" "port"
        updateImage "odm" "ui7update" "port"
        updateImage "vendor" "ui7update" "port"
    fi
    
    # Enhanced super.img processing
    if [[ "$OPERATION_MODE" == "enhanced" ]]; then
        echo "🔧 Enhanced super.img processing..."
        
        # Extract super.img with analysis
        process_super_img "extract" "port/super.img" "enhanced/super/port_extracted" ""
        process_super_img "extract" "stock/super.img" "enhanced/super/stock_extracted" ""
        
        # Process individual partitions
        process_system_img "extract" "enhanced/super/port_extracted/system.img" "enhanced/system/port_system" ""
        process_system_img "extract" "enhanced/super/stock_extracted/vendor.img" "enhanced/system/stock_vendor" ""
    else
        # Standard extraction
        extract_erofs_images "port" "system.img"
        extract_erofs_images "port" "system_ext.img"
        extract_erofs_images "port" "odm.img"
        extract_erofs_images "port" "product.img"
        extract_erofs_images "stock" "vendor.img"
    fi
    
    # Mount images
    mount_images "stock"
    
    # Apply S906B specific patches
    apply_s906b_patches
    
    # Create output images
    create_output_images
    
    echo "✅ Standard porting workflow complete"
}

# Apply S906B specific patches
apply_s906b_patches() {
    echo "🩹 Applying S906B specific patches..."
    
    # Get device properties
    VNDK_VERSION=$(getprop ro.vndk.version vendor)
    DEVICE_MODEL=$(getprop ro.product.vendor.model vendor)
    
    # Apply SELinux patches
    replace_selinux "port"
    rm -rf port/system/system/etc/vintf
    
    # Apply partition patches
    apply_partition_patches "port"
    
    # Set device model
    set_device_model "$DEVICE_MODEL" "floating_feature.xml" "port/system"
    
    # Add S906B specific floating features
    for feature in "${FLOATING_FEATURES[@]}"; do
        add_line_in_file "port/system" "floating_feature.xml" "<$feature>"
    done
    
    # Copy VNDK files
    copy_file_to_same_path "stock/system_ext" "com.android.vndk.v$VNDK_VERSION.apex" "port/system_ext"
    
    # Apply property replacements
    apply_property_replacements
    
    # Apply vendor modifications for 64-bit only
    apply_vendor_64bit_modifications
    
    # Apply system modifications
    apply_system_modifications
    
    # Apply product modifications
    apply_product_modifications
    
    # Apply system_ext modifications
    apply_system_ext_modifications
    
    echo "✅ S906B patches applied"
}

# Apply property replacements
apply_property_replacements() {
    echo "📝 Applying property replacements..."
    
    # System properties
    for prop in "${!SYSTEM_PROPS[@]}"; do
        replace_props "$prop" "stock/system/system" "port/system/system" "${SYSTEM_PROPS[$prop]}"
    done
    
    # Vendor properties
    for prop in "${!VENDOR_PROPS[@]}"; do
        replace_props "$prop" "stock/vendor" "port/vendor" "${VENDOR_PROPS[$prop]}"
    done
    
    # Product properties
    for prop in "${!PRODUCT_PROPS[@]}"; do
        replace_props "$prop" "stock/product" "port/product" "${PRODUCT_PROPS[$prop]}"
    done
    
    # ODM properties
    for prop in "${!ODM_PROPS[@]}"; do
        replace_props "$prop" "stock/odm" "port/odm" "${ODM_PROPS[$prop]}"
    done
}

# Apply vendor 64-bit modifications
apply_vendor_64bit_modifications() {
    echo "🔧 Applying vendor 64-bit modifications..."
    
    # Modify build.prop for 64-bit only
    replace_in_file "stock/vendor" "build.prop" "ro.vendor.product.cpu.abilist=arm64-v8a,armeabi-v7a,armeabi" "ro.vendor.product.cpu.abilist=arm64-v8a"
    replace_in_file "stock/vendor" "build.prop" "ro.vendor.product.cpu.abilist32=armeabi-v7a,armeabi" "ro.vendor.product.cpu.abilist32="
    replace_in_file "stock/vendor" "build.prop" "ro.bionic.2nd_arch=arm" "ro.bionic.2nd_arch="
    replace_in_file "stock/vendor" "build.prop" "ro.bionic.2nd_cpu_variant=cortex-a75" "ro.bionic.2nd_cpu_variant="
    replace_in_file "stock/vendor" "build.prop" "ro.zygote=zygote64_32" "ro.zygote=zygote64"
    
    # Remove 32-bit specific lines
    remove_line_from_file "stock/vendor" "build.prop" "dalvik.vm.isa.arm.variant=cortex-a75"
    remove_line_from_file "stock/vendor" "build.prop" "dalvik.vm.isa.arm.features=default"
    
    # Delete 32-bit ELF files
    delete_32bit_elf_files "stock/vendor"
    
    # Remove vendor files
    remove_files_by_name "stock/vendor" "${VENDOR_REMOVE_FILES[@]}"
    
    # Apply vendor patches
    apply_partition_patches "stock" "vendor"
}

# Apply system modifications
apply_system_modifications() {
    echo "📱 Applying system modifications..."
    
    # Remove bloatware
    for app in "${SYSTEM_REMOVE_APPS[@]}"; do
        rm -rf "port/system/system/priv-app/$app"
        rm -rf "port/system/system/app/$app"
        echo "   Removed: $app"
    done
    
    # Camera modifications
    rm -rf patches/libsusedbycamera.txt
    extract_apk_libs "SamsungCamera.apk" "port/system/system/priv-app/" "patches/libsusedbycamera.txt"
    copy_file_to_same_path "stock/system/system" "vendor.samsung.hardware.snap-V2-ndk.so" "port/system/system"
    
    # Copy camera libraries
    copy_files_from_list "stock/system" "port/system" "public.libraries-camera.samsung.txt"
    copy_files_from_list "stock/system" "port/system" "public.libraries-arcsoft.txt"
    copy_files_from_list "stock/system" "port/system" "patches/libsusedbycamera.txt" "true"
    
    # Audio modifications (Dolby Atmos)
    copy_file_to_same_path "stock/system/system" "libswdap_legacy.so" "port/system/system"
    copy_file_to_same_path "stock/system/system" "libswspatializer_legacy.so" "port/system/system"
    copy_file_to_same_path "stock/system/system/etc" "audio_effects.xml" "port/system/system/etc"
    copy_file_to_same_path "stock/system/system/etc" "audio_effects_common.conf" "port/system/system/etc"
}

# Apply product modifications
apply_product_modifications() {
    echo "🛍️ Applying product modifications..."
    
    # Remove product files
    remove_files_by_name "port/product" "${PRODUCT_REMOVE_FILES[@]}"
    
    # Copy required files from stock
    copy_file_to_same_path "stock/product/overlay" "framework-res__auto_generated_rro_product.apk" "port/product/overlay"
    copy_file_to_same_path "stock/product/priv-app" "HotwordEnrollmentOKGoogleEx4HEXAGON.apk" "port/product/priv-app"
    copy_file_to_same_path "stock/product/priv-app" "HotwordEnrollmentXGoogleEx4HEXAGON.apk" "port/product/priv-app"
}

# Apply system_ext modifications
apply_system_ext_modifications() {
    echo "🔧 Applying system_ext modifications..."
    
    # Copy required libraries
    copy_file_to_same_path "stock/system_ext" "libpenguin.so" "port/system_ext"
    copy_file_to_same_path "stock/system_ext" "libpenguin_impl.so" "port/system_ext"
}

# Create output images
create_output_images() {
    echo "🏗️ Creating output images..."
    
    cd "$LOCALPATH"
    
    if [[ "$OPERATION_MODE" == "enhanced" ]]; then
        # Enhanced image creation
        echo "🔧 Creating enhanced images..."
        
        # Create individual partition images
        process_system_img "create" "port/system" "updatezip/system.img" ""
        mkfs.erofs -zlz4hc --file-contexts=port/system_ext/etc/selinux/system_ext_file_contexts --ignore-mtime ./updatezip/system_ext.img port/system_ext/
        mkfs.erofs -zlz4hc --file-contexts=stock/vendor/etc/selinux/vendor_file_contexts --ignore-mtime ./updatezip/vendor.img stock/vendor/
        mkfs.erofs -zlz4hc --file-contexts=port/product/etc/selinux/product_file_contexts --ignore-mtime ./updatezip/product.img port/product/
        mkfs.erofs -zlz4hc --ignore-mtime ./updatezip/odm.img port/odm/
        
        # Create enhanced super.img
        process_super_img "create" "updatezip" "updatezip/super.img" ""
        
        # Validate created images
        "$SUPER_MANAGER" validate "updatezip/super.img"
        "$SYSTEM_PROCESSOR" validate "updatezip/system.img"
        
    else
        # Standard image creation
        echo "🔧 Creating standard images..."
        
        mkfs.erofs -zlz4hc --file-contexts=port/system/system/etc/selinux/plat_file_contexts --ignore-mtime ./updatezip/system.img port/system/
        mkfs.erofs -zlz4hc --file-contexts=port/system_ext/etc/selinux/system_ext_file_contexts --ignore-mtime ./updatezip/system_ext.img port/system_ext/
        mkfs.erofs -zlz4hc --file-contexts=stock/vendor/etc/selinux/vendor_file_contexts --ignore-mtime ./updatezip/vendor.img stock/vendor/
        mkfs.erofs -zlz4hc --file-contexts=port/product/etc/selinux/product_file_contexts --ignore-mtime ./updatezip/product.img port/product/
        mkfs.erofs -zlz4hc --ignore-mtime ./updatezip/odm.img port/odm/
    fi
    
    # Copy boot images
    patch_vendor_cmdline "stock/vendor_boot.img" "tmpout" "updatezip/vendor_boot.img" "${VENDOR_CMDLINE_ADD[@]}"
    cp stock/boot.img updatezip/
    cp patches/init_boot.img updatezip/ 2>/dev/null || echo "⚠️ init_boot.img not found, skipping..."
    
    echo "✅ Output images created"
}

# Create final ROM package
create_rom_package() {
    local version="$1"
    local mode="$2"
    
    echo "📦 Creating final ROM package..."
    
    # Create output directory
    rm -rf out/*
    mkdir -p out
    
    # Package ROM
    cd updatezip
    local rom_name="S906B-OneUI6-${mode}-${version}.zip"
    zip -r "../out/$rom_name" ./*
    cd ..
    
    # Create checksums
    cd out
    sha256sum "$rom_name" > "${rom_name}.sha256"
    md5sum "$rom_name" > "${rom_name}.md5"
    cd ..
    
    # Generate ROM info
    cat > "out/${rom_name}.info" << EOF
ROM Information:
================
Name: $rom_name
Version: $version
Mode: $mode
Device: Samsung Galaxy S22 Plus (S906B)
Android Version: $ANDROID_VERSION
OneUI Version: $ONEUI_VERSION
Build Date: $(date)
Build Fingerprint: $BUILD_FINGERPRINT

Features:
- 64-bit only vendor
- Enhanced super.img processing
- S906B optimized configurations
- Dolby Atmos support
- Camera enhancements
- Performance optimizations

Installation:
1. Boot into download mode
2. Flash using Odin or similar tool
3. Perform factory reset after first boot
4. Enjoy your enhanced S906B ROM!

Disclaimer:
This ROM is for advanced users only. Flash at your own risk.
Always backup your device before flashing custom ROMs.
EOF
    
    echo "✅ ROM package created: out/$rom_name"
    ls -lh "out/$rom_name"
}

# Cleanup function
cleanup_workspace() {
    echo "🧹 Cleaning up workspace..."
    
    # Remove temporary directories
    rm -rf workingdir
    rm -rf tmpout
    
    # Optionally remove extracted directories (keep for debugging)
    if [[ "$OPERATION_MODE" != "enhanced" ]]; then
        # rm -rf port/*
        # rm -rf stock/*
        echo "ℹ️ Keeping extracted directories for debugging"
    fi
    
    echo "✅ Cleanup complete"
}

# Validation and safety checks
perform_safety_checks() {
    echo "🔍 Performing safety checks..."
    
    # Check S906B compatibility
    validate_s906b_compatibility "stock"
    
    # Check available disk space
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local required_space=157286400  # 150GB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        echo "⚠️ Warning: Low disk space. Required: 150GB, Available: $((available_space/1024/1024))GB"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "❌ Aborting due to insufficient disk space"
            exit 1
        fi
    fi
    
    # Validate tools
    for tool in lpmake lpunpack mkfs.erofs simg2img; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "❌ Error: Required tool not found: $tool"
            exit 1
        fi
    done
    
    echo "✅ Safety checks passed"
}

# Main execution function
main() {
    # Display banner
    display_banner
    
    # Validate parameters
    validate_parameters "$@"
    
    # Setup environment
    setup_environment
    
    # Perform safety checks
    perform_safety_checks
    
    # Execute workflow based on mode
    case "$OPERATION_MODE" in
        "basic"|"enhanced")
            standard_porting_workflow
            create_rom_package "$VERSION" "$OPERATION_MODE"
            ;;
        "reverse")
            reverse_porting_workflow "$BASEROMZIP" "$PORTROMZIP" "$VERSION"
            create_rom_package "$VERSION" "reverse"
            ;;
        *)
            echo "❌ Error: Unknown operation mode: $OPERATION_MODE"
            show_usage
            exit 1
            ;;
    esac
    
    # Cleanup
    cleanup_workspace
    
    echo ""
    echo "🎉 S906B ROM porting completed successfully!"
    echo "📦 Output ROM: out/S906B-OneUI6-${OPERATION_MODE}-${VERSION}.zip"
    echo "📋 ROM info: out/S906B-OneUI6-${OPERATION_MODE}-${VERSION}.zip.info"
    echo ""
    echo "⚠️ Remember to:"
    echo "   • Test the ROM thoroughly before daily use"
    echo "   • Keep a backup of your original firmware"
    echo "   • Flash at your own risk"
    echo ""
    echo "✅ Happy flashing! 🚀"
}

# Run main function
main "$@"

