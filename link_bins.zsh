#!/usr/bin/env zsh

# ===== CONFIGURATION =====
readonly TARGET_DIR="${HOME}/opt/bin"
readonly SOURCE_BASE="/usr/local/opt"
readonly DEPTH_MAP=(
    "bin:2"
    "uubin:4"
    "gnubin:4"
)
readonly EXCLUDE_PATTERNS=("*.dylib" "*.so")

# 버전 패턴 매칭용 정규식
readonly VERSION_PATTERN='@[0-9.]+$'

# 예외 설정: 특정 패키지의 특정 버전을 우선 사용
readonly PRIORITY_OVERRIDE=(
    # "node@18"  # 예: node 18 버전을 우선 사용하고 싶을 때
    # "python@3.8"
)

# ===== ERROR HANDLING =====
error() {
    echo "[ERROR] $*" >&2
    return 1
}

warn() {
    echo "[WARN] $*" >&2
}

info() {
    echo "[INFO] $*"
}

# ===== FUNCTION: 실행 가능 파일 필터링 =====
is_executable() {
    local file="$1"
    [[ -f "$file" && -x "$file" ]] || return 1

    # Shebang 검사를 간소화
    if head -c 2 "$file" 2>/dev/null | grep -q $'^\x23\x21'; then
        return 0
    fi

    local file_type=$(file -b "$file")
    case "$file_type" in
        *Mach-O*executable*|*Mach-O*64-bit*|*script*executable*|*Bourne-Again*|*Perl*|\
        *ELF*executable*|*POSIX*shell*|*Perl*script*|*Python*script*)
            return 0 ;;
        *Java*archive*|*compressed*Zip*)
            [[ "$file" == *.jar ]] && return 0 ;;
        *symbolic*link*)
            local target=$(readlink -f "$file")
            [[ -n "$target" ]] && is_executable "$target" ;;
        *)
            return 1 ;;
    esac
}

# ===== FUNCTION: 심볼릭 링크 생성 =====
create_link() {
    local src="$1"
    local real_src=$(readlink -f "$src" 2>/dev/null || echo "$src")
    local dest="${TARGET_DIR}/${src:t}"
    local basename=${src:t}

    [[ -x "$real_src" ]] || { warn "Missing execute permission: $src"; return 1; }

    # 이미 존재하는 링크 처리
    if [[ -e "$dest" ]]; then
        local current_src=$(readlink "$dest")
        local current_base=${current_src:t:h}
        
        # 현재 링크가 버전이 없는 formula이거나 우선순위 오버라이드에 있는 경우 건너뛰기
        if ! [[ $current_base =~ $VERSION_PATTERN ]] || is_priority_override "$current_base"; then
            warn "Skipping: $dest → $current_src (higher priority)"
            return 0
        fi
        
        # 새로운 소스가 버전이 있는 formula이고 우선순위 오버라이드가 아니면 건너뛰기
        if [[ $basename =~ $VERSION_PATTERN ]] && ! is_priority_override "$basename"; then
            warn "Skipping: $src (lower priority)"
            return 0
        fi

        if ((FORCE)); then
            rm -f "$dest"
        else
            warn "Exist: $dest → $current_src"
            return 0
        fi
    fi

    if ((DRY_RUN)); then
        info "[DRY] ln -s '$src' '$dest'"
    else
        ln -sfv "$src" "$dest"
    fi
}

# ===== FUNCTION: 우선순위 오버라이드 확인 =====
is_priority_override() {
    local name="$1"
    for override in $PRIORITY_OVERRIDE; do
        [[ "$name" == "$override" ]] && return 0
    done
    return 1
}

# ===== FUNCTION: 조건별 디렉토리 검색 =====
find_target_dirs() {
    local dir depth
    for entry in $DEPTH_MAP; do
        dir=${entry%:*}
        depth=${entry#*:}
        fd -d "$depth" -t d -L "^${dir}$" "$SOURCE_BASE" | while read -r p; do
            [[ -d "$p" && -e "$p" ]] && echo "$p"
        done
    done
}

# ===== MAIN LOGIC =====
main() {
    # 의존성 체크
    command -v fd >/dev/null || error "Install 'fd': brew install fd"
    command -v file >/dev/null || error "Command 'file' not found"

    # 타겟 디렉토리 생성
    mkdir -p "$TARGET_DIR" || error "Failed to create target directory"

    # 실행파일 처리
    find_target_dirs | while read -r bin_dir; do
        info "Scanning directory: $bin_dir"
        
        find "$bin_dir" -maxdepth 1 \( -type f -o -type l \) | while read -r exe; do
            local basename=${exe:t}
            
            # 제외 패턴 확인
            for pattern in $EXCLUDE_PATTERNS; do
                if [[ "$basename" == ${~pattern} ]]; then
                    warn "Excluded: $exe"
                    continue 2
                fi
            done

            if is_executable "$exe"; then
                create_link "$exe"
            else
                warn "Not executable: $exe"
            fi
        done
    done

    # 깨진 링크 정리
    local broken_links=()
    while IFS= read -r link; do
        if ! test -e "$link"; then
            broken_links+=("$link")
            info "[CLEAN] Found broken link: $link"
        fi
    done < <(find "$TARGET_DIR" -type l)

    # 깨진 링크 제거
    if ((${#broken_links[@]} > 0)); then
        if ((DRY_RUN)); then
            info "[DRY] Would remove ${#broken_links[@]} broken links"
        else
            for link in "${broken_links[@]}"; do
                rm -f "$link" && info "[CLEAN] Removed: $link"
            done
        fi
    fi
}

# ===== SETUP =====
# GNU readlink 우선 사용
(( $+commands[greadlink] )) && alias readlink="greadlink"

# ===== OPTION PARSING =====
typeset -i FORCE=0 DRY_RUN=0
while (($#)); do
    case "$1" in
        -f|--force) FORCE=1 ;;
        -d|--dry-run) DRY_RUN=1 ;;
        *) error "Unknown option: $1" ;;
    esac
    shift
done

# ===== ENTRY POINT =====
main "$@"
