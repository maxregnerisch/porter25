#!/bin/bash
# Reverse Porting Engine for S906B Android 15 OneUI 6
# Extracts features and modifications from custom ROMs and applies them to base ROMs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALPATH="$(dirname "$SCRIPT_DIR")"

# Source configuration and functions
source "$LOCALPATH/configs/s906b_config.sh"
source "$LOCALPATH/bin/functions.sh"

# Reverse Porting Engine Functions

# Function to analyze ROM for reverse porting opportunities
analyze_rom_for_reverse_port() {
    local rom_path="$1"
    local analysis_output="$2"
    local comparison_base="$3"  # Optional base ROM for comparison
    
    echo "🔍 Analyzing ROM for reverse porting opportunities..."
    
    if [ ! -d "$rom_path" ]; then
        echo "❌ Error: ROM path not found: $rom_path"
        return 1
    fi
    
    mkdir -p "$analysis_output"
    
    # Analyze ROM structure
    echo "📋 Analyzing ROM structure..."
    find "$rom_path" -type f -name "*.apk" > "$analysis_output/apk_inventory.txt"
    find "$rom_path" -type f -name "*.jar" > "$analysis_output/jar_inventory.txt"
    find "$rom_path" -type f -name "*.so" > "$analysis_output/so_inventory.txt"
    find "$rom_path" -type f -name "*.xml" > "$analysis_output/xml_inventory.txt"
    
    echo "📱 Found $(wc -l < "$analysis_output/apk_inventory.txt") APK files"
    echo "☕ Found $(wc -l < "$analysis_output/jar_inventory.txt") JAR files"
    echo "🔧 Found $(wc -l < "$analysis_output/so_inventory.txt") SO libraries"
    echo "📄 Found $(wc -l < "$analysis_output/xml_inventory.txt") XML files"
    
    # Detect custom features
    detect_custom_features "$rom_path" "$analysis_output"
    
    # Detect modifications
    detect_modifications "$rom_path" "$analysis_output"
    
    # Compare with base ROM if provided
    if [ -n "$comparison_base" ] && [ -d "$comparison_base" ]; then
        echo "🔄 Comparing with base ROM..."
        compare_roms "$rom_path" "$comparison_base" "$analysis_output"
    fi
    
    # Generate reverse porting report
    generate_reverse_port_report "$analysis_output"
    
    echo "✅ ROM analysis complete. Report saved to $analysis_output"
}

# Function to detect custom features in ROM
detect_custom_features() {
    local rom_path="$1"
    local output_dir="$2"
    
    echo "🔍 Detecting custom features..."
    
    local features_file="$output_dir/detected_features.txt"
    > "$features_file"
    
    # Check for custom launchers
    if find "$rom_path" -name "*launcher*" -o -name "*home*" | grep -v "com.android.launcher" | head -1 >/dev/null; then
        echo "custom_launcher" >> "$features_file"
        echo "🏠 Detected custom launcher"
    fi
    
    # Check for custom camera apps
    if find "$rom_path" -name "*camera*" | grep -v "com.android.camera" | head -1 >/dev/null; then
        echo "custom_camera" >> "$features_file"
        echo "📷 Detected custom camera"
    fi
    
    # Check for custom keyboards
    if find "$rom_path" -name "*keyboard*" -o -name "*ime*" | grep -v "com.android.inputmethod" | head -1 >/dev/null; then
        echo "custom_keyboard" >> "$features_file"
        echo "⌨️ Detected custom keyboard"
    fi
    
    # Check for custom themes
    if find "$rom_path" -name "*theme*" -o -name "*substratum*" -o -name "*overlay*" | head -1 >/dev/null; then
        echo "custom_themes" >> "$features_file"
        echo "🎨 Detected custom themes"
    fi
    
    # Check for performance mods
    if find "$rom_path" -name "*performance*" -o -name "*boost*" -o -name "*optimizer*" | head -1 >/dev/null; then
        echo "performance_mods" >> "$features_file"
        echo "⚡ Detected performance modifications"
    fi
    
    # Check for privacy/security mods
    if find "$rom_path" -name "*privacy*" -o -name "*security*" -o -name "*firewall*" | head -1 >/dev/null; then
        echo "privacy_mods" >> "$features_file"
        echo "🔒 Detected privacy/security modifications"
    fi
    
    # Check for audio enhancements
    if find "$rom_path" -name "*viper*" -o -name "*dolby*" -o -name "*audio*fx*" | head -1 >/dev/null; then
        echo "audio_enhancements" >> "$features_file"
        echo "🔊 Detected audio enhancements"
    fi
    
    # Check for custom recovery
    if find "$rom_path" -name "*recovery*" -o -name "*twrp*" -o -name "*cwm*" | head -1 >/dev/null; then
        echo "custom_recovery" >> "$features_file"
        echo "🔧 Detected custom recovery"
    fi
    
    # Check for root/superuser
    if find "$rom_path" -name "*su*" -o -name "*superuser*" -o -name "*magisk*" | head -1 >/dev/null; then
        echo "root_access" >> "$features_file"
        echo "👑 Detected root access"
    fi
    
    # Check for custom bootanimation
    if find "$rom_path" -name "bootanimation.zip" | head -1 >/dev/null; then
        echo "custom_bootanimation" >> "$features_file"
        echo "🎬 Detected custom boot animation"
    fi
    
    echo "✅ Feature detection complete. Found $(wc -l < "$features_file") features"
}

