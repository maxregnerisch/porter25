#!/bin/bash
# Enhanced System.img Processing Module for S906B Android 15 OneUI 6 Porting
# Provides deep system.img extraction, modification, and reverse porting capabilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALPATH="$(dirname "$SCRIPT_DIR")"

# Source configuration and functions
source "$LOCALPATH/configs/s906b_config.sh"
source "$LOCALPATH/bin/functions.sh"

# System.img Processing Functions

# Function to analyze system.img structure
analyze_system_img() {
    local system_img="$1"
    local output_dir="$2"
    
    echo "🔍 Analyzing system.img structure..."
    
    if [ ! -f "$system_img" ]; then
        echo "❌ Error: System.img not found at $system_img"
        return 1
    fi
    
    mkdir -p "$output_dir/analysis"
    
    # Get system.img information
    echo "📊 System.img Information:"
    ls -lh "$system_img"
    file "$system_img" > "$output_dir/analysis/file_type.txt"
    cat "$output_dir/analysis/file_type.txt"
    
    # Detect filesystem type
    local fs_type=""
    if file "$system_img" | grep -q "EROFS"; then
        fs_type="erofs"
        echo "📦 Detected EROFS filesystem"
    elif file "$system_img" | grep -q "ext[234]"; then
        fs_type="ext4"
        echo "📦 Detected EXT4 filesystem"
    else
        echo "❓ Unknown filesystem type"
        fs_type="unknown"
    fi
    
    echo "$fs_type" > "$output_dir/analysis/filesystem_type"
    
    # Mount and analyze content
    local mount_point="$output_dir/analysis/mounted"
    mkdir -p "$mount_point"
    
    if [ "$fs_type" == "erofs" ]; then
        if mount -t erofs -o loop "$system_img" "$mount_point" 2>/dev/null; then
            echo "✅ Successfully mounted EROFS system.img"
            analyze_system_content "$mount_point" "$output_dir/analysis"
            umount "$mount_point"
        else
            echo "⚠️ Failed to mount EROFS system.img, trying extraction..."
            extract_erofs_content "$system_img" "$mount_point"
            analyze_system_content "$mount_point" "$output_dir/analysis"
        fi
    elif [ "$fs_type" == "ext4" ]; then
        if mount -t ext4 -o loop,ro "$system_img" "$mount_point" 2>/dev/null; then
            echo "✅ Successfully mounted EXT4 system.img"
            analyze_system_content "$mount_point" "$output_dir/analysis"
            umount "$mount_point"
        else
            echo "❌ Failed to mount EXT4 system.img"
            return 1
        fi
    fi
    
    echo "✅ Analysis complete. Results saved to $output_dir/analysis/"
}

# Function to analyze system content
analyze_system_content() {
    local mount_point="$1"
    local analysis_dir="$2"
    
    echo "📋 Analyzing system content structure..."
    
    # List directory structure
    find "$mount_point" -type d | head -50 > "$analysis_dir/directory_structure.txt"
    
    # Find APK files
    find "$mount_point" -name "*.apk" > "$analysis_dir/apk_list.txt"
    echo "📱 Found $(wc -l < "$analysis_dir/apk_list.txt") APK files"
    
    # Find JAR files
    find "$mount_point" -name "*.jar" > "$analysis_dir/jar_list.txt"
    echo "☕ Found $(wc -l < "$analysis_dir/jar_list.txt") JAR files"
    
    # Find SO libraries
    find "$mount_point" -name "*.so" > "$analysis_dir/so_list.txt"
    echo "🔧 Found $(wc -l < "$analysis_dir/so_list.txt") SO libraries"
    
    # Analyze build.prop
    if [ -f "$mount_point/build.prop" ]; then
        cp "$mount_point/build.prop" "$analysis_dir/build.prop"
        echo "📝 Build.prop copied for analysis"
    fi
    
    # Check for OneUI specific files
    find "$mount_point" -name "*samsung*" -o -name "*oneui*" -o -name "*knox*" > "$analysis_dir/oneui_files.txt"
    echo "🎨 Found $(wc -l < "$analysis_dir/oneui_files.txt") OneUI-specific files"
    
    # Check system apps
    if [ -d "$mount_point/app" ]; then
        ls "$mount_point/app" > "$analysis_dir/system_apps.txt"
        echo "📱 Found $(wc -l < "$analysis_dir/system_apps.txt") system apps"
    fi
    
    # Check privileged apps
    if [ -d "$mount_point/priv-app" ]; then
        ls "$mount_point/priv-app" > "$analysis_dir/priv_apps.txt"
        echo "🔐 Found $(wc -l < "$analysis_dir/priv_apps.txt") privileged apps"
    fi
    
    # Check framework files
    if [ -d "$mount_point/framework" ]; then
        ls "$mount_point/framework" > "$analysis_dir/framework_files.txt"
        echo "🏗️ Found $(wc -l < "$analysis_dir/framework_files.txt") framework files"
    fi
}

