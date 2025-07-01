#!/bin/bash
# Comprehensive Validation and Safety System for S906B Porting
# Provides pre-flight checks, integrity validation, and safety mechanisms

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALPATH="$(dirname "$SCRIPT_DIR")"

# Source configuration
source "$LOCALPATH/configs/s906b_config.sh"

# Validation Functions

# Function to perform comprehensive pre-flight checks
pre_flight_checks() {
    local base_rom="$1"
    local port_rom="$2"
    local update_zip="$3"
    local mode="$4"
    
    echo "🔍 Performing pre-flight safety checks..."
    
    local checks_passed=true
    
    # Check 1: Disk space
    echo "💾 Checking disk space..."
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local required_space=157286400  # 150GB in KB
    
    if [ $available_space -lt $required_space ]; then
        echo "❌ Insufficient disk space"
        echo "   Required: 150GB"
        echo "   Available: $((available_space/1024/1024))GB"
        checks_passed=false
    else
        echo "✅ Disk space sufficient: $((available_space/1024/1024))GB available"
    fi
    
    # Check 2: Required tools
    echo "🔧 Checking required tools..."
    local required_tools=("lpmake" "lpunpack" "simg2img" "mkfs.erofs" "lz4" "unzip" "zip")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            echo "❌ Missing required tool: $tool"
            checks_passed=false
        else
            echo "✅ Tool available: $tool"
        fi
    done
    
    # Check 3: File existence and accessibility
    echo "📁 Checking input files..."
    
    if [ "$mode" != "reverse" ]; then
        if [ ! -f "$base_rom" ]; then
            echo "❌ Base ROM not found: $base_rom"
            checks_passed=false
        elif [ ! -r "$base_rom" ]; then
            echo "❌ Base ROM not readable: $base_rom"
            checks_passed=false
        else
            echo "✅ Base ROM accessible: $base_rom"
        fi
        
        if [ ! -f "$port_rom" ]; then
            echo "❌ Port ROM not found: $port_rom"
            checks_passed=false
        elif [ ! -r "$port_rom" ]; then
            echo "❌ Port ROM not readable: $port_rom"
            checks_passed=false
        else
            echo "✅ Port ROM accessible: $port_rom"
        fi
        
        if [ "$update_zip" != "-" ]; then
            if [ ! -f "$update_zip" ]; then
                echo "❌ Update ZIP not found: $update_zip"
                checks_passed=false
            elif [ ! -r "$update_zip" ]; then
                echo "❌ Update ZIP not readable: $update_zip"
                checks_passed=false
            else
                echo "✅ Update ZIP accessible: $update_zip"
            fi
        fi
    fi
    
    # Check 4: File integrity
    echo "🔐 Checking file integrity..."
    
    if [ "$mode" != "reverse" ] && [ -f "$base_rom" ]; then
        if unzip -t "$base_rom" >/dev/null 2>&1; then
            echo "✅ Base ROM archive integrity OK"
        else
            echo "❌ Base ROM archive corrupted"
            checks_passed=false
        fi
    fi
    
    if [ "$mode" != "reverse" ] && [ -f "$port_rom" ]; then
        if unzip -t "$port_rom" >/dev/null 2>&1; then
            echo "✅ Port ROM archive integrity OK"
        else
            echo "❌ Port ROM archive corrupted"
            checks_passed=false
        fi
    fi
    
    # Check 5: S906B compatibility
    echo "📱 Checking S906B compatibility..."
    
    if [ "$mode" != "reverse" ] && [ -f "$base_rom" ]; then
        local temp_dir=$(mktemp -d)
        unzip -q "$base_rom" "*/build.prop" -d "$temp_dir" 2>/dev/null || true
        
        local build_prop=$(find "$temp_dir" -name "build.prop" | head -1)
        if [ -f "$build_prop" ]; then
            local device_model=$(grep "ro.product.model" "$build_prop" | cut -d'=' -f2 | tr -d '\r')
            if [[ "$device_model" == *"S906"* ]] || [[ "$device_model" == *"s22plus"* ]]; then
                echo "✅ S906B compatible base ROM detected"
            else
                echo "⚠️ Warning: Base ROM may not be S906B compatible (Model: $device_model)"
            fi
        else
            echo "⚠️ Warning: Could not verify device compatibility"
        fi
        
        rm -rf "$temp_dir"
    fi
    
    # Check 6: Memory availability
    echo "🧠 Checking memory availability..."
    local available_mem=$(free -m | awk 'NR==2{print $7}')
    local required_mem=4096  # 4GB
    
    if [ $available_mem -lt $required_mem ]; then
        echo "⚠️ Warning: Low available memory"
        echo "   Available: ${available_mem}MB"
        echo "   Recommended: ${required_mem}MB"
    else
        echo "✅ Memory sufficient: ${available_mem}MB available"
    fi
    
    # Check 7: Permissions
    echo "🔒 Checking permissions..."
    
    if [ ! -w "." ]; then
        echo "❌ No write permission in current directory"
        checks_passed=false
    else
        echo "✅ Write permissions OK"
    fi
    
    # Summary
    echo ""
    if [ "$checks_passed" = true ]; then
        echo "✅ All pre-flight checks passed"
        return 0
    else
        echo "❌ Some pre-flight checks failed"
        echo "⚠️ Please resolve the issues above before proceeding"
        return 1
    fi
}

