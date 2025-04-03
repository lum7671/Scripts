#!/usr/bin/env zsh

# ===== CONFIGURATION =====
TARGET_DIR="${HOME}/opt/bin"          # 심볼릭 링크 생성 위치
SOURCE_BASE="/usr/local/opt"          # 검색 시작 경로
DIR_PATTERNS=("bin" "uubin" "gnubin") # 완전 매칭 대상 디렉토리
DEPTH_MAP=( # 디렉토리 별 깊이 매핑
    "bin:2"
    "uubin:4"
    "gnubin:4"
)

EXCLUDE_PATTERNS=("*.dylib" "*.so") # 제외할 파일 패턴

# ===== FUNCTION: 실행 가능 파일 필터링 =====
is_executable() {
    [[ -f "$1" ]] || return 1
    [[ -x "$1" ]] || return 1

    # 1. Shebang 우선 검사 (모든 파일 대상)
    if dd if="$1" bs=2 count=1 2>/dev/null | grep -q $'^\x23\x21'; then
        return 0
    fi

    case $(file -b "$1") in
        # macOS 확장 패턴 (모든 쉘 스크립트 포괄)
        *Mach-O*executable*|*Mach-O*64-bit*|*script*executable*|*Bourne-Again*|*Perl*)
            return 0 ;;
        # Linux 확장 패턴
        *ELF*executable*|*POSIX*shell*|*Perl*script*|*Python*script*)
            return 0 ;;
        # Java/JAR 파일
        *Java*archive*|*compressed*Zip*)
            [[ "$1" == *.jar ]] && return 0 ;;
        # 심볼릭 링크 심층 검사
        *symbolic*link*)
            local target=$(readlink -f "$1")
            [[ -n "$target" ]] && is_executable "$target" ;;
        *)
            return 1 ;;
    esac
}



# ===== FUNCTION: 심볼릭 링크 생성 =====
create_link() {
    local src="$1"

    # 최종 원본 확인
    local real_src=$(readlink -f "$src" 2>/dev/null || echo "$src")
    if [[ ! -x "$real_src" ]]; then
        echo "[WARN] Missing execute permission: $src" >&2
        return 1
    fi

    local dest="${TARGET_DIR}/${src:t}" # 파일명만 추출

    # 이미 존재하는 링크 처리
    if [[ -e "$dest" ]]; then
        if ((FORCE)); then
            rm -f "$dest"
        else
            echo "[SKIP] Exist: $dest → $(readlink "$dest")" >&2
            return
        fi
    fi

    # 실제 링크 생성
    if ((DRY_RUN)); then
        echo "[DRY] ln -s '$src' '$dest'"
    else
        ln -sfv "$src" "$dest"
    fi
}

# ===== DYNAMIC DEPTH CALCULATION =====
calculate_max_depth() {
    local max=0
    for entry in $DEPTH_MAP; do
        local depth=${entry#*:}
        ((depth > max)) && max=$depth
    done
    echo $max
}
FD_MAX_DEPTH=$(calculate_max_depth)

# ===== FUNCTION: 조건별 디렉토리 검색 =====
# find_target_dirs() {
#     local pattern depth
#     for entry in $DEPTH_MAP; do
#         local dir=${entry%:*}
#         local depth=${entry#*:}
#         fd -d $depth -t d -L "^${dir}$" "$SOURCE_BASE"
#     done
# }

# find_target_dirs() {
#     local pattern depth
#     for entry in $DEPTH_MAP; do
#         local dir=${entry%:*}
#         local depth=${entry#*:}
#         # 절대 경로 기준으로 검색
#         fd -d $depth -t d -L "^${dir}$" "/usr/local/opt" --base-directory="/usr/local/opt"
#
#         # 디버깅 코드 추가
#         echo "[DEBUG] Searching for '$dir' at depth $depth"
#         fd -d $depth -t d -L "^${dir}$" "/usr/local/opt" --print0 | xargs -0 -I{} echo "[FOUND] {}"
#
#     done
# }

# ===== ENHANCED DIRECTORY VALIDATION =====
find_target_dirs() {
    local pattern depth
    for entry in $DEPTH_MAP; do
        local dir=${entry%:*}
        local depth=${entry#*:}

        # 3단계 유효성 검사:
        # 1. fd로 기본 검색
        # 2. test -d로 실제 디렉토리 확인
        # 3. readlink로 최종 대상 확인
        fd -d $depth -t d -L "^${dir}$" "$SOURCE_BASE" \
            -x bash -c '
                for p; do
                    [[ -d "$p" ]] && [[ -e "$p" ]] && echo "$p"
                done' _ {} +
    done
}

# ===== MAIN LOGIC =====
main() {
    # 의존성 체크
    if ! command -v fd &>/dev/null; then
        echo "[ERROR] Install 'fd': brew install fd" >&2
        exit 127
    fi

    # 타겟 디렉토리 생성
    mkdir -p "$TARGET_DIR" || exit 1

    # FD로 조건별 디렉토리 검색 (깊이+이름 동시 필터링)
    find_target_dirs | while read bin_dir; do
        echo "[SCAN] Directory: $bin_dir"

        # 실행 파일 처리
        # find "$bin_dir" -maxdepth 1 -type f | while read exe; do
        # 파일+링크 동시 검색
        find "$bin_dir" -maxdepth 1 \( -type f -o -type l \) | while read exe; do

            # 제외 패턴 확인
            for pattern in $EXCLUDE_PATTERNS; do
                # [[ "$exe" == $~pattern ]] && continue 2
                if [[ "${exe:t}" == ${~pattern} ]]; then
                    echo "[SKIP] Excluded: $exe"
                    continue 2
                fi
            done

            # 실행 가능성 검증
            if is_executable "$exe"; then
                create_link "$exe"
            else
                echo "[SKIP] Not executable: $exe"
            fi
            # is_executable "$exe" || continue
            # 심볼릭 링크 생성
            # create_link "$exe"
        done
    done

    # 깨진 링크 정리
    find "$TARGET_DIR" -type l | while read link; do
        [[ -e "$link" ]] || {
            echo "[CLEAN] Removing broken: $link" >&2
            ((DRY_RUN)) || rm -f "$link"
        }
    done
}

# ===== OPTION PARSING =====
while (($#)); do
    case "$1" in
    -f | --force) FORCE=1 ;;
    -d | --dry-run) DRY_RUN=1 ;;
    *)
        echo "Unknown option: $1" >&2
        exit 1
        ;;
    esac
    shift
done

# GNU readlink 우선 사용
if (( $+commands[greadlink] )); then
    alias readlink="greadlink"
fi


# ===== ENTRY POINT =====
main "$@"
