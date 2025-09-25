#!/bin/bash

# AOSP Build Script
# This script fetches the AOSP manifest and builds Android Open Source Project

set -e  # Exit on any error

# Configuration
AOSP_MANIFEST_URL="https://android.googlesource.com/platform/manifest"
DEFAULT_BRANCH="android-14.0.0_r22"
DEFAULT_TARGET="aosp_arm64-userdebug"  # Will be validated and corrected if needed
BUILD_DIR="aosp"
LOG_FILE="aosp-build.log"
DEFAULT_SYNC_JOBS=4  # Conservative default to avoid 429 errors

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if running on Linux
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        error "This script is designed for Linux systems only"
    fi
    
    # Check for required commands
    # local required_commands=("git" "curl" "wget" "python3" "java" "make" "gcc" "g++")
    # for cmd in "${required_commands[@]}"; do
    #     if ! command -v "$cmd" &> /dev/null; then
    #         error "Required command '$cmd' is not installed"
    #     fi
    # done
    
    # Check for repo command
    if ! command -v "repo" &> /dev/null; then
        log "Installing repo tool..."
        mkdir -p ~/.bin
        curl https://storage.googleapis.com/git-repo-downloads/repo > ~/.bin/repo
        chmod a+rx ~/.bin/repo
        export PATH="$HOME/.bin:$PATH"
        
        # Add to bashrc if not already there
        if ! grep -q "export PATH=\"\$HOME/.bin:\$PATH\"" ~/.bashrc; then
            echo 'export PATH="$HOME/.bin:$PATH"' >> ~/.bashrc
        fi
    fi
    
    # Check available disk space (need at least 100GB)
    local available_space=$(df . | tail -1 | awk '{print $4}')
    local required_space=104857600  # 100GB in KB
    if [ "$available_space" -lt "$required_space" ]; then
        warning "Available disk space is less than 100GB. AOSP build may fail."
    fi
    
    # Check RAM (need at least 16GB)
    local total_ram=$(free -m | awk 'NR==2{print $2}')
    if [ "$total_ram" -lt 16384 ]; then
        warning "Total RAM is less than 16GB. Build may be slow or fail."
    fi
    
    success "Prerequisites check completed"
}

# Function to create build directory
create_build_dir() {
    local build_dir="$1"
    
    log "Creating build directory: $build_dir"
    
    if [ -d "$build_dir" ]; then
        log "Build directory '$build_dir' already exists"
        return 0
    fi
    
    mkdir -p "$build_dir"
    if [ $? -eq 0 ]; then
        log "Successfully created build directory '$build_dir'"
    else
        error "Failed to create build directory '$build_dir'. Check permissions and path."
    fi
}

# Function to get absolute log file path
get_log_file_path() {
    local build_dir="$1"
    echo "$build_dir/../$LOG_FILE"
}