# Function to extract system.img with enhanced options
extract_system_img() {
    local system_img="$1"
    local output_dir="$2"
    local extraction_mode="$3"  # "full", "selective", "apps_only"
    local file_filter="$4"      # Optional file filter
    
    echo "📦 Extracting system.img with mode: $extraction_mode"
    
    if [ ! -f "$system_img" ]; then
        echo "❌ Error: System.img not found at $system_img"
        return 1
    fi
    
    mkdir -p "$output_dir/extracted"
    
    # Detect filesystem type
    local fs_type=""
    if file "$system_img" | grep -q "EROFS"; then
        fs_type="erofs"
    elif file "$system_img" | grep -q "ext[234]"; then
        fs_type="ext4"
    else
        echo "❌ Error: Unsupported filesystem type"
        return 1
    fi
    
    case "$extraction_mode" in
        "full")
            extract_full_system "$system_img" "$output_dir/extracted" "$fs_type"
            ;;
        "selective")
            extract_selective_system "$system_img" "$output_dir/extracted" "$fs_type" "$file_filter"
            ;;
        "apps_only")
            extract_apps_only "$system_img" "$output_dir/extracted" "$fs_type"
            ;;
        *)
            echo "❌ Error: Unknown extraction mode: $extraction_mode"
            return 1
            ;;
    esac
    
    echo "✅ System.img extraction complete"
}