# Function to validate ROM structure
validate_rom_structure() {
    local rom_path="$1"
    local rom_type="$2"  # "extracted" or "archive"
    
    echo "🔍 Validating ROM structure: $rom_path"
    
    local validation_passed=true
    
    if [ "$rom_type" == "archive" ]; then
        # Validate archive structure
        echo "📦 Validating archive structure..."
        
        local temp_dir=$(mktemp -d)
        unzip -q "$rom_path" -d "$temp_dir"
        
        # Check for essential files
        local essential_files=("AP_*.tar.md5" "*.img.lz4")
        for pattern in "${essential_files[@]}"; do
            if ! find "$temp_dir" -name "$pattern" | head -1 >/dev/null; then
                echo "⚠️ Warning: Pattern not found: $pattern"
            fi
        done
        
        rm -rf "$temp_dir"
        
    elif [ "$rom_type" == "extracted" ]; then
        # Validate extracted ROM structure
        echo "📁 Validating extracted ROM structure..."
        
        # Check for essential partitions
        local essential_partitions=("system.img" "vendor.img" "boot.img")
        for partition in "${essential_partitions[@]}"; do
            if [ ! -f "$rom_path/$partition" ]; then
                echo "❌ Missing essential partition: $partition"
                validation_passed=false
            else
                echo "✅ Found partition: $partition"
            fi
        done
        
        # Check super.img if present
        if [ -f "$rom_path/super.img" ]; then
            echo "📦 Validating super.img..."
            if "$LOCALPATH/bin/lpdump" --slot=0 "$rom_path/super.img" >/dev/null 2>&1; then
                echo "✅ Super.img structure valid"
            else
                echo "❌ Super.img structure invalid"
                validation_passed=false
            fi
        fi
        
        # Check individual partition images
        for img in "$rom_path"/*.img; do
            if [ -f "$img" ]; then
                local img_name=$(basename "$img")
                echo "🔍 Validating $img_name..."
                
                # Check file size
                local size=$(stat -c%s "$img")
                if [ $size -eq 0 ]; then
                    echo "❌ $img_name is empty"
                    validation_passed=false
                elif [ $size -lt 1048576 ]; then  # Less than 1MB
                    echo "⚠️ $img_name is very small: $size bytes"
                else
                    echo "✅ $img_name size OK: $((size/1024/1024))MB"
                fi
                
                # Check file type
                local file_type=$(file "$img")
                if echo "$file_type" | grep -q "data\|Android\|Linux"; then
                    echo "✅ $img_name file type OK"
                else
                    echo "⚠️ $img_name unknown file type: $file_type"
                fi
            fi
        done
    fi
    
    if [ "$validation_passed" = true ]; then
        echo "✅ ROM structure validation passed"
        return 0
    else
        echo "❌ ROM structure validation failed"
        return 1
    fi
}

# Function to validate device compatibility
validate_device_compatibility() {
    local rom_path="$1"
    local target_device="$2"
    
    echo "📱 Validating device compatibility..."
    
    local compatibility_score=0
    local max_score=10
    
    # Extract build.prop for analysis
    local temp_dir=$(mktemp -d)
    local build_prop=""
    
    if [ -d "$rom_path" ]; then
        # Extracted ROM
        build_prop=$(find "$rom_path" -name "build.prop" | head -1)
    else
        # Archive ROM
        unzip -q "$rom_path" "*/build.prop" -d "$temp_dir" 2>/dev/null || true
        build_prop=$(find "$temp_dir" -name "build.prop" | head -1)
    fi
    
    if [ -f "$build_prop" ]; then
        echo "📋 Analyzing build.prop for compatibility..."
        
        # Check device model
        local device_model=$(grep "ro.product.model" "$build_prop" | cut -d'=' -f2 | tr -d '\r')
        if [[ "$device_model" == *"S906"* ]]; then
            echo "✅ Device model matches: $device_model"
            compatibility_score=$((compatibility_score + 3))
        elif [[ "$device_model" == *"S22"* ]]; then
            echo "✅ Device family matches: $device_model"
            compatibility_score=$((compatibility_score + 2))
        else
            echo "⚠️ Device model different: $device_model"
        fi
        
        # Check architecture
        local cpu_abi=$(grep "ro.product.cpu.abi=" "$build_prop" | cut -d'=' -f2 | tr -d '\r')
        if [[ "$cpu_abi" == "arm64-v8a" ]]; then
            echo "✅ Architecture compatible: $cpu_abi"
            compatibility_score=$((compatibility_score + 2))
        else
            echo "⚠️ Architecture may be incompatible: $cpu_abi"
        fi
        
        # Check Android version
        local android_version=$(grep "ro.build.version.release" "$build_prop" | cut -d'=' -f2 | tr -d '\r')
        if [[ "$android_version" == "15"* ]] || [[ "$android_version" == "14"* ]]; then
            echo "✅ Android version compatible: $android_version"
            compatibility_score=$((compatibility_score + 2))
        else
            echo "⚠️ Android version may be incompatible: $android_version"
        fi
        
        # Check OneUI version
        local oneui_version=$(grep "ro.oneui.version" "$build_prop" | cut -d'=' -f2 | tr -d '\r')
        if [[ "$oneui_version" == "6"* ]]; then
            echo "✅ OneUI version compatible: $oneui_version"
            compatibility_score=$((compatibility_score + 2))
        else
            echo "⚠️ OneUI version different: $oneui_version"
        fi
        
        # Check bootloader
        local bootloader=$(grep "ro.bootloader" "$build_prop" | cut -d'=' -f2 | tr -d '\r')
        if [[ "$bootloader" == *"S906B"* ]]; then
            echo "✅ Bootloader matches: $bootloader"
            compatibility_score=$((compatibility_score + 1))
        else
            echo "⚠️ Bootloader different: $bootloader"
        fi
        
    else
        echo "❌ Could not find build.prop for analysis"
    fi
    
    rm -rf "$temp_dir"
    
    # Calculate compatibility percentage
    local compatibility_percent=$((compatibility_score * 100 / max_score))
    
    echo ""
    echo "📊 Compatibility Analysis Results:"
    echo "   Score: $compatibility_score/$max_score"
    echo "   Compatibility: $compatibility_percent%"
    
    if [ $compatibility_percent -ge 80 ]; then
        echo "✅ High compatibility - Safe to proceed"
        return 0
    elif [ $compatibility_percent -ge 60 ]; then
        echo "⚠️ Moderate compatibility - Proceed with caution"
        return 1
    else
        echo "❌ Low compatibility - High risk of issues"
        return 2
    fi
}