# Function to setup build environment
setup_environment() {
    log "Setting up build environment..."
    
    # Set up Java environment (AOSP requires OpenJDK 11 or 17)
    if command -v "java" &> /dev/null; then
        local java_version=$(java -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
        if [ "$java_version" -lt 11 ]; then
            warning "Java version $java_version detected. AOSP requires Java 11 or higher."
        fi
    fi
    
    # Set up environment variables
    export USE_CCACHE=1
    export CCACHE_DIR=~/.ccache
    export CCACHE_MAXSIZE=50G
    
    # Create ccache directory if it doesn't exist
    mkdir -p "$CCACHE_DIR"
    
    success "Build environment setup completed"
}

# Function to fetch and initialize repo
fetch_manifest() {
    local branch=${1:-$DEFAULT_BRANCH}
    local target=${2:-$DEFAULT_TARGET}
    local sync_jobs=${3:-$DEFAULT_SYNC_JOBS}
    local build_dir=${4:-$BUILD_DIR}
    local script_dir=${5:-$BUILD_DIR}
    log "Fetching AOSP manifest for branch: $branch"
    
    # Change to build directory (already created by create_build_dir)
    log "Using build directory '$build_dir'"
    cd "$build_dir"
    
    # Check if this is already a repo-managed directory
    if [ -d ".repo" ]; then
        log "Existing repo directory found, will sync to update"
    else
        log "New build directory, will initialize repo"
    fi
    
    # Initialize repo (only if not already initialized or if branch changed)
    if [ ! -d ".repo" ]; then
        log "Initializing repo..."
        repo init -u "$AOSP_MANIFEST_URL" -b "$branch"
    else
        log "Repo already initialized, checking if branch needs to be updated..."
        # Check current branch and update if different
        local current_branch=$(repo manifest -r | grep -o 'revision="[^"]*"' | head -1 | cut -d'"' -f2)
        if [ "$current_branch" != "$branch" ]; then
            log "Switching from branch '$current_branch' to '$branch'"
            repo init -u "$AOSP_MANIFEST_URL" -b "$branch"
        else
            log "Already on correct branch '$branch'"
        fi
    fi
    
    # Copy RBE script from repo root to build directory (always copy for availability)
    if [ -f "$script_dir/rbe.sh" ]; then
        log "Copying RBE script from repo root to build directory..."
        cp "$script_dir/rbe.sh" "rbe.sh"
    else
        log "RBE script not found in repo root ($script_dir/rbe.sh)"
        exit 1
    fi
    
    # Sync the repository with rate limiting
    log "Syncing repository (this may take a long time)..."
    local max_jobs=$(nproc)
    
    # Use fewer jobs if we have many cores to avoid overwhelming the servers
    if [ "$sync_jobs" -gt "$max_jobs" ]; then
        sync_jobs="$max_jobs"
    fi
    
    # Additional rate limiting for high-core systems
    if [ "$max_jobs" -gt 8 ] && [ "$sync_jobs" -gt 4 ]; then
        sync_jobs=4
    fi
    
    log "Using $sync_jobs parallel jobs for repo sync to avoid rate limiting"
    log "If you get 429 errors, try reducing sync jobs with -j option"
    
    # Add retry logic for 429 errors
    local retry_count=0
    local max_retries=3
    
    while [ $retry_count -lt $max_retries ]; do
        if repo sync -j"$sync_jobs" --no-tags --no-clone-bundle --fail-fast; then
            break
        else
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                warning "Repo sync failed (attempt $retry_count/$max_retries). Retrying in 30 seconds..."
                sleep 30
                # Reduce jobs on retry to be more conservative
                sync_jobs=$((sync_jobs / 2))
                if [ "$sync_jobs" -lt 1 ]; then
                    sync_jobs=1
                fi
                log "Reducing sync jobs to $sync_jobs for retry"
            else
                error "Repo sync failed after $max_retries attempts. Try running with fewer jobs using -j option."
            fi
        fi
    done
    
    success "Manifest fetched and repository synced"
}

# Function to setup build configuration
setup_build() {
    local target=${1:-$DEFAULT_TARGET}
    local use_rbe=${2:-false}
    local build_dir=${3:-$BUILD_DIR}
    
    log "Setting up build configuration for target: $target"
    
    # Change to build directory
    cd "$build_dir"
    
    # Source the appropriate build environment
    if [ "$use_rbe" = true ]; then
        if [ -f "rbe.sh" ]; then
            log "Using RBE (Remote Build Execution) environment"
            source rbe.sh
        else
            error "RBE script not found. Please ensure rbe.sh exists in the project directory."
        fi
    else
        log "Using standard build environment"
        source build/envsetup.sh
    fi
    
    # Choose the build target
    log "Attempting to set lunch target: $target"
    
    # Try to set the lunch target, with fallback handling
    if ! lunch "$target" 2>/dev/null; then
        warning "Target '$target' not found. Showing available targets..."
        log "Available lunch targets:"
        lunch 2>&1 | head -20 | tee -a "../$LOG_FILE"
        
        # Try some common fallback targets
        local fallback_targets=("aosp_arm64-userdebug" "aosp_arm64-user" "aosp_x86_64-userdebug" "aosp_x86_64-user")
        local found_target=""
        
        for fallback in "${fallback_targets[@]}"; do
            if lunch "$fallback" 2>/dev/null; then
                found_target="$fallback"
                log "Successfully set fallback target: $fallback"
                break
            fi
        done
        
        if [ -z "$found_target" ]; then
            error "Could not find a valid lunch target. Please check available targets and try again."
        fi
    else
        log "Successfully set lunch target: $target"
    fi
    
    success "Build configuration completed"
}

# Function to start the build
start_build() {
    local build_dir=${1:-$BUILD_DIR}
    
    log "Starting AOSP build..."
    
    # Change to build directory
    cd "$build_dir"
    
    # Start the build with parallel jobs
    local jobs=$(nproc)
    log "Building with $jobs parallel jobs"
    
    make -j"$jobs" 2>&1 | tee -a "$(get_log_file_path "$build_dir")"
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        success "AOSP build completed successfully!"
        log "Build artifacts are available in: $(pwd)/out/target/product/*/"
        return 0
    else
        echo -e "${RED}[ERROR]${NC} AOSP build failed. Check the log file for details." | tee -a "$(get_log_file_path "$build_dir")"
        return 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -b, --branch BRANCH     AOSP branch to build (default: $DEFAULT_BRANCH)"
    echo "  -t, --target TARGET     Build target (default: $DEFAULT_TARGET)"
    echo "  -j, --jobs JOBS         Number of parallel jobs for repo sync (default: $DEFAULT_SYNC_JOBS)"
    echo "  -r, --rbe               Use RBE (Remote Build Execution) for distributed builds"
    echo "  -d, --build-dir DIR      Set custom build directory (default: $BUILD_DIR, auto-created if needed)"
    echo "  -c, --clean             Clean build directory before starting (removes existing build)"
    echo "  -l, --list-targets      List available lunch targets and exit"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Build with default settings"
    echo "  $0 -b android-14.0.0_r1              # Build specific branch"
    echo "  $0 -t aosp_x86_64-userdebug          # Build for x86_64"
    echo "  $0 -j 2                              # Use only 2 parallel jobs (if getting 429 errors)"
    echo "  $0 -r                                 # Use RBE for distributed builds"
    echo "  $0 -d /path/to/custom/build           # Use custom build directory"
    echo "  $0 -l                                 # List available lunch targets"
    echo "  $0 -c -b master -t aosp_arm64-user   # Clean build (removes existing directory)"
    echo "  BUILDKITE_AOSP_CLEAN=1 $0            # Clean build via environment variable"
    echo ""
    echo "Rate Limiting Tips:"
    echo "  - If you get 429 (Too Many Requests) errors, reduce jobs with -j 1 or -j 2"
    echo "  - Default is $DEFAULT_SYNC_JOBS jobs to avoid overwhelming AOSP servers"
    echo "  - Script will automatically retry with fewer jobs if sync fails"
    echo ""
    echo "Incremental Builds:"
    echo "  - By default, existing build directories are preserved and reused"
    echo "  - Build directories are automatically created if they don't exist"
    echo "  - Only use -c/--clean when you need a completely fresh build"
    echo "  - Repo sync will update existing repositories incrementally"
    echo "  - This significantly speeds up subsequent builds"
    echo ""
    echo "RBE (Remote Build Execution) Support:"
    echo "  - Use -r or --rbe flag to enable RBE for distributed builds"
    echo "  - RBE enables distributed builds for faster compilation"
    echo "  - Make sure to configure your RBE cluster settings in rbe.sh"
    echo "  - rbe.sh must exist in the project directory when using RBE"
    echo ""
    echo "Buildkite Integration:"
    echo "  - Set BUILDKITE=true environment variable to enable artifact upload"
    echo "  - Set BUILDKITE_AOSP_CLEAN=1 to automatically enable clean builds"
    echo "  - Automatically uploads RBE logs, build artifacts, and build logs"
    echo "  - Artifacts are uploaded regardless of build success or failure"
    echo "  - Requires buildkite-agent to be installed and configured"
    echo ""
    echo "Common build targets (format may vary by AOSP version):"
    echo "  aosp_arm64-userdebug    # ARM64 userdebug build"
    echo "  aosp_x86_64-userdebug   # x86_64 userdebug build"
    echo "  aosp_arm64-user         # ARM64 user build"
    echo "  aosp_x86_64-user        # x86_64 user build"
    echo "  Note: Use -l to list actual available targets for your AOSP version"
}

# Main function
main() {
    local branch="$DEFAULT_BRANCH"
    local target="$DEFAULT_TARGET"
    local sync_jobs="$DEFAULT_SYNC_JOBS"
    local build_dir="$BUILD_DIR"
    local use_rbe=false
    local clean_build=false
    local script_dir=$(dirname "$(realpath "$0")")
    
    # Check for BUILDKITE_AOSP_CLEAN environment variable
    if [ "$BUILDKITE_AOSP_CLEAN" = "1" ]; then
        log "BUILDKITE_AOSP_CLEAN=1 detected, enabling clean build"
        clean_build=true
    fi
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -b|--branch)
                branch="$2"
                shift 2
                ;;
            -t|--target)
                target="$2"
                shift 2
                ;;
            -j|--jobs)
                sync_jobs="$2"
                shift 2
                ;;
            -r|--rbe)
                use_rbe=true
                shift
                ;;
            -d|--build-dir)
                build_dir="$2"
                shift 2
                ;;
            -c|--clean)
                clean_build=true
                shift
                ;;
            -l|--list-targets)
                list_targets "$build_dir"
                exit 0
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use -h for help."
                ;;
        esac
    done
    
    log "Starting AOSP build process..."
    log "Branch: $branch"
    log "Target: $target"
    log "Build directory: $build_dir"
    log "Sync jobs: $sync_jobs"
    log "Use RBE: $use_rbe"
    log "Clean build: $clean_build"
    
    # Clean build directory if requested
    if [ "$clean_build" = true ] && [ -d "$build_dir" ]; then
        log "Cleaning build directory..."
        sudo rm -rf "$build_dir"
        sudo mkdir -m 777 -p "$build_dir"
    fi
    
    # Run the build process
    check_prerequisites
    create_build_dir "$build_dir"
    setup_environment "$script_dir"
    fetch_manifest "$branch" "$target" "$sync_jobs" "$build_dir" "$script_dir"
    setup_build "$target" "$use_rbe" "$build_dir"
    
    # Start build and capture exit status
    local build_success=false
    if start_build "$build_dir"; then
        success "AOSP build process completed successfully!"
        build_success=true
    else
        echo -e "${RED}[ERROR]${NC} AOSP build process failed!" | tee -a "$(get_log_file_path "$build_dir")"
        build_success=false
    fi
    
    # Upload artifacts to Buildkite regardless of build success/failure
    upload_buildkite_artifacts "$build_dir"
    
    # Exit with appropriate code
    if [ "$build_success" = true ]; then
        exit 0
    else
        exit 1
    fi
}