# Function to extract full system
extract_full_system() {
    local system_img="$1"
    local output_dir="$2"
    local fs_type="$3"
    
    echo "📂 Performing full system extraction..."
    
    if [ "$fs_type" == "erofs" ]; then
        # Use fsck.erofs or mount to extract
        local mount_point=$(mktemp -d)
        if mount -t erofs -o loop "$system_img" "$mount_point" 2>/dev/null; then
            echo "🔄 Copying system content..."
            cp -a "$mount_point"/* "$output_dir/"
            umount "$mount_point"
        else
            echo "🔧 Using alternative EROFS extraction..."
            extract_erofs_content "$system_img" "$output_dir"
        fi
        rmdir "$mount_point" 2>/dev/null
    elif [ "$fs_type" == "ext4" ]; then
        local mount_point=$(mktemp -d)
        if mount -t ext4 -o loop,ro "$system_img" "$mount_point" 2>/dev/null; then
            echo "🔄 Copying system content..."
            cp -a "$mount_point"/* "$output_dir/"
            umount "$mount_point"
        else
            echo "❌ Failed to mount EXT4 system.img"
            return 1
        fi
        rmdir "$mount_point" 2>/dev/null
    fi
}

# Function to extract selective system content
extract_selective_system() {
    local system_img="$1"
    local output_dir="$2"
    local fs_type="$3"
    local file_filter="$4"
    
    echo "🎯 Performing selective system extraction with filter: $file_filter"
    
    local mount_point=$(mktemp -d)
    
    if [ "$fs_type" == "erofs" ]; then
        mount -t erofs -o loop "$system_img" "$mount_point" 2>/dev/null
    elif [ "$fs_type" == "ext4" ]; then
        mount -t ext4 -o loop,ro "$system_img" "$mount_point" 2>/dev/null
    fi
    
    if mountpoint -q "$mount_point"; then
        # Apply file filter
        if [ -n "$file_filter" ]; then
            echo "🔍 Applying file filter: $file_filter"
            find "$mount_point" -name "$file_filter" -exec cp --parents {} "$output_dir" \;
        else
            # Default selective extraction (important files only)
            echo "📋 Extracting important system files..."
            
            # Copy essential directories
            for dir in framework app priv-app lib lib64 bin etc; do
                if [ -d "$mount_point/$dir" ]; then
                    echo "📁 Copying $dir..."
                    cp -a "$mount_point/$dir" "$output_dir/"
                fi
            done
            
            # Copy build.prop and other important files
            for file in build.prop default.prop; do
                if [ -f "$mount_point/$file" ]; then
                    cp "$mount_point/$file" "$output_dir/"
                fi
            done
        fi
        
        umount "$mount_point"
    else
        echo "❌ Failed to mount system.img for selective extraction"
        return 1
    fi
    
    rmdir "$mount_point" 2>/dev/null
}

# Function to extract apps only
extract_apps_only() {
    local system_img="$1"
    local output_dir="$2"
    local fs_type="$3"
    
    echo "📱 Extracting apps only from system.img..."
    
    local mount_point=$(mktemp -d)
    
    if [ "$fs_type" == "erofs" ]; then
        mount -t erofs -o loop "$system_img" "$mount_point" 2>/dev/null
    elif [ "$fs_type" == "ext4" ]; then
        mount -t ext4 -o loop,ro "$system_img" "$mount_point" 2>/dev/null
    fi
    
    if mountpoint -q "$mount_point"; then
        # Extract app directories
        for app_dir in app priv-app; do
            if [ -d "$mount_point/$app_dir" ]; then
                echo "📱 Extracting $app_dir..."
                mkdir -p "$output_dir/$app_dir"
                cp -a "$mount_point/$app_dir"/* "$output_dir/$app_dir/"
            fi
        done
        
        umount "$mount_point"
    else
        echo "❌ Failed to mount system.img for app extraction"
        return 1
    fi
    
    rmdir "$mount_point" 2>/dev/null
}

# Function to modify system.img
modify_system_img() {
    local system_img="$1"
    local modifications_dir="$2"
    local output_img="$3"
    local compression="$4"
    
    echo "🔧 Modifying system.img..."
    
    local temp_dir=$(mktemp -d)
    local work_dir="$temp_dir/system"
    
    # Extract current system.img
    extract_system_img "$system_img" "$temp_dir" "full"
    mv "$temp_dir/extracted" "$work_dir"
    
    # Apply modifications
    if [ -d "$modifications_dir" ]; then
        echo "📝 Applying modifications from $modifications_dir"
        
        # Copy new/modified files
        if [ -d "$modifications_dir/overlay" ]; then
            echo "🔄 Applying overlay files..."
            cp -a "$modifications_dir/overlay"/* "$work_dir/"
        fi
        
        # Remove files listed in remove.txt
        if [ -f "$modifications_dir/remove.txt" ]; then
            echo "🗑️ Removing files listed in remove.txt..."
            while IFS= read -r file_to_remove; do
                if [ -n "$file_to_remove" ] && [[ ! "$file_to_remove" =~ ^#.*$ ]]; then
                    rm -rf "$work_dir/$file_to_remove"
                    echo "   Removed: $file_to_remove"
                fi
            done < "$modifications_dir/remove.txt"
        fi
        
        # Apply patches
        if [ -d "$modifications_dir/patches" ]; then
            echo "🩹 Applying patches..."
            for patch_file in "$modifications_dir/patches"/*.patch; do
                if [ -f "$patch_file" ]; then
                    echo "   Applying: $(basename "$patch_file")"
                    (cd "$work_dir" && patch -p1 < "$patch_file")
                fi
            done
        fi
        
        # Run custom scripts
        if [ -f "$modifications_dir/custom_script.sh" ]; then
            echo "🔧 Running custom modification script..."
            chmod +x "$modifications_dir/custom_script.sh"
            (cd "$work_dir" && "$modifications_dir/custom_script.sh")
        fi
    fi
    
    # Create new system.img
    create_system_img "$work_dir" "$output_img" "$compression"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✅ System.img modification complete: $output_img"
}

# Function to create system.img
create_system_img() {
    local input_dir="$1"
    local output_img="$2"
    local compression="$3"
    
    echo "🏗️ Creating system.img..."
    
    if [ ! -d "$input_dir" ]; then
        echo "❌ Error: Input directory not found: $input_dir"
        return 1
    fi
    
    # Determine compression type
    local comp_flag=""
    case "$compression" in
        "lz4hc") comp_flag="-zlz4hc" ;;
        "lz4") comp_flag="-zlz4" ;;
        "lzma") comp_flag="-zlzma" ;;
        "none") comp_flag="" ;;
        *) comp_flag="-zlz4hc" ;;  # Default
    esac
    
    # Find appropriate file contexts
    local file_contexts=""
    if [ -f "$input_dir/etc/selinux/plat_file_contexts" ]; then
        file_contexts="$input_dir/etc/selinux/plat_file_contexts"
    elif [ -f "$LOCALPATH/patches/plat_file_contexts" ]; then
        file_contexts="$LOCALPATH/patches/plat_file_contexts"
    fi
    
    # Create EROFS image
    local mkfs_cmd="mkfs.erofs $comp_flag --ignore-mtime"
    if [ -n "$file_contexts" ]; then
        mkfs_cmd="$mkfs_cmd --file-contexts=$file_contexts"
    fi
    mkfs_cmd="$mkfs_cmd $output_img $input_dir"
    
    echo "🔨 Running: $mkfs_cmd"
    eval "$mkfs_cmd"
    
    if [ $? -eq 0 ]; then
        echo "✅ System.img created successfully: $output_img"
        ls -lh "$output_img"
        return 0
    else
        echo "❌ Error: Failed to create system.img"
        return 1
    fi
}

# Function to reverse port from system.img
reverse_port_system() {
    local source_system="$1"
    local target_system="$2"
    local feature_list="$3"
    local output_dir="$4"
    
    echo "🔄 Reverse porting from system.img..."
    
    local temp_dir=$(mktemp -d)
    local source_dir="$temp_dir/source"
    local target_dir="$temp_dir/target"
    
    # Extract both systems
    extract_system_img "$source_system" "$source_dir" "full"
    extract_system_img "$target_system" "$target_dir" "full"
    
    mv "$source_dir/extracted" "$source_dir/system"
    mv "$target_dir/extracted" "$target_dir/system"
    
    mkdir -p "$output_dir/reverse_port"
    
    # Process feature list
    if [ -f "$feature_list" ]; then
        echo "📋 Processing feature list from $feature_list"
        while IFS= read -r feature; do
            if [[ "$feature" =~ ^#.*$ ]] || [[ -z "$feature" ]]; then
                continue
            fi
            
            echo "🔍 Reverse porting feature: $feature"
            reverse_port_feature "$source_dir/system" "$target_dir/system" "$feature" "$output_dir/reverse_port"
        done < "$feature_list"
    else
        echo "🔍 Auto-detecting features to reverse port..."
        auto_detect_features "$source_dir/system" "$target_dir/system" "$output_dir/reverse_port"
    fi
    
    # Create reverse ported system.img
    create_system_img "$target_dir/system" "$output_dir/reverse_ported_system.img" "lz4hc"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✅ Reverse porting complete. Results in $output_dir"
}

# Function to reverse port specific feature
reverse_port_feature() {
    local source_dir="$1"
    local target_dir="$2"
    local feature="$3"
    local output_dir="$4"
    
    case "$feature" in
        "samsung_camera")
            echo "📷 Reverse porting Samsung Camera..."
            copy_if_exists "$source_dir/priv-app/SamsungCamera*" "$target_dir/priv-app/"
            copy_if_exists "$source_dir/lib*/libcamera*samsung*" "$target_dir/lib*/"
            ;;
        "samsung_gallery")
            echo "🖼️ Reverse porting Samsung Gallery..."
            copy_if_exists "$source_dir/priv-app/Gallery*" "$target_dir/priv-app/"
            copy_if_exists "$source_dir/app/Gallery*" "$target_dir/app/"
            ;;
        "samsung_keyboard")
            echo "⌨️ Reverse porting Samsung Keyboard..."
            copy_if_exists "$source_dir/app/SamsungIME*" "$target_dir/app/"
            copy_if_exists "$source_dir/app/Honeyboard*" "$target_dir/app/"
            ;;
        "edge_panels")
            echo "📱 Reverse porting Edge Panels..."
            copy_if_exists "$source_dir/priv-app/EdgePanels*" "$target_dir/priv-app/"
            copy_if_exists "$source_dir/app/EdgePanels*" "$target_dir/app/"
            ;;
        "good_lock")
            echo "🔧 Reverse porting Good Lock support..."
            copy_if_exists "$source_dir/priv-app/GoodLock*" "$target_dir/priv-app/"
            copy_if_exists "$source_dir/app/GoodLock*" "$target_dir/app/"
            ;;
        *)
            echo "❓ Unknown feature: $feature"
            ;;
    esac
    
    # Log reverse ported feature
    echo "$feature" >> "$output_dir/reverse_ported_features.txt"
}