# Function to detect modifications in ROM
detect_modifications() {
    local rom_path="$1"
    local output_dir="$2"
    
    echo "🔍 Detecting ROM modifications..."
    
    local mods_file="$output_dir/detected_modifications.txt"
    > "$mods_file"
    
    # Check build.prop modifications
    if [ -f "$rom_path/system/build.prop" ]; then
        echo "📝 Analyzing build.prop modifications..."
        
        # Look for custom properties
        grep -E "^ro\.custom\.|^ro\.mod\.|^ro\.rom\." "$rom_path/system/build.prop" > "$output_dir/custom_props.txt" 2>/dev/null
        if [ -s "$output_dir/custom_props.txt" ]; then
            echo "build_prop_mods" >> "$mods_file"
            echo "📋 Detected build.prop modifications"
        fi
    fi
    
    # Check for framework modifications
    if [ -d "$rom_path/system/framework" ]; then
        echo "🏗️ Analyzing framework modifications..."
        
        # Look for custom framework files
        find "$rom_path/system/framework" -name "*custom*" -o -name "*mod*" > "$output_dir/custom_framework.txt"
        if [ -s "$output_dir/custom_framework.txt" ]; then
            echo "framework_mods" >> "$mods_file"
            echo "🏗️ Detected framework modifications"
        fi
    fi
    
    # Check for init.d support
    if [ -d "$rom_path/system/etc/init.d" ]; then
        echo "init_d_support" >> "$mods_file"
        echo "🔧 Detected init.d support"
    fi
    
    # Check for custom fonts
    if [ -d "$rom_path/system/fonts" ]; then
        local font_count=$(find "$rom_path/system/fonts" -name "*.ttf" -o -name "*.otf" | wc -l)
        if [ "$font_count" -gt 20 ]; then  # Assuming stock has ~20 fonts
            echo "custom_fonts" >> "$mods_file"
            echo "🔤 Detected custom fonts"
        fi
    fi
    
    # Check for custom media files
    if [ -d "$rom_path/system/media" ]; then
        echo "🎵 Analyzing media modifications..."
        
        # Check for custom ringtones/notifications
        local media_count=$(find "$rom_path/system/media" -name "*.ogg" -o -name "*.mp3" | wc -l)
        if [ "$media_count" -gt 50 ]; then  # Assuming stock has ~50 media files
            echo "custom_media" >> "$mods_file"
            echo "🎵 Detected custom media files"
        fi
    fi
    
    # Check for custom wallpapers
    if find "$rom_path" -name "*wallpaper*" | head -1 >/dev/null; then
        echo "custom_wallpapers" >> "$mods_file"
        echo "🖼️ Detected custom wallpapers"
    fi
    
    echo "✅ Modification detection complete. Found $(wc -l < "$mods_file") modifications"
}

