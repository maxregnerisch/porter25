#!/bin/bash
# Rollback Procedures for S906B Porting Tool
# Provides comprehensive rollback and recovery mechanisms

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCALPATH="$(dirname "$SCRIPT_DIR")"

# Source configuration
source "$LOCALPATH/configs/s906b_config.sh"
source "$LOCALPATH/safety/validation_rules.txt"

# Rollback Functions

# Function to create rollback point
create_rollback_point() {
    local point_name="$1"
    local description="$2"
    
    echo "💾 Creating rollback point: $point_name"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local rollback_dir="backup/rollback_points/${point_name}_${timestamp}"
    
    mkdir -p "$rollback_dir"
    
    # Create rollback metadata
    cat > "$rollback_dir/rollback_info.txt" << EOF
Rollback Point Information
==========================
Name: $point_name
Description: $description
Created: $(date)
Timestamp: $timestamp
Working Directory: $(pwd)
User: $(whoami)
Host: $(hostname)

Files Backed Up:
EOF
    
    # Backup current state based on rollback point type
    case "$point_name" in
        "pre_extraction")
            backup_pre_extraction "$rollback_dir"
            ;;
        "pre_modification")
            backup_pre_modification "$rollback_dir"
            ;;
        "pre_creation")
            backup_pre_creation "$rollback_dir"
            ;;
        "pre_packaging")
            backup_pre_packaging "$rollback_dir"
            ;;
        "custom")
            backup_custom_state "$rollback_dir" "$description"
            ;;
        *)
            backup_full_state "$rollback_dir"
            ;;
    esac
    
    # Create rollback script
    create_rollback_script "$rollback_dir" "$point_name"
    
    # Update rollback registry
    update_rollback_registry "$point_name" "$timestamp" "$rollback_dir"
    
    echo "✅ Rollback point created: $rollback_dir"
    echo "📋 Rollback info: $rollback_dir/rollback_info.txt"
    echo "🔄 Rollback script: $rollback_dir/rollback.sh"
    
    return 0
}

# Function to backup pre-extraction state
backup_pre_extraction() {
    local rollback_dir="$1"
    
    echo "📁 Backing up pre-extraction state..."
    
    # Backup original ROM files
    if [ -f "$BASEROMZIP" ]; then
        echo "  Backing up base ROM..."
        cp "$BASEROMZIP" "$rollback_dir/base_rom_original.zip"
        echo "base_rom_original.zip" >> "$rollback_dir/rollback_info.txt"
    fi
    
    if [ -f "$PORTROMZIP" ]; then
        echo "  Backing up port ROM..."
        cp "$PORTROMZIP" "$rollback_dir/port_rom_original.zip"
        echo "port_rom_original.zip" >> "$rollback_dir/rollback_info.txt"
    fi
    
    if [ -f "$UPDATEZIP" ] && [ "$UPDATEZIP" != "-" ]; then
        echo "  Backing up update ZIP..."
        cp "$UPDATEZIP" "$rollback_dir/update_original.zip"
        echo "update_original.zip" >> "$rollback_dir/rollback_info.txt"
    fi
    
    # Backup configuration files
    echo "  Backing up configurations..."
    cp -r configs/ "$rollback_dir/configs_backup/"
    echo "configs_backup/" >> "$rollback_dir/rollback_info.txt"
    
    # Backup any existing work directories
    for dir in stock port ui7update; do
        if [ -d "$dir" ]; then
            echo "  Backing up existing $dir directory..."
            cp -r "$dir" "$rollback_dir/${dir}_backup/"
            echo "${dir}_backup/" >> "$rollback_dir/rollback_info.txt"
        fi
    done
}

# Function to backup pre-modification state
backup_pre_modification() {
    local rollback_dir="$1"
    
    echo "📁 Backing up pre-modification state..."
    
    # Backup extracted directories
    for dir in stock port ui7update; do
        if [ -d "$dir" ]; then
            echo "  Backing up $dir directory..."
            cp -r "$dir" "$rollback_dir/${dir}_backup/"
            echo "${dir}_backup/" >> "$rollback_dir/rollback_info.txt"
        fi
    done
    
    # Backup enhanced processing directories
    if [ -d "enhanced" ]; then
        echo "  Backing up enhanced processing state..."
        cp -r enhanced/ "$rollback_dir/enhanced_backup/"
        echo "enhanced_backup/" >> "$rollback_dir/rollback_info.txt"
    fi
    
    # Backup analysis results
    if [ -d "analysis" ]; then
        echo "  Backing up analysis results..."
        cp -r analysis/ "$rollback_dir/analysis_backup/"
        echo "analysis_backup/" >> "$rollback_dir/rollback_info.txt"
    fi
}