# Function to auto-detect features for reverse porting
auto_detect_features() {
    local source_dir="$1"
    local target_dir="$2"
    local output_dir="$3"
    
    echo "🤖 Auto-detecting features for reverse porting..."
    
    # Compare app directories
    if [ -d "$source_dir/priv-app" ] && [ -d "$target_dir/priv-app" ]; then
        for app in "$source_dir/priv-app"/*; do
            if [ -d "$app" ]; then
                local app_name=$(basename "$app")
                if [ ! -d "$target_dir/priv-app/$app_name" ]; then
                    echo "🆕 Found new privileged app: $app_name"
                    cp -a "$app" "$target_dir/priv-app/"
                    echo "$app_name" >> "$output_dir/auto_detected_features.txt"
                fi
            fi
        done
    fi
    
    # Compare framework files
    if [ -d "$source_dir/framework" ] && [ -d "$target_dir/framework" ]; then
        for framework_file in "$source_dir/framework"/*; do
            if [ -f "$framework_file" ]; then
                local file_name=$(basename "$framework_file")
                if [ ! -f "$target_dir/framework/$file_name" ]; then
                    echo "🆕 Found new framework file: $file_name"
                    cp "$framework_file" "$target_dir/framework/"
                    echo "framework/$file_name" >> "$output_dir/auto_detected_features.txt"
                fi
            fi
        done
    fi
}

# Helper function to copy files if they exist
copy_if_exists() {
    local source_pattern="$1"
    local target_dir="$2"
    
    for file in $source_pattern; do
        if [ -e "$file" ]; then
            cp -a "$file" "$target_dir/"
            echo "   Copied: $(basename "$file")"
        fi
    done
}

# Function to extract EROFS content (fallback method)
extract_erofs_content() {
    local erofs_img="$1"
    local output_dir="$2"
    
    echo "🔧 Using alternative EROFS extraction method..."
    
    # Try using fsck.erofs if available
    if command -v fsck.erofs >/dev/null 2>&1; then
        fsck.erofs --extract="$output_dir" "$erofs_img"
    else
        echo "⚠️ fsck.erofs not available, using basic extraction..."
        # Implement basic extraction logic here
        mkdir -p "$output_dir"
        echo "❌ EROFS extraction not fully implemented without fsck.erofs"
        return 1
    fi
}

# Function to validate system.img
validate_system_img() {
    local system_img="$1"
    
    echo "🔍 Validating system.img..."
    
    if [ ! -f "$system_img" ]; then
        echo "❌ Error: System.img not found at $system_img"
        return 1
    fi
    
    # Check file type
    local file_type=$(file "$system_img")
    echo "📋 File type: $file_type"
    
    if echo "$file_type" | grep -q "EROFS\|ext[234]"; then
        echo "✅ Valid filesystem detected"
    else
        echo "❌ Invalid or unknown filesystem"
        return 1
    fi
    
    # Try to mount and check basic structure
    local mount_point=$(mktemp -d)
    local mount_success=false
    
    if echo "$file_type" | grep -q "EROFS"; then
        if mount -t erofs -o loop "$system_img" "$mount_point" 2>/dev/null; then
            mount_success=true
        fi
    elif echo "$file_type" | grep -q "ext[234]"; then
        if mount -t ext4 -o loop,ro "$system_img" "$mount_point" 2>/dev/null; then
            mount_success=true
        fi
    fi
    
    if [ "$mount_success" = true ]; then
        echo "✅ Successfully mounted system.img"
        
        # Check for essential directories
        local essential_dirs=("app" "priv-app" "framework" "lib" "bin")
        local missing_dirs=()
        
        for dir in "${essential_dirs[@]}"; do
            if [ ! -d "$mount_point/$dir" ]; then
                missing_dirs+=("$dir")
            fi
        done
        
        if [ ${#missing_dirs[@]} -eq 0 ]; then
            echo "✅ All essential directories present"
        else
            echo "⚠️ Missing directories: ${missing_dirs[*]}"
        fi
        
        umount "$mount_point"
    else
        echo "❌ Failed to mount system.img"
        rmdir "$mount_point" 2>/dev/null
        return 1
    fi
    
    rmdir "$mount_point" 2>/dev/null
    echo "✅ System.img validation complete"
}

# Main function for system.img processing
main() {
    case "$1" in
        "analyze")
            analyze_system_img "$2" "$3"
            ;;
        "extract")
            extract_system_img "$2" "$3" "$4" "$5"
            ;;
        "modify")
            modify_system_img "$2" "$3" "$4" "$5"
            ;;
        "create")
            create_system_img "$2" "$3" "$4"
            ;;
        "reverse_port")
            reverse_port_system "$2" "$3" "$4" "$5"
            ;;
        "validate")
            validate_system_img "$2"
            ;;
        *)
            echo "Usage: $0 {analyze|extract|modify|create|reverse_port|validate} [options]"
            echo ""
            echo "Commands:"
            echo "  analyze <system.img> <output_dir>                           - Analyze system.img"
            echo "  extract <system.img> <output_dir> <mode> [filter]           - Extract system.img"
            echo "  modify <system.img> <modifications_dir> <output_img> [comp] - Modify system.img"
            echo "  create <input_dir> <output_img> [compression]               - Create system.img"
            echo "  reverse_port <source_sys> <target_sys> <features> <out_dir> - Reverse port features"
            echo "  validate <system.img>                                       - Validate system.img"
            echo ""
            echo "Extraction modes: full, selective, apps_only"
            echo "Compression types: lz4hc, lz4, lzma, none"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