# Function to compare two ROMs
compare_roms() {
    local custom_rom="$1"
    local base_rom="$2"
    local output_dir="$3"
    
    echo "🔄 Comparing custom ROM with base ROM..."
    
    local comparison_file="$output_dir/rom_comparison.txt"
    > "$comparison_file"
    
    # Compare APK files
    echo "📱 Comparing APK files..."
    find "$custom_rom" -name "*.apk" | sed "s|$custom_rom||" | sort > "$output_dir/custom_apks.txt"
    find "$base_rom" -name "*.apk" | sed "s|$base_rom||" | sort > "$output_dir/base_apks.txt"
    
    # Find new APKs in custom ROM
    comm -23 "$output_dir/custom_apks.txt" "$output_dir/base_apks.txt" > "$output_dir/new_apks.txt"
    echo "🆕 New APKs in custom ROM: $(wc -l < "$output_dir/new_apks.txt")"
    
    # Find removed APKs from base ROM
    comm -13 "$output_dir/custom_apks.txt" "$output_dir/base_apks.txt" > "$output_dir/removed_apks.txt"
    echo "🗑️ Removed APKs from base ROM: $(wc -l < "$output_dir/removed_apks.txt")"
    
    # Compare file sizes for common APKs
    echo "📊 Comparing file sizes for modified APKs..."
    comm -12 "$output_dir/custom_apks.txt" "$output_dir/base_apks.txt" | while read apk_path; do
        local custom_size=$(stat -c%s "$custom_rom$apk_path" 2>/dev/null || echo "0")
        local base_size=$(stat -c%s "$base_rom$apk_path" 2>/dev/null || echo "0")
        
        if [ "$custom_size" != "$base_size" ]; then
            echo "$apk_path: $base_size -> $custom_size" >> "$output_dir/modified_apks.txt"
        fi
    done
    
    if [ -f "$output_dir/modified_apks.txt" ]; then
        echo "🔄 Modified APKs: $(wc -l < "$output_dir/modified_apks.txt")"
    fi
    
    # Compare build.prop files
    if [ -f "$custom_rom/system/build.prop" ] && [ -f "$base_rom/system/build.prop" ]; then
        echo "📋 Comparing build.prop files..."
        diff "$base_rom/system/build.prop" "$custom_rom/system/build.prop" > "$output_dir/build_prop_diff.txt" 2>/dev/null
        if [ -s "$output_dir/build_prop_diff.txt" ]; then
            echo "📝 Build.prop differences found"
        fi
    fi
    
    echo "✅ ROM comparison complete"
}

