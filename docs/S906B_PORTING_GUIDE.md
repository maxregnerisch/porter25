# S906B (Galaxy S22 Plus) Android 15 OneUI 6 Porting Guide

## Overview

This comprehensive guide covers the enhanced porting process for Samsung Galaxy S22 Plus (S906B) devices, featuring deep super.img and system.img manipulation capabilities, reverse porting, and well-organized custom ROM creation.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Operation Modes](#operation-modes)
4. [Enhanced Features](#enhanced-features)
5. [Step-by-Step Workflow](#step-by-step-workflow)
6. [Troubleshooting](#troubleshooting)
7. [Safety Guidelines](#safety-guidelines)

## Prerequisites

### Hardware Requirements
- **Storage**: Minimum 150GB free space
- **RAM**: 8GB or more recommended
- **CPU**: Multi-core processor for faster processing

### Software Requirements
- Linux-based operating system (Ubuntu 20.04+ recommended)
- Required packages:
  ```bash
  sudo apt update
  sudo apt install git android-sdk-libsparse-utils erofs-utils xmlstarlet lz4 python3 openjdk-11-jdk
  ```

### ROM Files Required
- **Base ROM**: S906B firmware file (latest OneUI 6)
- **Port ROM**: Source ROM to port from (S24, S23, etc.)
- **Update ZIP**: OneUI 6 update file (optional)

## Quick Start

### Basic Porting
```bash
./gen_s906b.sh S906B_Base.zip S24_Port.zip OneUI6_Update.zip v1.0
```

### Enhanced Porting with Deep Processing
```bash
./gen_s906b.sh S906B_Base.zip S24_Port.zip OneUI6_Update.zip v1.0 enhanced
```

### Reverse Porting from Custom ROM
```bash
./gen_s906b.sh CustomROM.zip S906B_Base.zip - v1.0 reverse
```

## Operation Modes

### 1. Basic Mode (Default)
- Standard ROM porting workflow
- Essential S906B optimizations
- 64-bit vendor configuration
- Core functionality patches

**Use Case**: Quick and reliable porting for daily use

### 2. Enhanced Mode
- Advanced super.img manipulation
- Deep system.img processing
- Comprehensive analysis and validation
- Optimized partition layouts

**Use Case**: Advanced users requiring maximum customization

### 3. Reverse Mode
- Extract features from custom ROMs
- Apply modifications to base ROMs
- Feature detection and analysis
- Cross-ROM compatibility

**Use Case**: Porting specific features from custom ROMs

## Enhanced Features

### Super.img Management
- **Analysis**: Detailed partition layout inspection
- **Extraction**: Selective or complete partition extraction
- **Modification**: Dynamic partition resizing and content modification
- **Creation**: Optimized super.img generation with S906B specifications
- **Validation**: Integrity checks and compatibility verification

### System.img Processing
- **Deep Extraction**: Full, selective, or app-only extraction modes
- **Modification**: Overlay application, file removal, and patching
- **Reverse Porting**: Feature extraction from custom ROMs
- **Validation**: Filesystem and structure verification

### Reverse Porting Engine
- **Feature Detection**: Automatic identification of custom features
- **Modification Analysis**: Detection of ROM modifications
- **Extraction**: Selective feature extraction with multiple modes
- **Application**: Intelligent feature application to target ROMs

## Step-by-Step Workflow

### Phase 1: Preparation
1. **Environment Setup**
   ```bash
   git clone https://github.com/maxregnerisch/porter25.git
   cd porter25
   chmod +x gen_s906b.sh
   ```

2. **File Preparation**
   - Download S906B base firmware
   - Obtain source ROM for porting
   - Prepare update files (if applicable)

3. **Space Check**
   ```bash
   df -h .  # Ensure 150GB+ available
   ```

### Phase 2: ROM Analysis (Enhanced Mode)
1. **Super.img Analysis**
   ```bash
   ./bin/super_manager.sh analyze base_super.img analysis/super
   ```

2. **System.img Analysis**
   ```bash
   ./bin/system_processor.sh analyze system.img analysis/system
   ```

3. **Review Analysis Reports**
   - Check `analysis/super/partition_layout.txt`
   - Review `analysis/system/directory_structure.txt`

### Phase 3: Porting Execution
1. **Start Porting Process**
   ```bash
   ./gen_s906b.sh BaseROM.zip PortROM.zip UpdateZip.zip v1.0 enhanced
   ```

2. **Monitor Progress**
   - Watch for error messages
   - Check intermediate outputs
   - Verify partition extractions

3. **Validation**
   - Automatic integrity checks
   - S906B compatibility verification
   - Size and structure validation

### Phase 4: Output and Testing
1. **Locate Output**
   ```
   out/S906B-OneUI6-enhanced-v1.0.zip
   out/S906B-OneUI6-enhanced-v1.0.zip.info
   out/S906B-OneUI6-enhanced-v1.0.zip.sha256
   ```

2. **Pre-Flash Verification**
   - Check file integrity with SHA256
   - Review ROM information file
   - Verify file size (should be 4-8GB)

3. **Test Installation**
   - Flash on test device first
   - Verify boot process
   - Test core functionality

## Advanced Usage

### Custom Feature Extraction
```bash
# Create feature list
echo "custom_camera" > features.txt
echo "audio_enhancements" >> features.txt

# Extract features
./bin/reverse_porter.sh extract source_rom.zip features.txt output_dir copy
```

### Selective System Processing
```bash
# Extract only apps
./bin/system_processor.sh extract system.img output_dir apps_only

# Extract with filter
./bin/system_processor.sh extract system.img output_dir selective "*.apk"
```

### Super.img Optimization
```bash
# Optimize for size
./bin/super_manager.sh optimize input_super.img output_super.img aggressive
```

## Configuration Customization

### Device-Specific Settings
Edit `configs/s906b_config.sh` to modify:
- Device properties
- Partition sizes
- Feature flags
- Build fingerprints

### Patch Customization
Edit `configs/android15_oneui6_patches.txt` to:
- Add custom patches
- Modify system properties
- Configure hardware features

## Troubleshooting

### Common Issues

#### 1. Insufficient Disk Space
**Error**: "Low disk space warning"
**Solution**: 
- Free up space (need 150GB+)
- Use external storage
- Clean temporary files

#### 2. Mount Failures
**Error**: "Failed to mount system.img"
**Solution**:
- Check filesystem type
- Verify image integrity
- Install missing tools (erofs-utils)

#### 3. Super.img Creation Failed
**Error**: "Failed to create super.img"
**Solution**:
- Check partition sizes
- Verify lpmake tool
- Review partition layout

#### 4. S906B Compatibility Warning
**Error**: "ROM may not be S906B compatible"
**Solution**:
- Verify base ROM is for S906B
- Check device model in build.prop
- Use correct firmware version

### Debug Mode
Enable verbose logging:
```bash
export DEBUG=1
./gen_s906b.sh [parameters]
```

### Log Analysis
Check logs in:
- `analysis/` - Analysis reports
- `backup/` - Backup files
- `enhanced/` - Enhanced processing outputs

## Safety Guidelines

### ⚠️ Critical Safety Warnings

1. **Always Backup**: Create full device backup before flashing
2. **Test First**: Use test device before daily driver
3. **Verify Compatibility**: Ensure ROM is for S906B specifically
4. **Check Bootloader**: Verify unlocked bootloader
5. **Power Supply**: Ensure stable power during flashing

### Pre-Flash Checklist
- [ ] Device backup completed
- [ ] Bootloader unlocked
- [ ] Correct firmware version
- [ ] Stable power supply
- [ ] Recovery mode accessible
- [ ] Download mode functional

### Recovery Procedures
If device fails to boot:
1. Enter download mode (Vol Down + Power + USB)
2. Flash original firmware using Odin
3. Perform factory reset
4. Restore from backup

## Performance Optimization

### Build Optimizations
- **64-bit Only**: Removes 32-bit libraries for better performance
- **EROFS Compression**: LZ4HC compression for faster I/O
- **Partition Optimization**: Optimized partition sizes for S906B

### Runtime Optimizations
- **ZRAM Configuration**: Optimized memory compression
- **CPU Governor**: Performance-oriented scheduling
- **I/O Scheduler**: Optimized for flash storage

## Support and Community

### Getting Help
- Check troubleshooting section first
- Review log files for error details
- Search existing issues on GitHub
- Create detailed bug reports

### Contributing
- Report bugs with full logs
- Suggest feature improvements
- Submit tested patches
- Share successful configurations

### Disclaimer
This tool is provided as-is for educational and development purposes. Users assume all risks associated with custom ROM flashing. Always maintain proper backups and flash at your own risk.

---

**Happy Porting! 🚀**

*For additional help, refer to the [Enhanced Features Guide](ENHANCED_FEATURES.md) and [Workflow Examples](WORKFLOW_EXAMPLES.md).*