# Function to upload artifacts to Buildkite
upload_buildkite_artifacts() {
    local build_dir="$1"
    
    if [ "$BUILDKITE" = "true" ]; then
        log "BUILDKITE environment detected, preparing artifacts for upload..."
        
        cd "$build_dir"
        
        # Create RBE logs archive if they exist
        if [ -d "out/soong/.temp/rbe" ]; then
            log "Creating RBE logs archive..."
            tar -czf rbe_logs.tar.gz out/soong/.temp/rbe/* 2>/dev/null || {
                warning "Failed to create RBE logs archive"
            }
            
            if [ -f "rbe_logs.tar.gz" ]; then
                log "Uploading RBE logs to Buildkite..."
                buildkite-agent artifact upload rbe_logs.tar.gz || {
                    warning "Failed to upload RBE logs to Buildkite"
                }
            fi
        else
            log "No RBE logs found at out/soong/.temp/rbe/"
        fi
                
        # Upload build log
        local log_file_path=$(get_log_file_path "$build_dir")
        if [ -f "$log_file_path" ]; then
            log "Uploading build log to Buildkite..."
            buildkite-agent artifact upload "$log_file_path" || {
                warning "Failed to upload build log to Buildkite"
            }
        fi
        
        success "Buildkite artifact upload completed"
    else
        log "BUILDKITE environment not set, skipping artifact upload"
    fi
}

# Function to list available lunch targets
list_targets() {
    local build_dir=${1:-$BUILD_DIR}
    
    log "Listing available lunch targets..."
    
    if [ -d "$build_dir" ] && [ -d "$build_dir/.repo" ]; then
        cd "$build_dir"
        if [ -f "build/envsetup.sh" ]; then
            source build/envsetup.sh
            log "Available lunch targets:"
            lunch
        else
            error "Build environment not found. Run the build script first to set up the environment."
        fi
    else
        error "Build directory not found or not initialized. Run the build script first."
    fi
}

# Run main function with all arguments
main "$@"
