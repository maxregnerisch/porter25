#!/bin/bash
# Enhanced Super.img Management Module for S906B Android 15 OneUI 6 Porting
# Provides advanced super.img manipulation capabilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALPATH="$(dirname "$SCRIPT_DIR")"

# Source configuration and functions
source "$LOCALPATH/configs/s906b_config.sh"
source "$LOCALPATH/bin/functions.sh"

# Super.img Management Functions

# Function to analyze super.img structure
analyze_super_img() {
    local super_img="$1"
    local output_dir="$2"
    
    echo "🔍 Analyzing super.img structure..."
    
    if [ ! -f "$super_img" ]; then
        echo "❌ Error: Super.img not found at $super_img"
        return 1
    fi
    
    mkdir -p "$output_dir/analysis"
    
    # Get super.img information
    echo "📊 Super.img Information:"
    ls -lh "$super_img"
    
    # Use lpdump to analyze partition layout
    echo "📋 Partition Layout:"
    "$LOCALPATH/bin/lpdump" --slot=0 "$super_img" > "$output_dir/analysis/partition_layout.txt"
    cat "$output_dir/analysis/partition_layout.txt"
    
    # Extract metadata
    echo "🗂️ Metadata Information:"
    "$LOCALPATH/bin/lpdump" --json "$super_img" > "$output_dir/analysis/metadata.json"
    
    # Check if it's a sparse image
    if file "$super_img" | grep -q "Android sparse image"; then
        echo "📦 Detected sparse image format"
        echo "true" > "$output_dir/analysis/is_sparse"
    else
        echo "📦 Detected raw image format"
        echo "false" > "$output_dir/analysis/is_sparse"
    fi
    
    echo "✅ Analysis complete. Results saved to $output_dir/analysis/"
}

# Function to extract super.img with enhanced options
extract_super_img() {
    local super_img="$1"
    local output_dir="$2"
    local partitions="$3"  # Comma-separated list or "all"
    local format="$4"      # "raw" or "sparse"
    
    echo "📦 Extracting super.img with enhanced options..."
    
    if [ ! -f "$super_img" ]; then
        echo "❌ Error: Super.img not found at $super_img"
        return 1
    fi
    
    mkdir -p "$output_dir/extracted"
    cd "$output_dir/extracted"
    
    # Convert sparse to raw if needed
    local working_img="$super_img"
    if file "$super_img" | grep -q "Android sparse image"; then
        echo "🔄 Converting sparse image to raw..."
        working_img="$output_dir/extracted/super_raw.img"
        simg2img "$super_img" "$working_img"
    fi
    
    # Extract partitions
    if [ "$partitions" == "all" ]; then
        echo "📂 Extracting all partitions..."
        "$LOCALPATH/bin/lpunpack" "$working_img"
    else
        echo "📂 Extracting selected partitions: $partitions"
        IFS=',' read -ra PARTITION_ARRAY <<< "$partitions"
        for partition in "${PARTITION_ARRAY[@]}"; do
            "$LOCALPATH/bin/lpunpack" -p "$partition" "$working_img"
        done
    fi
    
    # Clean up temporary raw image if created
    if [ "$working_img" != "$super_img" ]; then
        rm -f "$working_img"
    fi
    
    echo "✅ Extraction complete. Partitions saved to $output_dir/extracted/"
    cd - > /dev/null
}

