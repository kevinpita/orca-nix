#!/usr/bin/env bash
set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

readonly GITHUB_REPO="stablyai/orca"
readonly PACKAGE_FILE="package.nix"
readonly X64_SYSTEM="x86_64-linux"
readonly ARM64_SYSTEM="aarch64-linux"
readonly X64_APPIMAGE="orca-linux.AppImage"
readonly ARM64_APPIMAGE="orca-linux-arm64.AppImage"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

flake_ref() {
    echo "path:$(pwd -P)#orca"
}

flake_path() {
    echo "path:$(pwd -P)"
}

get_current_version() {
    sed -n 's/.*version = "\([^"]*\)".*/\1/p' "$PACKAGE_FILE" | head -1
}

get_latest_version() {
    local tag
    tag=$(gh api "repos/$GITHUB_REPO/releases/latest" --jq '.tag_name' 2>/dev/null || echo "")
    if [ -z "$tag" ]; then
        log_error "Failed to fetch latest version from GitHub"
        exit 1
    fi
    echo "$tag" | sed 's/^v//'
}

ensure_in_repository_root() {
    if [ ! -f "flake.nix" ] || [ ! -f "$PACKAGE_FILE" ]; then
        log_error "flake.nix or $PACKAGE_FILE not found. Run this script from the repository root."
        exit 1
    fi
}

ensure_required_tools_installed() {
    command -v curl >/dev/null 2>&1 || { log_error "curl is required but not installed."; exit 1; }
    command -v gh >/dev/null 2>&1 || { log_error "gh is required but not installed."; exit 1; }
    command -v grep >/dev/null 2>&1 || { log_error "grep is required but not installed."; exit 1; }
    command -v nix >/dev/null 2>&1 || { log_error "nix is required but not installed."; exit 1; }
    command -v perl >/dev/null 2>&1 || { log_error "perl is required but not installed."; exit 1; }
}

print_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --version VERSION  Update to a specific version"
    echo "  --check            Only check for updates"
    echo "  --help             Show this help message"
}

parse_arguments() {
    local target_version=""
    local check_only=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --version)
                if [ $# -lt 2 ]; then
                    log_error "--version requires a value"
                    print_usage
                    exit 1
                fi
                target_version="$2"
                shift 2
                ;;
            --check)
                check_only=true
                shift
                ;;
            --help)
                print_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done

    echo "$target_version|$check_only"
}

update_version() {
    local version="$1"
    perl -0pi -e "s/version = \"[^\"]+\";/version = \"$version\";/" "$PACKAGE_FILE"
}

set_system_hash() {
    local system="$1"
    local hash="$2"
    perl -0pi -e "s|($system = \\{.*?hash = )\"[^\"]+\";|\${1}\"$hash\";|s" "$PACKAGE_FILE"
}

get_release_metadata() {
    local version="$1"
    local metadata_file="$2"
    curl -fsSL "https://github.com/$GITHUB_REPO/releases/download/v$version/$metadata_file"
}

extract_appimage_hash() {
    local version="$1"
    local metadata_file="$2"
    local appimage_name="$3"

    local hash
    hash=$(get_release_metadata "$version" "$metadata_file" | awk -v appimage="$appimage_name" '
        $1 == "-" && $2 == "url:" && $3 == appimage { found = 1; next }
        found && $1 == "sha512:" { print "sha512-" $2; exit }
    ')

    if [ -z "$hash" ]; then
        log_error "Failed to extract sha512 hash for $appimage_name from $metadata_file"
        exit 1
    fi

    echo "$hash"
}

refresh_hashes() {
    local version="$1"
    local x64_hash
    local arm64_hash

    log_info "Refreshing x86_64-linux AppImage hash"
    x64_hash=$(extract_appimage_hash "$version" "latest-linux.yml" "$X64_APPIMAGE")
    set_system_hash "$X64_SYSTEM" "$x64_hash"

    log_info "Refreshing aarch64-linux AppImage hash"
    arm64_hash=$(extract_appimage_hash "$version" "latest-linux-arm64.yml" "$ARM64_APPIMAGE")
    set_system_hash "$ARM64_SYSTEM" "$arm64_hash"
}

verify_update() {
    log_info "Building Orca"
    nix build "$(flake_ref)" --print-build-logs

    log_info "Checking Orca CLI"
    local help
    help=$(./result/bin/orca --help)
    grep -q 'Usage: orca' <<< "$help"

    log_info "Verifying package contents"
    test -x ./result/bin/orca
    test -x ./result/bin/orca-ide
}

update_flake_lock() {
    log_info "Updating flake.lock"
    nix flake update --flake "$(flake_path)"
}

show_changes() {
    echo ""
    log_info "Changes made:"
    git diff --stat "$PACKAGE_FILE" flake.lock 2>/dev/null || true
}

update_to_version() {
    local current_version="$1"
    local new_version="$2"

    cp "$PACKAGE_FILE" "$PACKAGE_FILE.bak"

    log_info "Updating Orca from $current_version to $new_version"
    update_version "$new_version"
    refresh_hashes "$new_version"
    verify_update
    update_flake_lock
    rm -f "$PACKAGE_FILE.bak"
    show_changes
}

main() {
    ensure_in_repository_root
    ensure_required_tools_installed

    local args
    args=$(parse_arguments "$@")
    local target_version
    target_version=$(echo "$args" | cut -d'|' -f1)
    local check_only
    check_only=$(echo "$args" | cut -d'|' -f2)

    local current_version
    current_version=$(get_current_version)
    local latest_version
    latest_version=$(get_latest_version)

    if [ -n "$target_version" ]; then
        latest_version="$target_version"
    fi

    log_info "Current version: $current_version"
    log_info "Latest version: $latest_version"

    if [ "$current_version" = "$latest_version" ]; then
        log_info "Already up to date"
        exit 0
    fi

    if [ "$check_only" = true ]; then
        log_info "Update available: $current_version -> $latest_version"
        exit 1
    fi

    update_to_version "$current_version" "$latest_version"
}

main "$@"
