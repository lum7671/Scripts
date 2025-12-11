#!/bin/bash
set -e

STABLE_BIN="/usr/local/bin/zig"
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
ACTION=${1:-"help"}
TARGET_VERSION=${2:-""}  # 선택적 버전 인자

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

# Check if version exists in JSON
version_exists() {
    local version="$1"
    if [ "$version" = "master" ]; then
        curl -s "$JSON_URL" | jq -e '.master' >/dev/null 2>&1
    else
        curl -s "$JSON_URL" | jq -e ".\"$version\"" >/dev/null 2>&1
    fi
}

# Get JSON key for version
get_json_key() {
    local version="$1"
    if [ "$version" = "master" ]; then
        echo "master"
    else
        echo "$version"
    fi
}

test_build() {
    local zig_bin="$1"
    local verbose="${2:-0}"  # 0 = quiet, 1 = verbose
    local test_dir="$(mktemp -d)"
    
    cd "$test_dir"
    echo 'const std=@import("std");pub fn main()void{std.debug.print("OK\n",.{});}' > test.zig
    
    if [ "$verbose" = "1" ]; then
        echo "📂 테스트 디렉토리: $test_dir"
        echo "🔧 Zig 바이너리: $zig_bin"
        echo "📝 테스트 코드:"
        cat test.zig
        echo ""
        echo "🏗️  빌드 실행 중..."
        echo "───────────────────────────────────────"
    fi
    
    # Try to build with timeout if available
    local result=1
    local stderr_file="$test_dir/stderr.txt"
    
    # Build without timeout, wait for completion
    if [ "$verbose" = "1" ]; then
        "$zig_bin" build-exe test.zig 2>&1 | tee "$stderr_file"
        result=${PIPESTATUS[0]}
    else
        "$zig_bin" build-exe test.zig 2>"$stderr_file"
        result=$?
    fi
    
    if [ "$verbose" = "1" ]; then
        echo "───────────────────────────────────────"
        echo "📊 종료 코드: $result"
        if [ $result -eq 0 ]; then
            echo "✅ 빌드 성공!"
            if [ -f "test" ]; then
                echo "🚀 실행 테스트:"
                ./test
            fi
        else
            echo "❌ 빌드 실패!"
            if [ -s "$stderr_file" ]; then
                echo "📄 에러 메시지:"
                cat "$stderr_file"
            fi
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
    
    # Backup existing standard library
    if [ -d "/usr/local/lib/zig" ]; then
        echo "💾 표준 라이브러리 백업: /usr/local/lib/zig.bak"
        sudo rm -rf /usr/local/lib/zig.bak
        sudo cp -r /usr/local/lib/zig /usr/local/lib/zig.bak
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
    
    # Install standard library first
    if [ -d "$extracted_dir/lib" ]; then
        echo "📚 표준 라이브러리 설치 중: /usr/local/lib/zig"
        sudo mkdir -p /usr/local/lib
        sudo rm -rf /usr/local/lib/zig
        sudo cp -r "$extracted_dir/lib" /usr/local/lib/zig
    fi
    
    # Install binary
    echo "📥 바이너리 설치 중: $target_bin"
    sudo cp "$extracted_dir/zig" "$target_bin"
    sudo chmod 755 "$target_bin"
    
    # Test build after installation (optional)
    if [ $SKIP_BUILD_TEST -eq 0 ]; then
        echo "🧪 빌드 테스트 중..."
        if ! test_build "$target_bin"; then
            echo "❌ 빌드 테스트 실패" >&2
            echo "💡 수동 테스트: $target_bin version" >&2
            # Try to get version at least
            if "$target_bin" version 2>/dev/null; then
                echo "⚠️  버전 표시는 가능하지만 빌드 실패." >&2
                echo "💡 건너뛰려면: $0 --skip-test $ACTION" >&2
            fi
            # Rollback
            if [ -f "${target_bin}.bak" ]; then
                echo "🔄 이전 버전 복원 중..." >&2
                sudo cp "${target_bin}.bak" "$target_bin"
            fi
            return 1
        fi
    else
        echo "⏭️  빌드 테스트 건너뜀 (--skip-test)"
        # At least check version
        echo "🔍 버전 확인 중..."
        if ! "$target_bin" version; then
            echo "❌ zig 실행 불가" >&2
            # Rollback
            if [ -f "${target_bin}.bak" ]; then
                echo "🔄 이전 버전 복원 중..." >&2
                sudo cp "${target_bin}.bak" "$target_bin"
            fi
            return 1
        fi
    fi
    
    echo "✅ 설치 완료: $version"
    $target_bin version
    
    return 0
}