# Function to validate partition integrity
validate_partition_integrity() {
    local partition_img="$1"
    local partition_name="$2"
    
    echo "🔍 Validating partition integrity: $partition_name"
    
    if [ ! -f "$partition_img" ]; then
        echo "❌ Partition image not found: $partition_img"
        return 1
    fi
    
    # Check file size
    local size=$(stat -c%s "$partition_img")
    echo "📊 Partition size: $((size/1024/1024))MB"
    
    if [ $size -eq 0 ]; then
        echo "❌ Partition is empty"
        return 1
    fi
    
    # Check file type and filesystem
    local file_type=$(file "$partition_img")
    echo "📋 File type: $file_type"
    
    if echo "$file_type" | grep -q "EROFS"; then
        echo "✅ EROFS filesystem detected"
        
        # Try to mount and validate
        local mount_point=$(mktemp -d)
        if mount -t erofs -o loop "$partition_img" "$mount_point" 2>/dev/null; then
            echo "✅ EROFS mount successful"
            
            # Check basic structure
            if [ -d "$mount_point/app" ] || [ -d "$mount_point/priv-app" ] || [ -d "$mount_point/lib" ]; then
                echo "✅ Partition structure looks valid"
            else
                echo "⚠️ Unusual partition structure"
            fi
            
            umount "$mount_point"
        else
            echo "⚠️ Could not mount EROFS partition"
        fi
        rmdir "$mount_point"
        
    elif echo "$file_type" | grep -q "ext[234]"; then
        echo "✅ EXT filesystem detected"
        
        # Check filesystem integrity
        if fsck.ext4 -n "$partition_img" >/dev/null 2>&1; then
            echo "✅ EXT filesystem integrity OK"
        else
            echo "⚠️ EXT filesystem may have issues"
        fi
        
    elif echo "$file_type" | grep -q "Android sparse"; then
        echo "✅ Android sparse image detected"
        
        # Convert and check
        local temp_raw=$(mktemp)
        if simg2img "$partition_img" "$temp_raw" 2>/dev/null; then
            echo "✅ Sparse image conversion successful"
            local raw_type=$(file "$temp_raw")
            echo "📋 Raw image type: $raw_type"
        else
            echo "❌ Sparse image conversion failed"
        fi
        rm -f "$temp_raw"
        
    else
        echo "⚠️ Unknown filesystem type"
    fi
    
    echo "✅ Partition integrity check complete"
    return 0
}