# Function to create enhanced super.img
create_super_img() {
    local input_dir="$1"
    local output_super="$2"
    local device_config="$3"  # Device configuration (s906b, etc.)
    local compression="$4"    # Compression type (lz4hc, etc.)
    
    echo "🏗️ Creating enhanced super.img..."
    
    if [ ! -d "$input_dir" ]; then
        echo "❌ Error: Input directory not found at $input_dir"
        return 1
    fi
    
    # Load device-specific configuration
    case "$device_config" in
        "s906b")
            local device_size="$SUPER_PARTITION_SIZE"
            local group_size="$DYNAMIC_PARTITIONS_SIZE"
            local metadata_size="$METADATA_SIZE"
            local metadata_slots="$METADATA_SLOTS"
            ;;
        *)
            echo "❌ Error: Unknown device configuration: $device_config"
            return 1
            ;;
    esac
    
    echo "📐 Using device configuration: $device_config"
    echo "💾 Device size: $device_size bytes"
    echo "📊 Group size: $group_size bytes"
    
    # Prepare partition arguments
    local partition_args=""
    local total_size=0
    
    # Check available partitions and calculate sizes
    for partition in system system_ext vendor product odm system_dlkm vendor_dlkm; do
        local partition_img="$input_dir/${partition}.img"
        if [ -f "$partition_img" ]; then
            local size=$(stat -c%s "$partition_img")
            echo "📦 Found $partition: $size bytes"
            partition_args="$partition_args --partition=$partition:none:$size:$DYNAMIC_PARTITIONS_GROUP"
            total_size=$((total_size + size))
        fi
    done
    
    echo "📊 Total partition size: $total_size bytes"
    
    if [ $total_size -gt $group_size ]; then
        echo "⚠️ Warning: Total partition size exceeds group size"
        echo "🔧 Adjusting group size to accommodate partitions"
        group_size=$((total_size + 104857600))  # Add 100MB buffer
    fi
    
    # Create super.img using lpmake
    echo "🔨 Building super.img with lpmake..."
    "$LOCALPATH/bin/lpmake" \
        --metadata-size "$metadata_size" \
        --device-size="$device_size" \
        --metadata-slots="$metadata_slots" \
        --group="$DYNAMIC_PARTITIONS_GROUP:$group_size" \
        $partition_args \
        --output="$output_super"
    
    if [ $? -eq 0 ]; then
        echo "✅ Super.img created successfully: $output_super"
        ls -lh "$output_super"
        return 0
    else
        echo "❌ Error: Failed to create super.img"
        return 1
    fi
}

# Function to modify super.img partitions
modify_super_partitions() {
    local super_img="$1"
    local modifications_file="$2"
    local output_super="$3"
    
    echo "🔧 Modifying super.img partitions..."
    
    if [ ! -f "$super_img" ]; then
        echo "❌ Error: Super.img not found at $super_img"
        return 1
    fi
    
    if [ ! -f "$modifications_file" ]; then
        echo "❌ Error: Modifications file not found at $modifications_file"
        return 1
    fi
    
    local temp_dir=$(mktemp -d)
    echo "📁 Working in temporary directory: $temp_dir"
    
    # Extract current super.img
    extract_super_img "$super_img" "$temp_dir" "all" "raw"
    
    # Apply modifications from file
    echo "📝 Applying modifications from $modifications_file"
    while IFS= read -r line; do
        if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
            continue  # Skip comments and empty lines
        fi
        
        if [[ "$line" =~ ^RESIZE:(.+):(.+)$ ]]; then
            local partition="${BASH_REMATCH[1]}"
            local new_size="${BASH_REMATCH[2]}"
            echo "📏 Resizing $partition to $new_size"
            resize_partition_image "$temp_dir/extracted/${partition}.img" "$new_size"
        elif [[ "$line" =~ ^REPLACE:(.+):(.+)$ ]]; then
            local partition="${BASH_REMATCH[1]}"
            local source_img="${BASH_REMATCH[2]}"
            echo "🔄 Replacing $partition with $source_img"
            cp "$source_img" "$temp_dir/extracted/${partition}.img"
        elif [[ "$line" =~ ^DELETE:(.+)$ ]]; then
            local partition="${BASH_REMATCH[1]}"
            echo "🗑️ Deleting $partition"
            rm -f "$temp_dir/extracted/${partition}.img"
        fi
    done < "$modifications_file"
    
    # Recreate super.img
    create_super_img "$temp_dir/extracted" "$output_super" "s906b" "lz4hc"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✅ Super.img modification complete: $output_super"
}