case "$ACTION" in
    "update")
        # Determine which version to install
        if [ -z "$TARGET_VERSION" ]; then
            # No version specified, use latest stable version
            echo "📥 버전을 지정하지 않았으므로 최신 안정 버전 설치합니다"
            TARGET_VERSION=$(curl -s "$JSON_URL" | jq -r 'to_entries[] | select(.key | test("^\\d+(\\.\\d+)*$")) | .key' | sort -V | tail -1)
            if [ -z "$TARGET_VERSION" ]; then
                echo "❌ 최신 버전을 조회할 수 없습니다"
                exit 1
            fi
            echo "📌 선택된 버전: $TARGET_VERSION"
        fi
        
        # Validate version exists
        if ! version_exists "$TARGET_VERSION"; then
            echo "❌ 버전을 찾을 수 없음: $TARGET_VERSION"
            exit 1
        fi
        
        # Get version info
        if [ "$TARGET_VERSION" = "master" ]; then
            DISPLAY_VER=$(curl -s "$JSON_URL" | jq -r '.master.version')
        else
            DISPLAY_VER="$TARGET_VERSION"
        fi
        
        JSON_KEY=$(get_json_key "$TARGET_VERSION")
        echo "📥 최신 버전: $DISPLAY_VER"
        
        if download_and_install "$DISPLAY_VER" "$STABLE_BIN" "$JSON_KEY"; then
            echo "✅ Zig 업데이트 성공"
        else
            echo "❌ Zig 업데이트 실패"
            if [ -f "${STABLE_BIN}.bak" ]; then
                echo "🔄 이전 버전 복원 중..."
                sudo cp "${STABLE_BIN}.bak" "$STABLE_BIN"
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
        ;;

    "list")
        echo "=== 사용 가능한 버전 ==="
        echo ""
        echo "Stable 버전:"
        curl -s "$JSON_URL" | jq -r 'to_entries[] | select(.key | test("^\\d+(\\.\\d+)*$")) | "  - \(.key) (릴리스: \(.value.date))"' | sort -V | tail -10
        echo ""
        echo "현재 플랫폼: $PLATFORM"
        ;;
    
    "build-test")
        echo "=== Zig 빌드 테스트 ==="
        echo ""
        
        if [ -f "$STABLE_BIN" ]; then
            echo "🔍 stable 버전 테스트: $STABLE_BIN"
            $STABLE_BIN version
            echo ""
            if test_build "$STABLE_BIN" 1; then
                echo "✅ stable 빌드 테스트 성공"
            else
                echo "❌ stable 빌드 테스트 실패"
            fi
            echo ""
        else
            echo "⚠️  stable 버전 미설치"
            echo ""
        fi
        ;;
    
    "clean")
        echo "=== 백업 파일 정리 ==="
        [ -f "${STABLE_BIN}.bak" ] && sudo rm -v "${STABLE_BIN}.bak" || echo "stable 백업 없음"
        ;;
    
    "help")
        echo "사용법: $0 [옵션] {update|status|list|build-test|clean|help}"
        echo ""
        echo "옵션:"
        echo "  --skip-test    - 빌드 테스트 건너뛰기 (빠른 설치)"
        echo "  --force        - 같은 버전이어도 강제 재설치"
        echo ""
        echo "명령어:"
        echo "  update <ver>   - 지정된 Zig 버전 설치 (예: update 0.15.2, update master)"
        echo "  status         - 설치된 버전 상태 확인"
        echo "  list           - 사용 가능한 Zig 버전 목록"
        echo "  build-test     - 빌드 테스트 실행 (디버깅용)"
        echo "  clean          - 백업 파일 정리"
        echo "  help           - 이 도움말 표시"
        echo ""
        echo "예제:"
        echo "  $0 update 0.15.2                    # 특정 버전 설치 (빌드 테스트 포함)"
        echo "  $0 --skip-test update 0.15.2        # 특정 버전 설치 (빌드 테스트 건너뛰기)"
        echo "  $0 --force update 0.15.2            # 강제 재설치"
        echo "  $0 update master                    # 최신 개발 버전 설치"
        echo ""
        echo "버전 확인:"
        echo "  $0 list"
        ;;
    
    *)
        echo "❌ 알 수 없는 명령어: $ACTION" >&2
        echo "💡 도움말: $0 help" >&2
        exit 1
        ;;
esac