# Function to create safety backup
create_safety_backup() {
    local source_dir="$1"
    local backup_name="$2"
    
    echo "💾 Creating safety backup: $backup_name"
    
    local backup_dir="backup/safety_backups"
    mkdir -p "$backup_dir"
    
    local backup_path="$backup_dir/${backup_name}_$(date +%Y%m%d_%H%M%S)"
    
    if [ -d "$source_dir" ]; then
        echo "📁 Backing up directory: $source_dir"
        cp -a "$source_dir" "$backup_path"
    elif [ -f "$source_dir" ]; then
        echo "📄 Backing up file: $source_dir"
        cp "$source_dir" "$backup_path"
    else
        echo "❌ Source not found: $source_dir"
        return 1
    fi
    
    # Create backup manifest
    cat > "$backup_path.manifest" << EOF
Backup Manifest
===============
Backup Name: $backup_name
Source: $source_dir
Backup Path: $backup_path
Created: $(date)
Size: $(du -sh "$backup_path" | cut -f1)

Restore Command:
cp -a "$backup_path" "$source_dir"
EOF
    
    echo "✅ Backup created: $backup_path"
    echo "📋 Manifest: $backup_path.manifest"
    
    return 0
}

# Function to validate final ROM output
validate_final_rom() {
    local rom_file="$1"
    
    echo "🔍 Validating final ROM output..."
    
    if [ ! -f "$rom_file" ]; then
        echo "❌ ROM file not found: $rom_file"
        return 1
    fi
    
    # Check file size
    local size=$(stat -c%s "$rom_file")
    local size_mb=$((size/1024/1024))
    echo "📊 ROM size: ${size_mb}MB"
    
    if [ $size_mb -lt 2000 ]; then
        echo "⚠️ ROM seems too small (< 2GB)"
    elif [ $size_mb -gt 10000 ]; then
        echo "⚠️ ROM seems too large (> 10GB)"
    else
        echo "✅ ROM size looks reasonable"
    fi
    
    # Check archive integrity
    echo "🔐 Checking archive integrity..."
    if unzip -t "$rom_file" >/dev/null 2>&1; then
        echo "✅ Archive integrity OK"
    else
        echo "❌ Archive integrity failed"
        return 1
    fi
    
    # Check for essential files
    echo "📁 Checking for essential files..."
    local essential_files=("system.img" "vendor.img" "boot.img")
    local temp_dir=$(mktemp -d)
    unzip -q "$rom_file" -d "$temp_dir"
    
    for file in "${essential_files[@]}"; do
        if find "$temp_dir" -name "$file" | head -1 >/dev/null; then
            echo "✅ Found: $file"
        else
            echo "❌ Missing: $file"
        fi
    done
    
    rm -rf "$temp_dir"
    
    # Generate checksum
    echo "🔐 Generating checksums..."
    local sha256=$(sha256sum "$rom_file" | cut -d' ' -f1)
    local md5=$(md5sum "$rom_file" | cut -d' ' -f1)
    
    echo "SHA256: $sha256"
    echo "MD5: $md5"
    
    # Save checksums
    echo "$sha256" > "${rom_file}.sha256"
    echo "$md5" > "${rom_file}.md5"
    
    echo "✅ Final ROM validation complete"
    return 0
}