# Function to extract specific features from ROM
extract_features() {
    local source_rom="$1"
    local feature_list="$2"
    local output_dir="$3"
    local extraction_mode="$4"  # "copy", "link", "package"
    
    echo "📦 Extracting features from ROM..."
    
    if [ ! -f "$feature_list" ]; then
        echo "❌ Error: Feature list not found: $feature_list"
        return 1
    fi
    
    mkdir -p "$output_dir/extracted_features"
    
    while IFS= read -r feature; do
        if [[ "$feature" =~ ^#.*$ ]] || [[ -z "$feature" ]]; then
            continue
        fi
        
        echo "📦 Extracting feature: $feature"
        extract_single_feature "$source_rom" "$feature" "$output_dir/extracted_features" "$extraction_mode"
    done < "$feature_list"
    
    # Create extraction manifest
    create_extraction_manifest "$output_dir/extracted_features" "$output_dir/extraction_manifest.txt"
    
    echo "✅ Feature extraction complete"
}

# Function to extract a single feature
extract_single_feature() {
    local source_rom="$1"
    local feature="$2"
    local output_dir="$3"
    local mode="$4"
    
    local feature_dir="$output_dir/$feature"
    mkdir -p "$feature_dir"
    
    case "$feature" in
        "custom_launcher")
            echo "🏠 Extracting custom launcher..."
            find "$source_rom" -name "*launcher*" -o -name "*home*" | grep -v "com.android.launcher" | while read launcher; do
                extract_file_or_dir "$launcher" "$feature_dir" "$mode"
            done
            ;;
        "custom_camera")
            echo "📷 Extracting custom camera..."
            find "$source_rom" -name "*camera*" | grep -v "com.android.camera" | while read camera; do
                extract_file_or_dir "$camera" "$feature_dir" "$mode"
            done
            ;;
        "custom_keyboard")
            echo "⌨️ Extracting custom keyboard..."
            find "$source_rom" -name "*keyboard*" -o -name "*ime*" | grep -v "com.android.inputmethod" | while read keyboard; do
                extract_file_or_dir "$keyboard" "$feature_dir" "$mode"
            done
            ;;
        "audio_enhancements")
            echo "🔊 Extracting audio enhancements..."
            find "$source_rom" -name "*viper*" -o -name "*dolby*" -o -name "*audio*fx*" | while read audio; do
                extract_file_or_dir "$audio" "$feature_dir" "$mode"
            done
            ;;
        "performance_mods")
            echo "⚡ Extracting performance modifications..."
            find "$source_rom" -name "*performance*" -o -name "*boost*" -o -name "*optimizer*" | while read perf; do
                extract_file_or_dir "$perf" "$feature_dir" "$mode"
            done
            ;;
        "custom_themes")
            echo "🎨 Extracting custom themes..."
            find "$source_rom" -name "*theme*" -o -name "*substratum*" -o -name "*overlay*" | while read theme; do
                extract_file_or_dir "$theme" "$feature_dir" "$mode"
            done
            ;;
        *)
            echo "❓ Unknown feature: $feature"
            ;;
    esac
    
    # Create feature metadata
    echo "Feature: $feature" > "$feature_dir/metadata.txt"
    echo "Extracted: $(date)" >> "$feature_dir/metadata.txt"
    echo "Source ROM: $source_rom" >> "$feature_dir/metadata.txt"
    echo "Extraction Mode: $mode" >> "$feature_dir/metadata.txt"
}

# Function to extract file or directory based on mode
extract_file_or_dir() {
    local source="$1"
    local dest_dir="$2"
    local mode="$3"
    
    if [ ! -e "$source" ]; then
        return
    fi
    
    local basename_source=$(basename "$source")
    local dest_path="$dest_dir/$basename_source"
    
    case "$mode" in
        "copy")
            cp -a "$source" "$dest_dir/"
            echo "   Copied: $basename_source"
            ;;
        "link")
            ln -sf "$source" "$dest_path"
            echo "   Linked: $basename_source"
            ;;
        "package")
            if [ -d "$source" ]; then
                tar -czf "$dest_path.tar.gz" -C "$(dirname "$source")" "$basename_source"
                echo "   Packaged: $basename_source.tar.gz"
            else
                cp "$source" "$dest_dir/"
                echo "   Copied: $basename_source"
            fi
            ;;
    esac
}

