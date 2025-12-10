#!/bin/bash
set -e

STABLE_BIN="/usr/local/bin/zig"
DEV_BIN="/usr/local/bin/zig-dev"
JSON_URL="https://ziglang.org/download/index.json"
WORK_DIR="/tmp/zig-install-$$"

# Cleanup on exit
trap 'cleanup' EXIT INT TERM

cleanup() {
    [ -d "$WORK_DIR" ] && rm -rf "$WORK_DIR"
}

# Detect platform automatically
detect_platform() {
    local os=$(uname -s | tr '[:upper:]' '[:lower:]')
    local arch=$(uname -m)
    
    case "$os" in
        linux)
            case "$arch" in
                x86_64) echo "x86_64-linux" ;;
                aarch64|arm64) echo "aarch64-linux" ;;
                armv7l) echo "arm-linux" ;;
                riscv64) echo "riscv64-linux" ;;
                i686|i386) echo "x86-linux" ;;
                *) echo "Unsupported architecture: $arch" >&2; return 1 ;;
            esac
            ;;
        darwin)
            case "$arch" in
                x86_64) echo "x86_64-macos" ;;
                arm64|aarch64) echo "aarch64-macos" ;;
                *) echo "Unsupported architecture: $arch" >&2; return 1 ;;
            esac
            ;;
        *)
            echo "Unsupported OS: $os" >&2
            return 1
            ;;
    esac
}

PLATFORM=$(detect_platform) || exit 1

# Parse options
SKIP_BUILD_TEST=0
FORCE_INSTALL=0
while [[ "$1" == --* ]]; do
    case "$1" in
        --skip-test)
            SKIP_BUILD_TEST=1
            shift
            ;;
        --force)
            FORCE_INSTALL=1
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Parse action argument
ACTION=${1:-"status"}