# Function to perform rollback
perform_rollback() {
    local backup_path="$1"
    local target_path="$2"
    
    echo "🔄 Performing rollback..."
    
    if [ ! -e "$backup_path" ]; then
        echo "❌ Backup not found: $backup_path"
        return 1
    fi
    
    echo "📁 Rolling back from: $backup_path"
    echo "📁 Rolling back to: $target_path"
    
    # Remove current target
    if [ -e "$target_path" ]; then
        rm -rf "$target_path"
    fi
    
    # Restore from backup
    cp -a "$backup_path" "$target_path"
    
    if [ $? -eq 0 ]; then
        echo "✅ Rollback successful"
        return 0
    else
        echo "❌ Rollback failed"
        return 1
    fi
}

# Main validation function
main() {
    case "$1" in
        "pre_flight")
            pre_flight_checks "$2" "$3" "$4" "$5"
            ;;
        "rom_structure")
            validate_rom_structure "$2" "$3"
            ;;
        "device_compatibility")
            validate_device_compatibility "$2" "$3"
            ;;
        "partition_integrity")
            validate_partition_integrity "$2" "$3"
            ;;
        "safety_backup")
            create_safety_backup "$2" "$3"
            ;;
        "final_rom")
            validate_final_rom "$2"
            ;;
        "rollback")
            perform_rollback "$2" "$3"
            ;;
        *)
            echo "Usage: $0 {pre_flight|rom_structure|device_compatibility|partition_integrity|safety_backup|final_rom|rollback} [options]"
            echo ""
            echo "Commands:"
            echo "  pre_flight <base_rom> <port_rom> <update_zip> <mode>     - Pre-flight safety checks"
            echo "  rom_structure <rom_path> <type>                          - Validate ROM structure"
            echo "  device_compatibility <rom_path> <target_device>          - Check device compatibility"
            echo "  partition_integrity <partition_img> <partition_name>     - Validate partition"
            echo "  safety_backup <source> <backup_name>                     - Create safety backup"
            echo "  final_rom <rom_file>                                     - Validate final ROM"
            echo "  rollback <backup_path> <target_path>                     - Perform rollback"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