# Function to apply extracted features to target ROM
apply_features() {
    local target_rom="$1"
    local features_dir="$2"
    local application_config="$3"
    local backup_dir="$4"
    
    echo "🔧 Applying extracted features to target ROM..."
    
    if [ ! -d "$target_rom" ]; then
        echo "❌ Error: Target ROM not found: $target_rom"
        return 1
    fi
    
    if [ ! -d "$features_dir" ]; then
        echo "❌ Error: Features directory not found: $features_dir"
        return 1
    fi
    
    # Create backup if specified
    if [ -n "$backup_dir" ]; then
        echo "💾 Creating backup..."
        mkdir -p "$backup_dir"
        cp -a "$target_rom" "$backup_dir/original_rom_$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Apply features based on configuration
    if [ -f "$application_config" ]; then
        echo "📝 Applying features based on configuration..."
        while IFS= read -r config_line; do
            if [[ "$config_line" =~ ^#.*$ ]] || [[ -z "$config_line" ]]; then
                continue
            fi
            
            if [[ "$config_line" =~ ^APPLY:(.+):(.+)$ ]]; then
                local feature="${BASH_REMATCH[1]}"
                local target_path="${BASH_REMATCH[2]}"
                
                echo "🔧 Applying feature: $feature to $target_path"
                apply_single_feature "$features_dir/$feature" "$target_rom/$target_path"
            fi
        done < "$application_config"
    else
        echo "🤖 Auto-applying all extracted features..."
        for feature_dir in "$features_dir"/*; do
            if [ -d "$feature_dir" ]; then
                local feature_name=$(basename "$feature_dir")
                echo "🔧 Auto-applying feature: $feature_name"
                auto_apply_feature "$feature_dir" "$target_rom" "$feature_name"
            fi
        done
    fi
    
    echo "✅ Feature application complete"
}

# Function to apply a single feature
apply_single_feature() {
    local feature_dir="$1"
    local target_path="$2"
    
    if [ ! -d "$feature_dir" ]; then
        echo "❌ Feature directory not found: $feature_dir"
        return 1
    fi
    
    mkdir -p "$target_path"
    
    # Copy all files from feature directory to target
    for item in "$feature_dir"/*; do
        if [ -e "$item" ] && [ "$(basename "$item")" != "metadata.txt" ]; then
            cp -a "$item" "$target_path/"
            echo "   Applied: $(basename "$item")"
        fi
    done
}

# Function to auto-apply feature based on its type
auto_apply_feature() {
    local feature_dir="$1"
    local target_rom="$2"
    local feature_name="$3"
    
    case "$feature_name" in
        "custom_launcher")
            apply_single_feature "$feature_dir" "$target_rom/system/priv-app"
            ;;
        "custom_camera")
            apply_single_feature "$feature_dir" "$target_rom/system/priv-app"
            ;;
        "custom_keyboard")
            apply_single_feature "$feature_dir" "$target_rom/system/app"
            ;;
        "audio_enhancements")
            apply_single_feature "$feature_dir" "$target_rom/system/priv-app"
            # Also copy to vendor if needed
            apply_single_feature "$feature_dir" "$target_rom/vendor/app"
            ;;
        "performance_mods")
            apply_single_feature "$feature_dir" "$target_rom/system/app"
            ;;
        "custom_themes")
            apply_single_feature "$feature_dir" "$target_rom/system/app"
            ;;
        *)
            echo "❓ Unknown feature type, applying to system/app: $feature_name"
            apply_single_feature "$feature_dir" "$target_rom/system/app"
            ;;
    esac
}

# Function to create extraction manifest
create_extraction_manifest() {
    local features_dir="$1"
    local manifest_file="$2"
    
    echo "📋 Creating extraction manifest..."
    
    echo "# Reverse Porting Extraction Manifest" > "$manifest_file"
    echo "# Generated: $(date)" >> "$manifest_file"
    echo "" >> "$manifest_file"
    
    for feature_dir in "$features_dir"/*; do
        if [ -d "$feature_dir" ]; then
            local feature_name=$(basename "$feature_dir")
            echo "Feature: $feature_name" >> "$manifest_file"
            
            if [ -f "$feature_dir/metadata.txt" ]; then
                cat "$feature_dir/metadata.txt" | sed 's/^/  /' >> "$manifest_file"
            fi
            
            echo "  Files:" >> "$manifest_file"
            find "$feature_dir" -type f | grep -v metadata.txt | sed 's/^/    /' >> "$manifest_file"
            echo "" >> "$manifest_file"
        fi
    done
    
    echo "✅ Extraction manifest created: $manifest_file"
}

# Function to generate reverse porting report
generate_reverse_port_report() {
    local analysis_dir="$1"
    
    echo "📊 Generating reverse porting report..."
    
    local report_file="$analysis_dir/reverse_port_report.md"
    
    cat > "$report_file" << EOF
# Reverse Porting Analysis Report

Generated: $(date)

## ROM Analysis Summary

### Detected Features
EOF
    
    if [ -f "$analysis_dir/detected_features.txt" ]; then
        echo "" >> "$report_file"
        while read feature; do
            echo "- $feature" >> "$report_file"
        done < "$analysis_dir/detected_features.txt"
    fi
    
    cat >> "$report_file" << EOF

### Detected Modifications
EOF
    
    if [ -f "$analysis_dir/detected_modifications.txt" ]; then
        echo "" >> "$report_file"
        while read mod; do
            echo "- $mod" >> "$report_file"
        done < "$analysis_dir/detected_modifications.txt"
    fi
    
    cat >> "$report_file" << EOF

### File Inventory

- APK files: $(wc -l < "$analysis_dir/apk_inventory.txt" 2>/dev/null || echo "0")
- JAR files: $(wc -l < "$analysis_dir/jar_inventory.txt" 2>/dev/null || echo "0")
- SO libraries: $(wc -l < "$analysis_dir/so_inventory.txt" 2>/dev/null || echo "0")
- XML files: $(wc -l < "$analysis_dir/xml_inventory.txt" 2>/dev/null || echo "0")

### Recommendations

Based on the analysis, the following features are recommended for reverse porting:

EOF
    
    # Add recommendations based on detected features
    if [ -f "$analysis_dir/detected_features.txt" ]; then
        while read feature; do
            case "$feature" in
                "custom_launcher")
                    echo "- **Custom Launcher**: High priority - Can significantly improve user experience" >> "$report_file"
                    ;;
                "audio_enhancements")
                    echo "- **Audio Enhancements**: Medium priority - Improves audio quality" >> "$report_file"
                    ;;
                "performance_mods")
                    echo "- **Performance Mods**: High priority - Can improve system performance" >> "$report_file"
                    ;;
                "custom_camera")
                    echo "- **Custom Camera**: Medium priority - May improve camera functionality" >> "$report_file"
                    ;;
                *)
                    echo "- **$feature**: Evaluate based on user needs" >> "$report_file"
                    ;;
            esac
        done < "$analysis_dir/detected_features.txt"
    fi
    
    echo "" >> "$report_file"
    echo "### Next Steps" >> "$report_file"
    echo "" >> "$report_file"
    echo "1. Review the detected features and modifications" >> "$report_file"
    echo "2. Create a feature extraction list based on requirements" >> "$report_file"
    echo "3. Use the extract_features function to extract desired features" >> "$report_file"
    echo "4. Apply extracted features to target ROM using apply_features function" >> "$report_file"
    echo "5. Test the modified ROM thoroughly before deployment" >> "$report_file"
    
    echo "✅ Reverse porting report generated: $report_file"
}

# Main function for reverse porting engine
main() {
    case "$1" in
        "analyze")
            analyze_rom_for_reverse_port "$2" "$3" "$4"
            ;;
        "extract")
            extract_features "$2" "$3" "$4" "$5"
            ;;
        "apply")
            apply_features "$2" "$3" "$4" "$5"
            ;;
        "compare")
            compare_roms "$2" "$3" "$4"
            ;;
        *)
            echo "Usage: $0 {analyze|extract|apply|compare} [options]"
            echo ""
            echo "Commands:"
            echo "  analyze <rom_path> <output_dir> [base_rom]              - Analyze ROM for reverse porting"
            echo "  extract <source_rom> <feature_list> <output_dir> <mode> - Extract features from ROM"
            echo "  apply <target_rom> <features_dir> <config> [backup_dir] - Apply features to ROM"
            echo "  compare <custom_rom> <base_rom> <output_dir>            - Compare two ROMs"
            echo ""
            echo "Extraction modes: copy, link, package"
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