# Verify file integrity with SHA256 and size
verify_integrity() {
    local file="$1"
    local expected_sha="$2"
    local expected_size="$3"
    
    # Check file size
    local actual_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
    if [ "$actual_size" != "$expected_size" ]; then
        echo "❌ 파일 크기 불일치: $actual_size != $expected_size" >&2
        return 1
    fi
    
    # Check SHA256
    local actual_sha
    if command -v sha256sum >/dev/null 2>&1; then
        actual_sha=$(sha256sum "$file" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        actual_sha=$(shasum -a 256 "$file" | awk '{print $1}')
    else
        echo "⚠️  SHA256 검증 도구 없음 (sha256sum 또는 shasum 필요)" >&2
        return 0  # Skip verification if tool not available
    fi
    
    if [ "$actual_sha" != "$expected_sha" ]; then
        echo "❌ SHA256 불일치:" >&2
        echo "  기대값: $expected_sha" >&2
        echo "  실제값: $actual_sha" >&2
        return 1
    fi
    
    echo "✅ 무결성 검증 완료 (SHA256 + 크기)"
    return 0
}

# Get current installed version
get_installed_version() {
    local bin="$1"
    if [ -f "$bin" ] && [ -x "$bin" ]; then
        "$bin" version 2>/dev/null | head -1
    else
        echo ""
    fi
}

test_build() {
    local zig_bin="$1"
    local test_dir="$(mktemp -d)"
    
    cd "$test_dir"
    echo 'const std=@import("std");pub fn main()void{std.debug.print("OK\n",.{});}' > test.zig
    
    # Try to build with timeout if available
    local result=1
    if command -v timeout >/dev/null 2>&1; then
        if timeout 10s "$zig_bin" build-exe test.zig 2>/dev/null; then
            result=0
        fi
    else
        # No timeout command, just try to build
        if "$zig_bin" build-exe test.zig 2>/dev/null; then
            result=0
        fi
    fi
    
    cd - >/dev/null
    rm -rf "$test_dir"
    return $result
}

# Download and install Zig with integrity verification
download_and_install() {
    local version="$1"
    local target_bin="$2"
    local json_key="$3"  # "0.15.2" or "master"
    
    # Check if already installed with same version
    if [ $FORCE_INSTALL -eq 0 ]; then
        local current_version=$(get_installed_version "$target_bin")
        if [ -n "$current_version" ] && [ "$current_version" = "$version" ]; then
            echo "✅ 이미 최신 버전이 설치되어 있습니다: $version"
            echo "💡 강제 재설치하려면: $0 --force $(basename $0 .sh | sed 's/manage_zig//')$ACTION"
            return 0
        fi
    fi
    
    echo "📥 다운로드 중: $version ($PLATFORM)"
    
    # Fetch all required info in one call
    local json_data=$(curl -s "$JSON_URL" | jq -r ".\"$json_key\".\"$PLATFORM\" | {tarball, shasum, size}")
    local url=$(echo "$json_data" | jq -r '.tarball')
    local sha=$(echo "$json_data" | jq -r '.shasum')
    local size=$(echo "$json_data" | jq -r '.size')
    
    if [ "$url" = "null" ] || [ -z "$url" ]; then
        echo "❌ 플랫폼 지원 안 함: $PLATFORM" >&2
        return 1
    fi
    
    # Create work directory
    mkdir -p "$WORK_DIR"
    cd "$WORK_DIR"
    
    # Backup existing binary
    if [ -f "$target_bin" ]; then
        echo "💾 기존 버전 백업: ${target_bin}.bak"
        sudo cp "$target_bin" "${target_bin}.bak"
    fi
    
    # Download
    local archive="zig-download.tar.xz"
    echo "⬇️  다운로드: $url"
    if ! wget -q --show-progress -O "$archive" "$url"; then
        echo "❌ 다운로드 실패" >&2
        return 1
    fi
    
    # Verify integrity
    echo "🔍 무결성 검증 중..."
    if ! verify_integrity "$archive" "$sha" "$size"; then
        echo "❌ 다운로드 파일 손상됨" >&2
        return 1
    fi
    
    # Extract
    echo "📦 압축 해제 중..."
    if ! tar xf "$archive"; then
        echo "❌ 압축 해제 실패" >&2
        return 1
    fi
    
    # Find extracted directory
    local extracted_dir=$(find . -maxdepth 1 -type d -name "zig-*" | head -1)
    if [ -z "$extracted_dir" ]; then
        echo "❌ 압축 해제된 디렉토리를 찾을 수 없음" >&2
        return 1
    fi
    
    # Test build before installation (optional)
    if [ $SKIP_BUILD_TEST -eq 0 ]; then
        echo "🧪 빌드 테스트 중..."
        if ! test_build "$extracted_dir/zig"; then
            echo "❌빌드 테스트 실패" >&2
            echo "💡 수동 테스트: $extracted_dir/zig version" >&2
            # Try to get version at least
            if "$extracted_dir/zig" version 2>/dev/null; then
                echo "⚠️  버전 표시는 가능하지만 빌드 실패." >&2
                echo "💡 건너뛰려면: $0 --skip-test $ACTION" >&2
            fi
            return 1
        fi
    else
        echo "⏭️  빌드 테스트 건너뜀 (--skip-test)"
        # At least check version
        echo "🔍 버전 확인 중..."
        if ! "$extracted_dir/zig" version; then
            echo "❌ zig 실행 불가" >&2
            return 1
        fi
    fi
    
    # Install
    echo "📥 설치 중: $target_bin"
    sudo cp "$extracted_dir/zig" "$target_bin"
    sudo chmod 755 "$target_bin"
    
    echo "✅ 설치 완료: $version"
    $target_bin version
    
    return 0
}

case "$ACTION" in
    "update-stable")
        STABLE_VER=$(curl -s "$JSON_URL" | jq -r 'to_entries[] | select(.key | test("^\\d+(\\.\\d+)*$")) | .key' | sort -V | tail -1)
        echo "📥 최신 stable: $STABLE_VER"
        
        if download_and_install "$STABLE_VER" "$STABLE_BIN" "$STABLE_VER"; then
            echo "✅ zig stable 업데이트 성공"
        else
            echo "❌ zig stable 업데이트 실패"
            if [ -f "${STABLE_BIN}.bak" ]; then
                echo "🔄 이전 버전 복원 중..."
                sudo cp "${STABLE_BIN}.bak" "$STABLE_BIN"
            fi
            exit 1
        fi
        ;;

    "update-dev")
        DEV_VER=$(curl -s "$JSON_URL" | jq -r '.master.version // empty')
        echo "📥 최신 dev: $DEV_VER"
        
        # Check for known unstable versions
        if [[ "$DEV_VER" == 0.16* ]]; then
            echo "⚠️  경고: 0.16.0-dev는 불안정할 수 있습니다"
            read -p "계속 진행하시겠습니까? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "취소됨"
                exit 0
            fi
        fi
        
        if download_and_install "$DEV_VER" "$DEV_BIN" "master"; then
            echo "✅ zig-dev 업데이트 성공"
        else
            echo "❌ zig-dev 업데이트 실패"
            if [ -f "${DEV_BIN}.bak" ]; then
                echo "🔄 이전 버전 복원 중..."
                sudo cp "${DEV_BIN}.bak" "$DEV_BIN"
            fi
            exit 1
        fi
        ;;

    "status")
        echo "=== Zig 상태 ==="
        echo "플랫폼: $PLATFORM"
        echo ""
        
        if [ -f "$STABLE_BIN" ]; then
            echo -n "- zig (stable): "
            if $STABLE_BIN version 2>/dev/null; then
                cd /tmp
                if test_build "$STABLE_BIN" 2>/dev/null; then
                    echo "  상태: ✅ 정상"
                else
                    echo "  상태: ⚠️  버전 표시는 되지만 빌드 실패"
                fi
            else
                echo "  상태: ❌ 실행 불가"
            fi
            [ -f "${STABLE_BIN}.bak" ] && echo "  백업: ${STABLE_BIN}.bak 존재"
        else
            echo "- zig (stable): ❌ 설치되지 않음"
        fi
        
        echo ""
        
        if [ -f "$DEV_BIN" ]; then
            echo -n "- zig-dev: "
            if $DEV_BIN version 2>/dev/null; then
                cd /tmp
                if test_build "$DEV_BIN" 2>/dev/null; then
                    echo "  상태: ✅ 정상"
                else
                    echo "  상태: ⚠️  버전 표시는 되지만 빌드 실패"
                fi
            else
                echo "  상태: ❌ 실행 불가"
            fi
            [ -f "${DEV_BIN}.bak" ] && echo "  백업: ${DEV_BIN}.bak 존재"
        else
            echo "- zig-dev: ❌ 설치되지 않음"
        fi
        ;;

    "list")
        echo "=== 사용 가능한 버전 ==="
        echo ""
        echo "Stable 버전:"
        curl -s "$JSON_URL" | jq -r 'to_entries[] | select(.key | test("^\\d+(\\.\\d+)*$")) | "  - \(.key) (릴리스: \(.value.date))"' | sort -V | tail -10
        echo ""
        echo "Dev 버전:"
        echo "  - $(curl -s "$JSON_URL" | jq -r '.master.version') (빌드: $(curl -s "$JSON_URL" | jq -r '.master.date'))"
        echo ""
        echo "현재 플랫폼: $PLATFORM"
        ;;
    
    "clean")
        echo "=== 백업 파일 정리 ==="
        [ -f "${STABLE_BIN}.bak" ] && sudo rm -v "${STABLE_BIN}.bak" || echo "stable 백업 없음"
        [ -f "${DEV_BIN}.bak" ] && sudo rm -v "${DEV_BIN}.bak" || echo "dev 백업 없음"
        ;;
    
    *)
        echo "사용법: $0 [옵션] {update-stable|update-dev|status|list|clean}"
        echo ""
        echo "옵션:"
        echo "  --skip-test    - 빌드 테스트 건너뛰기 (빠른 설치)"
        echo "  --force        - 같은 버전이어도 강제 재설치"
        echo ""
        echo "명령어:"
        echo "  update-stable  - 최신 안정 버전 설치"
        echo "  update-dev     - 최신 개발 버전 설치"
        echo "  status         - 설치된 버전 상태 확인"
        echo "  list           - 사용 가능한 버전 목록"
        echo "  clean          - 백업 파일 정리"
        echo ""
        echo "예제:"
        echo "  $0 update-stable                    # 빌드 테스트 포함"
        echo "  $0 --skip-test update-stable        # 빌드 테스트 건너뛰기"
        echo "  $0 --force update-stable            # 강제 재설치"
        echo "  $0 --skip-test --force update-stable # 조합 사용"
        exit 1
        ;;
esac

