#!/bin/bash
set -e

STABLE_BIN="/usr/local/bin/zig"
DEV_BIN="/usr/local/bin/zig-dev"
JSON_URL="https://ziglang.org/download/index.json"

cd /tmp

ACTION=${1:-"status"}

timeout_test() {
    timeout 10s "$1" build-exe test.zig 2>/dev/null && rm test* && return 0
    return 1
}

test_build() {
    echo 'const std=@import("std");pub fn main()void{std.debug.print("OK\n",.{});}' > test.zig
    timeout_test "$1"
}

case "$ACTION" in
    "update-stable")
        STABLE_VER=$(curl -s "$JSON_URL" | jq -r 'to_entries[] | select(.key | test("^\\d+(\\.\\d+)*$")) | .key' | sort -V | tail -1)
        echo "📥 최신 stable: $STABLE_VER"
        URL=$(curl -s "$JSON_URL" | jq -r ".\"$STABLE_VER\".\"aarch64-linux\".tarball")
        
        wget -O zig-stable.tar.xz "$URL"
        tar xf zig-stable.tar.xz
        sudo cp zig-aarch64-linux-*/zig "$STABLE_BIN"
        sudo chmod 755 "$STABLE_BIN"
        rm -rf zig-stable.tar.xz zig-aarch64-linux-*
        
        if test_build "$STABLE_BIN"; then
            echo "✅ zig ($STABLE_VER) 정상"
            $STABLE_BIN version
        else
            echo "❌ zig ($STABLE_VER) 파손 - 롤백"
        fi
        ;;

    "update-dev")
        echo "⚠️  최신 master (0.16.0-dev) 불안정. 이전 안정 dev 시도..."
        
        # 이전 안정 dev 버전 (index.json에 있는 0.15.x dev)
        DEV_VER=$(curl -s "$JSON_URL" | jq -r '.master.version // empty')
        if [[ "$DEV_VER" == 0.16* ]]; then
            echo "⚠️  0.16.0-dev 불안정 감지. 0.15.0-dev 사용"
            wget https://ziglang.org/builds/zig-aarch64-linux-0.15.0-dev.1429+04fe1bfe3.tar.xz -O zig-dev.tar.xz
        else
            URL=$(curl -s "$JSON_URL" | jq -r '.master."aarch64-linux".tarball')
            wget -O zig-dev.tar.xz "$URL"
        fi
        
        tar xf zig-dev.tar.xz
        sudo cp zig-aarch64-linux-*/zig "$DEV_BIN"
        sudo chmod 755 "$DEV_BIN"
        rm -rf zig-dev.tar.xz zig-aarch64-linux-*
        
        if test_build "$DEV_BIN"; then
            echo "✅ zig-dev 정상"
            $DEV_BIN version
        else
            echo "❌ zig-dev 파손. stable만 사용 권장"
        fi
        ;;

    "status")
        echo "=== Zig 상태 ==="
        [ -f "$STABLE_BIN" ] && echo "- zig: $(test_build "$STABLE_BIN" && $STABLE_BIN version || echo '파손')"
        [ -f "$DEV_BIN" ] && echo "- zig-dev: $(test_build "$DEV_BIN" && $DEV_BIN version || echo '파손')"
        ;;

    "list")
        echo "Stable (index.json):"
        curl -s "$JSON_URL" | jq -r 'to_entries[] | select(.key | test("^\\d+(\\.\\d+)*$")) | "- \(.key)"' | sort -V
        echo -e "\nDev (master): $(curl -s "$JSON_URL" | jq -r '.master.version')"
        ;;
esac

