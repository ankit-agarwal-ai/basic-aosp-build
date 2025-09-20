
# Basic AOSP Build

A comprehensive bash script for building the Android Open Source Project (AOSP) from source.


## Features

- **Automated Setup**: Automatically installs the `repo` tool and checks prerequisites
- **Manifest Fetching**: Downloads the latest AOSP manifest from Google's repository
- **Flexible Configuration**: Supports different branches and build targets
- **Error Handling**: Comprehensive error checking and logging
- **Build Optimization**: Uses ccache and parallel compilation for faster builds
- **Clean Builds**: Option to perform clean builds

## Prerequisites

### System Requirements
- **OS**: Linux (Ubuntu 18.04+ recommended)
- **RAM**: 16GB minimum (32GB recommended)
- **Storage**: 100GB+ free space
- **CPU**: Multi-core processor (8+ cores recommended)

### System Installation 

During the build I had to install the following packages

```
sudo apt-get update
sudo apt-get install libncurses5

```

### Required Software
The script will check for and install missing dependencies:
- Git
- Python 3
- Java 11 or 17 (OpenJDK)
- Build tools (make, gcc, g++)
- curl/wget

## Quick Start

1. **Clone this repository**:
   ```bash
   git clone <your-repo-url>
   cd basic-aosp-build
   ```

2. **Run the build script**:
   ```bash
   ./build-aosp.sh
   ```

This will build AOSP with default settings (master branch, aosp_arm64-userdebug target).

## Usage

### Basic Usage
```bash
./build-aosp.sh [OPTIONS]
```

### Options
- `-b, --branch BRANCH`: Specify AOSP branch to build (default: master)
- `-t, --target TARGET`: Specify build target (default: aosp_arm64-userdebug)
- `-c, --clean`: Clean build directory before starting
- `-h, --help`: Show help message

### Examples

**Build with default settings**:
```bash
./build-aosp.sh
```

**Build a specific Android version**:
```bash
./build-aosp.sh -b android-14.0.0_r1
```

**Build for x86_64 architecture**:
```bash
./build-aosp.sh -t aosp_x86_64-userdebug
```

**Clean build with custom settings**:
```bash
./build-aosp.sh -c -b master -t aosp_arm64-user
```

## Build Targets

Common build targets you can use:

| Target | Description |
|--------|-------------|
| `aosp_arm64-userdebug` | ARM64 userdebug build (default) |
| `aosp_x86_64-userdebug` | x86_64 userdebug build |
| `aosp_arm64-user` | ARM64 user build (production) |
| `aosp_x86_64-user` | x86_64 user build (production) |
| `aosp_arm-userdebug` | ARM userdebug build |
| `aosp_x86-userdebug` | x86 userdebug build |

## Build Process

The script performs the following steps:

1. **Prerequisites Check**: Verifies system requirements and installed software
2. **Environment Setup**: Configures build environment and ccache
3. **Manifest Fetching**: Downloads AOSP manifest and initializes repo
4. **Repository Sync**: Downloads all AOSP source code (this takes the longest)
5. **Build Configuration**: Sets up the build environment and selects target
6. **Compilation**: Builds the Android system

## Output

- **Build artifacts**: Located in `aosp/out/target/product/*/`
- **Log file**: `aosp-build.log` contains detailed build logs
- **Console output**: Real-time build progress with colored output

## Troubleshooting

### Common Issues

**Out of disk space**:
- Ensure you have at least 100GB free space
- The script will warn if space is insufficient

**Build fails with memory errors**:
- Ensure you have at least 16GB RAM
- Close other applications to free up memory

**Java version issues**:
- Install OpenJDK 11 or 17
- Update JAVA_HOME if necessary

**Network issues during sync**:
- Check your internet connection
- The script will retry failed downloads

### Getting Help

1. Check the log file `aosp-build.log` for detailed error messages
2. Ensure all prerequisites are met
3. Try a clean build with `-c` option
4. Verify you have sufficient disk space and RAM

## Performance Tips

1. **Use SSD storage** for faster I/O operations
2. **Increase RAM** to 32GB+ for faster builds
3. **Use ccache** (enabled by default) to speed up incremental builds
4. **Close unnecessary applications** during the build process

## License

This project is provided as-is for educational and development purposes. AOSP is licensed under the Apache License 2.0.

## Contributing

Feel free to submit issues and enhancement requests!