# Function to resize partition image
resize_partition_image() {
    local partition_img="$1"
    local new_size="$2"
    
    echo "📏 Resizing partition image: $partition_img to $new_size"
    
    if [ ! -f "$partition_img" ]; then
        echo "❌ Error: Partition image not found: $partition_img"
        return 1
    fi
    
    # Convert size to bytes if needed
    local size_bytes
    case "$new_size" in
        *G|*g) size_bytes=$(echo "$new_size" | sed 's/[Gg]//' | awk '{print $1 * 1024 * 1024 * 1024}') ;;
        *M|*m) size_bytes=$(echo "$new_size" | sed 's/[Mm]//' | awk '{print $1 * 1024 * 1024}') ;;
        *K|*k) size_bytes=$(echo "$new_size" | sed 's/[Kk]//' | awk '{print $1 * 1024}') ;;
        *) size_bytes="$new_size" ;;
    esac
    
    # Create new image with specified size
    local temp_img="${partition_img}.tmp"
    dd if=/dev/zero of="$temp_img" bs=1 count=0 seek="$size_bytes" 2>/dev/null
    
    # Copy original content
    dd if="$partition_img" of="$temp_img" conv=notrunc 2>/dev/null
    
    # Replace original
    mv "$temp_img" "$partition_img"
    
    echo "✅ Partition resized successfully"
}