# Function to backup pre-creation state
backup_pre_creation() {
    local rollback_dir="$1"
    
    echo "📁 Backing up pre-creation state..."
    
    # Backup modified directories
    for dir in stock port ui7update enhanced; do
        if [ -d "$dir" ]; then
            echo "  Backing up modified $dir directory..."
            cp -r "$dir" "$rollback_dir/${dir}_modified_backup/"
            echo "${dir}_modified_backup/" >> "$rollback_dir/rollback_info.txt"
        fi
    done
    
    # Backup any intermediate images
    for img in *.img; do
        if [ -f "$img" ]; then
            echo "  Backing up intermediate image: $img"
            cp "$img" "$rollback_dir/"
            echo "$img" >> "$rollback_dir/rollback_info.txt"
        fi
    done
}

# Function to backup pre-packaging state
backup_pre_packaging() {
    local rollback_dir="$1"
    
    echo "📁 Backing up pre-packaging state..."
    
    # Backup updatezip directory
    if [ -d "updatezip" ]; then
        echo "  Backing up updatezip directory..."
        cp -r updatezip/ "$rollback_dir/updatezip_backup/"
        echo "updatezip_backup/" >> "$rollback_dir/rollback_info.txt"
    fi
    
    # Backup any created images
    for img in updatezip/*.img; do
        if [ -f "$img" ]; then
            local img_name=$(basename "$img")
            echo "  Backing up created image: $img_name"
            cp "$img" "$rollback_dir/"
            echo "$img_name" >> "$rollback_dir/rollback_info.txt"
        fi
    done
}

# Function to backup custom state
backup_custom_state() {
    local rollback_dir="$1"
    local description="$2"
    
    echo "📁 Backing up custom state: $description"
    
    # Backup all working directories
    for dir in stock port ui7update enhanced analysis updatezip out; do
        if [ -d "$dir" ]; then
            echo "  Backing up $dir directory..."
            cp -r "$dir" "$rollback_dir/${dir}_backup/"
            echo "${dir}_backup/" >> "$rollback_dir/rollback_info.txt"
        fi
    done
    
    # Backup any loose image files
    for img in *.img; do
        if [ -f "$img" ]; then
            echo "  Backing up image: $img"
            cp "$img" "$rollback_dir/"
            echo "$img" >> "$rollback_dir/rollback_info.txt"
        fi
    done
}

# Function to backup full state
backup_full_state() {
    local rollback_dir="$1"
    
    echo "📁 Backing up full state..."
    
    # Backup everything except output and temporary files
    local exclude_patterns=(
        "--exclude=out/*"
        "--exclude=*.tmp"
        "--exclude=*.temp"
        "--exclude=backup/rollback_points/*"
        "--exclude=logs/*"
    )
    
    echo "  Creating full backup archive..."
    tar czf "$rollback_dir/full_state_backup.tar.gz" "${exclude_patterns[@]}" .
    echo "full_state_backup.tar.gz" >> "$rollback_dir/rollback_info.txt"
}

# Function to create rollback script
create_rollback_script() {
    local rollback_dir="$1"
    local point_name="$2"
    
    cat > "$rollback_dir/rollback.sh" << EOF
#!/bin/bash
# Automatic Rollback Script
# Generated for rollback point: $point_name
# Created: $(date)

ROLLBACK_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
ORIGINAL_DIR="$LOCALPATH"

echo "🔄 Starting rollback to point: $point_name"
echo "📁 Rollback directory: \$ROLLBACK_DIR"
echo "📁 Target directory: \$ORIGINAL_DIR"

cd "\$ORIGINAL_DIR"

# Confirm rollback
read -p "Are you sure you want to rollback to '$point_name'? (y/N): " -n 1 -r
echo
if [[ ! \$REPLY =~ ^[Yy]\$ ]]; then
    echo "❌ Rollback cancelled"
    exit 1
fi

echo "⚠️ Starting rollback process..."

# Create emergency backup of current state
echo "💾 Creating emergency backup of current state..."
mkdir -p backup/emergency_backups
tar czf "backup/emergency_backups/emergency_backup_\$(date +%Y%m%d_%H%M%S).tar.gz" \\
    --exclude=backup/rollback_points/* \\
    --exclude=backup/emergency_backups/* \\
    --exclude=out/* \\
    --exclude=logs/* .

EOF

    # Add specific rollback commands based on point type
    case "$point_name" in
        "pre_extraction")
            cat >> "$rollback_dir/rollback.sh" << 'EOF'
# Rollback to pre-extraction state
echo "🔄 Rolling back to pre-extraction state..."

# Remove extracted directories
for dir in stock port ui7update enhanced analysis; do
    if [ -d "$dir" ]; then
        echo "  Removing $dir..."
        rm -rf "$dir"
    fi
done

# Restore backed up directories if they existed
for backup in "${ROLLBACK_DIR}"/*_backup/; do
    if [ -d "$backup" ]; then
        dir_name=$(basename "$backup" _backup)
        echo "  Restoring $dir_name..."
        cp -r "$backup" "$dir_name"
    fi
done
EOF
            ;;
        "pre_modification")
            cat >> "$rollback_dir/rollback.sh" << 'EOF'
# Rollback to pre-modification state
echo "🔄 Rolling back to pre-modification state..."

# Restore directories from backup
for backup in "${ROLLBACK_DIR}"/*_backup/; do
    if [ -d "$backup" ]; then
        dir_name=$(basename "$backup" _backup)
        echo "  Restoring $dir_name..."
        rm -rf "$dir_name"
        cp -r "$backup" "$dir_name"
    fi
done
EOF
            ;;
        "pre_creation")
            cat >> "$rollback_dir/rollback.sh" << 'EOF'
# Rollback to pre-creation state
echo "🔄 Rolling back to pre-creation state..."

# Remove created images
for img in *.img; do
    if [ -f "$img" ]; then
        echo "  Removing created image: $img"
        rm -f "$img"
    fi
done

# Restore directories from backup
for backup in "${ROLLBACK_DIR}"/*_modified_backup/; do
    if [ -d "$backup" ]; then
        dir_name=$(basename "$backup" _modified_backup)
        echo "  Restoring $dir_name..."
        rm -rf "$dir_name"
        cp -r "$backup" "$dir_name"
    fi
done
EOF
            ;;
        "pre_packaging")
            cat >> "$rollback_dir/rollback.sh" << 'EOF'
# Rollback to pre-packaging state
echo "🔄 Rolling back to pre-packaging state..."

# Remove output directory
if [ -d "out" ]; then
    echo "  Removing output directory..."
    rm -rf out/*
fi

# Restore updatezip directory
if [ -d "${ROLLBACK_DIR}/updatezip_backup" ]; then
    echo "  Restoring updatezip directory..."
    rm -rf updatezip
    cp -r "${ROLLBACK_DIR}/updatezip_backup" updatezip
fi

# Restore created images
for img in "${ROLLBACK_DIR}"/*.img; do
    if [ -f "$img" ]; then
        img_name=$(basename "$img")
        echo "  Restoring image: $img_name"
        cp "$img" "updatezip/"
    fi
done
EOF
            ;;
        *)
            cat >> "$rollback_dir/rollback.sh" << 'EOF'
# Full state rollback
echo "🔄 Rolling back to full state..."

# Extract full backup
if [ -f "${ROLLBACK_DIR}/full_state_backup.tar.gz" ]; then
    echo "  Extracting full state backup..."
    tar xzf "${ROLLBACK_DIR}/full_state_backup.tar.gz"
else
    echo "❌ Full state backup not found"
    exit 1
fi
EOF
            ;;
    esac
    
    cat >> "$rollback_dir/rollback.sh" << 'EOF'

echo "✅ Rollback completed successfully"
echo "📋 Check the current state and verify everything is working correctly"
echo "⚠️ Emergency backup created in backup/emergency_backups/"
EOF
    
    chmod +x "$rollback_dir/rollback.sh"
}

# Function to update rollback registry
update_rollback_registry() {
    local point_name="$1"
    local timestamp="$2"
    local rollback_dir="$3"
    
    local registry_file="backup/rollback_registry.txt"
    
    # Create registry if it doesn't exist
    if [ ! -f "$registry_file" ]; then
        cat > "$registry_file" << EOF
# Rollback Point Registry
# Format: TIMESTAMP|POINT_NAME|ROLLBACK_DIR|STATUS
EOF
    fi
    
    # Add entry to registry
    echo "${timestamp}|${point_name}|${rollback_dir}|ACTIVE" >> "$registry_file"
    
    # Clean up old rollback points if needed
    cleanup_old_rollback_points
}

# Function to list available rollback points
list_rollback_points() {
    local registry_file="backup/rollback_registry.txt"
    
    echo "📋 Available Rollback Points:"
    echo "=============================="
    
    if [ ! -f "$registry_file" ]; then
        echo "No rollback points found."
        return 1
    fi
    
    echo "Timestamp        | Point Name      | Status | Size"
    echo "-----------------|-----------------|--------|--------"
    
    while IFS='|' read -r timestamp point_name rollback_dir status; do
        if [[ "$timestamp" =~ ^[0-9] ]]; then  # Skip comment lines
            local size="N/A"
            if [ -d "$rollback_dir" ]; then
                size=$(du -sh "$rollback_dir" 2>/dev/null | cut -f1)
            else
                status="MISSING"
            fi
            printf "%-16s | %-15s | %-6s | %s\n" "$timestamp" "$point_name" "$status" "$size"
        fi
    done < "$registry_file"
}

# Function to rollback to specific point
rollback_to_point() {
    local target_timestamp="$1"
    
    echo "🔄 Rolling back to point: $target_timestamp"
    
    local registry_file="backup/rollback_registry.txt"
    
    if [ ! -f "$registry_file" ]; then
        echo "❌ No rollback registry found"
        return 1
    fi
    
    # Find the rollback point
    local rollback_dir=""
    local point_name=""
    
    while IFS='|' read -r timestamp point_name_reg rollback_dir_reg status; do
        if [ "$timestamp" == "$target_timestamp" ]; then
            rollback_dir="$rollback_dir_reg"
            point_name="$point_name_reg"
            break
        fi
    done < "$registry_file"
    
    if [ -z "$rollback_dir" ]; then
        echo "❌ Rollback point not found: $target_timestamp"
        return 1
    fi
    
    if [ ! -d "$rollback_dir" ]; then
        echo "❌ Rollback directory not found: $rollback_dir"
        return 1
    fi
    
    # Execute rollback script
    local rollback_script="$rollback_dir/rollback.sh"
    
    if [ -f "$rollback_script" ]; then
        echo "🔄 Executing rollback script..."
        bash "$rollback_script"
    else
        echo "❌ Rollback script not found: $rollback_script"
        return 1
    fi
}

# Function to cleanup old rollback points
cleanup_old_rollback_points() {
    echo "🧹 Cleaning up old rollback points..."
    
    local registry_file="backup/rollback_registry.txt"
    local retention_days=${BACKUP_RETENTION_DAYS:-7}
    local max_backup_size_gb=${MAX_BACKUP_SIZE_GB:-50}
    
    if [ ! -f "$registry_file" ]; then
        return 0
    fi
    
    # Calculate cutoff date
    local cutoff_date=$(date -d "$retention_days days ago" +%Y%m%d)
    
    # Create temporary registry
    local temp_registry=$(mktemp)
    
    # Copy header
    head -n 2 "$registry_file" > "$temp_registry"
    
    # Process entries
    while IFS='|' read -r timestamp point_name rollback_dir status; do
        if [[ "$timestamp" =~ ^[0-9] ]]; then
            local entry_date=$(echo "$timestamp" | cut -d'_' -f1)
            
            if [ "$entry_date" -ge "$cutoff_date" ]; then
                # Keep this entry
                echo "${timestamp}|${point_name}|${rollback_dir}|${status}" >> "$temp_registry"
            else
                # Remove old rollback point
                echo "  Removing old rollback point: $timestamp ($point_name)"
                if [ -d "$rollback_dir" ]; then
                    rm -rf "$rollback_dir"
                fi
            fi
        fi
    done < <(tail -n +3 "$registry_file")
    
    # Replace registry
    mv "$temp_registry" "$registry_file"
    
    # Check total backup size
    local total_size=$(du -s backup/ 2>/dev/null | cut -f1)
    local total_size_gb=$((total_size / 1024 / 1024))
    
    if [ $total_size_gb -gt $max_backup_size_gb ]; then
        echo "⚠️ Backup size ($total_size_gb GB) exceeds limit ($max_backup_size_gb GB)"
        echo "Consider manually cleaning up backup directory"
    fi
    
    echo "✅ Cleanup completed"
}

# Function to create emergency recovery
create_emergency_recovery() {
    local description="$1"
    
    echo "🚨 Creating emergency recovery point..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local recovery_dir="backup/emergency_recovery/emergency_${timestamp}"
    
    mkdir -p "$recovery_dir"
    
    # Create minimal recovery package
    echo "📦 Creating minimal recovery package..."
    
    # Backup essential files
    cp -r configs/ "$recovery_dir/" 2>/dev/null || true
    cp -r bin/ "$recovery_dir/" 2>/dev/null || true
    cp gen_s906b.sh "$recovery_dir/" 2>/dev/null || true
    
    # Create recovery info
    cat > "$recovery_dir/recovery_info.txt" << EOF
Emergency Recovery Point
========================
Created: $(date)
Description: $description
Working Directory: $(pwd)
User: $(whoami)
Host: $(hostname)

Recovery Instructions:
1. Copy files from this directory to your working directory
2. Ensure all tools are available in bin/
3. Run ./gen_s906b.sh with appropriate parameters
4. Check logs for any issues

Files Included:
$(find "$recovery_dir" -type f | sed 's|^|  |')
EOF
    
    # Create recovery script
    cat > "$recovery_dir/recover.sh" << 'EOF'
#!/bin/bash
# Emergency Recovery Script

RECOVERY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$1"

if [ -z "$TARGET_DIR" ]; then
    echo "Usage: $0 <target_directory>"
    echo "Example: $0 /path/to/porter25"
    exit 1
fi

echo "🚨 Starting emergency recovery..."
echo "📁 Recovery source: $RECOVERY_DIR"
echo "📁 Recovery target: $TARGET_DIR"

# Confirm recovery
read -p "Are you sure you want to recover to '$TARGET_DIR'? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Recovery cancelled"
    exit 1
fi

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# Copy essential files
echo "📋 Copying essential files..."
cp -r "$RECOVERY_DIR/configs" . 2>/dev/null || true
cp -r "$RECOVERY_DIR/bin" . 2>/dev/null || true
cp "$RECOVERY_DIR/gen_s906b.sh" . 2>/dev/null || true

# Set permissions
chmod +x gen_s906b.sh 2>/dev/null || true
chmod +x bin/*.sh 2>/dev/null || true

echo "✅ Emergency recovery completed"
echo "📋 Check recovery_info.txt for details"
echo "🔧 You can now run ./gen_s906b.sh to continue"
EOF
    
    chmod +x "$recovery_dir/recover.sh"
    
    echo "✅ Emergency recovery point created: $recovery_dir"
    echo "📋 Recovery info: $recovery_dir/recovery_info.txt"
    echo "🔄 Recovery script: $recovery_dir/recover.sh"
}

# Function to validate rollback integrity
validate_rollback_integrity() {
    local rollback_dir="$1"
    
    echo "🔍 Validating rollback integrity..."
    
    if [ ! -d "$rollback_dir" ]; then
        echo "❌ Rollback directory not found: $rollback_dir"
        return 1
    fi
    
    # Check for required files
    local required_files=("rollback_info.txt" "rollback.sh")
    
    for file in "${required_files[@]}"; do
        if [ ! -f "$rollback_dir/$file" ]; then
            echo "❌ Missing required file: $file"
            return 1
        fi
    done
    
    # Check rollback script permissions
    if [ ! -x "$rollback_dir/rollback.sh" ]; then
        echo "⚠️ Rollback script not executable, fixing..."
        chmod +x "$rollback_dir/rollback.sh"
    fi
    
    # Validate backed up files
    echo "📋 Validating backed up files..."
    local validation_passed=true
    
    while IFS= read -r file; do
        if [[ "$file" =~ ^[[:space:]]*$ ]] || [[ "$file" =~ ^#.*$ ]]; then
            continue
        fi
        
        if [ ! -e "$rollback_dir/$file" ]; then
            echo "❌ Missing backed up file: $file"
            validation_passed=false
        fi
    done < "$rollback_dir/rollback_info.txt"
    
    if [ "$validation_passed" = true ]; then
        echo "✅ Rollback integrity validation passed"
        return 0
    else
        echo "❌ Rollback integrity validation failed"
        return 1
    fi
}

# Main function
main() {
    case "$1" in
        "create")
            create_rollback_point "$2" "$3"
            ;;
        "list")
            list_rollback_points
            ;;
        "rollback")
            rollback_to_point "$2"
            ;;
        "cleanup")
            cleanup_old_rollback_points
            ;;
        "emergency")
            create_emergency_recovery "$2"
            ;;
        "validate")
            validate_rollback_integrity "$2"
            ;;
        *)
            echo "Usage: $0 {create|list|rollback|cleanup|emergency|validate} [options]"
            echo ""
            echo "Commands:"
            echo "  create <point_name> <description>    - Create rollback point"
            echo "  list                                 - List available rollback points"
            echo "  rollback <timestamp>                 - Rollback to specific point"
            echo "  cleanup                              - Clean up old rollback points"
            echo "  emergency <description>              - Create emergency recovery point"
            echo "  validate <rollback_dir>              - Validate rollback integrity"
            echo ""
            echo "Examples:"
            echo "  $0 create pre_extraction \"Before ROM extraction\""
            echo "  $0 list"
            echo "  $0 rollback 20241201_143022"
            echo "  $0 emergency \"System corruption detected\""
            exit 1
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