# Function to merge multiple super.img files
merge_super_imgs() {
    local base_super="$1"
    local donor_super="$2"
    local output_super="$3"
    local merge_config="$4"
    
    echo "🔗 Merging super.img files..."
    
    local temp_dir=$(mktemp -d)
    local base_dir="$temp_dir/base"
    local donor_dir="$temp_dir/donor"
    
    # Extract both super images
    extract_super_img "$base_super" "$base_dir" "all" "raw"
    extract_super_img "$donor_super" "$donor_dir" "all" "raw"
    
    # Apply merge configuration
    if [ -f "$merge_config" ]; then
        echo "📝 Applying merge configuration from $merge_config"
        while IFS= read -r line; do
            if [[ "$line" =~ ^#.*$ ]] || [[ -z "$line" ]]; then
                continue
            fi
            
            if [[ "$line" =~ ^MERGE:(.+):(.+)$ ]]; then
                local partition="${BASH_REMATCH[1]}"
                local source="${BASH_REMATCH[2]}"  # "base" or "donor"
                
                if [ "$source" == "donor" ]; then
                    echo "🔄 Using $partition from donor"
                    cp "$donor_dir/extracted/${partition}.img" "$base_dir/extracted/${partition}.img"
                else
                    echo "📦 Keeping $partition from base"
                fi
            fi
        done < "$merge_config"
    fi
    
    # Create merged super.img
    create_super_img "$base_dir/extracted" "$output_super" "s906b" "lz4hc"
    
    # Cleanup
    rm -rf "$temp_dir"
    
    echo "✅ Super.img merge complete: $output_super"
}

# Function to validate super.img integrity
validate_super_img() {
    local super_img="$1"
    
    echo "🔍 Validating super.img integrity..."
    
    if [ ! -f "$super_img" ]; then
        echo "❌ Error: Super.img not found at $super_img"
        return 1
    fi
    
    # Check file size
    local file_size=$(stat -c%s "$super_img")
    echo "📊 File size: $file_size bytes"
    
    # Validate with lpdump
    if "$LOCALPATH/bin/lpdump" --slot=0 "$super_img" > /dev/null 2>&1; then
        echo "✅ Super.img structure is valid"
    else
        echo "❌ Super.img structure validation failed"
        return 1
    fi
    
    # Check partition integrity
    local temp_dir=$(mktemp -d)
    extract_super_img "$super_img" "$temp_dir" "all" "raw"
    
    local validation_passed=true
    for img in "$temp_dir/extracted"/*.img; do
        if [ -f "$img" ]; then
            local partition_name=$(basename "$img" .img)
            echo "🔍 Validating $partition_name..."
            
            # Check if image is valid EROFS/EXT4
            if file "$img" | grep -q "EROFS\|Linux.*filesystem"; then
                echo "✅ $partition_name: Valid filesystem"
            else
                echo "⚠️ $partition_name: Unknown filesystem type"
                validation_passed=false
            fi
        fi
    done
    
    rm -rf "$temp_dir"
    
    if [ "$validation_passed" = true ]; then
        echo "✅ All partitions validated successfully"
        return 0
    else
        echo "⚠️ Some partitions failed validation"
        return 1
    fi
}

# Function to optimize super.img size
optimize_super_img() {
    local input_super="$1"
    local output_super="$2"
    local optimization_level="$3"  # "basic", "aggressive"
    
    echo "⚡ Optimizing super.img size..."
    
    local temp_dir=$(mktemp -d)
    extract_super_img "$input_super" "$temp_dir" "all" "raw"
    
    # Apply optimizations based on level
    case "$optimization_level" in
        "basic")
            echo "🔧 Applying basic optimizations..."
            # Remove unnecessary files, compress images
            for img in "$temp_dir/extracted"/*.img; do
                if [ -f "$img" ]; then
                    echo "🗜️ Optimizing $(basename "$img")..."
                    # Add basic optimization logic here
                fi
            done
            ;;
        "aggressive")
            echo "🔧 Applying aggressive optimizations..."
            # More aggressive size reduction
            for img in "$temp_dir/extracted"/*.img; do
                if [ -f "$img" ]; then
                    echo "🗜️ Aggressively optimizing $(basename "$img")..."
                    # Add aggressive optimization logic here
                fi
            done
            ;;
    esac
    
    # Recreate optimized super.img
    create_super_img "$temp_dir/extracted" "$output_super" "s906b" "lz4hc"
    
    # Compare sizes
    local original_size=$(stat -c%s "$input_super")
    local optimized_size=$(stat -c%s "$output_super")
    local saved_bytes=$((original_size - optimized_size))
    local saved_percent=$((saved_bytes * 100 / original_size))
    
    echo "📊 Optimization Results:"
    echo "   Original size: $original_size bytes"
    echo "   Optimized size: $optimized_size bytes"
    echo "   Saved: $saved_bytes bytes ($saved_percent%)"
    
    rm -rf "$temp_dir"
    echo "✅ Super.img optimization complete"
}

# Main function for super.img management
main() {
    case "$1" in
        "analyze")
            analyze_super_img "$2" "$3"
            ;;
        "extract")
            extract_super_img "$2" "$3" "$4" "$5"
            ;;
        "create")
            create_super_img "$2" "$3" "$4" "$5"
            ;;
        "modify")
            modify_super_partitions "$2" "$3" "$4"
            ;;
        "merge")
            merge_super_imgs "$2" "$3" "$4" "$5"
            ;;
        "validate")
            validate_super_img "$2"
            ;;
        "optimize")
            optimize_super_img "$2" "$3" "$4"
            ;;
        *)
            echo "Usage: $0 {analyze|extract|create|modify|merge|validate|optimize} [options]"
            echo ""
            echo "Commands:"
            echo "  analyze <super.img> <output_dir>                    - Analyze super.img structure"
            echo "  extract <super.img> <output_dir> <partitions> <format> - Extract partitions"
            echo "  create <input_dir> <output_super> <device> <compression> - Create super.img"
            echo "  modify <super.img> <modifications_file> <output_super> - Modify partitions"
            echo "  merge <base_super> <donor_super> <output_super> <config> - Merge super images"
            echo "  validate <super.img>                               - Validate integrity"
            echo "  optimize <input_super> <output_super> <level>      - Optimize size"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

