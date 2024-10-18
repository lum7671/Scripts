#!/usr/bin/env zsh

TDY=$(date +"%Y-%m%d_%H%M-%S")

BUP="$HOME/PDS/rp4bdp/sync.backup"
LOG="/tmp/rp4bdp_sync-$TDY.log"
LIST="$HOME/PDS/rp4bdp/sync.list"
MYLIST=()
(
    echo "==========================================================="
    echo "$(date)"

    for line in "${(@f)"$(<$LIST)"}"
    {
        if [ -f "$line" ]; then
            MYLIST+=("$line")
        fi
    }

    [[ ! -d "$BUP" ]] && mkdir -vp "$BUP"
    apack -vf $BUP/$TDY.zip $MYLIST

    for line in "${MYLIST[@]}"
    {
        echo "BACKUP : $line"
        
        # 백업 대상 경로 설정
        backup_path="$HOME/PDS/rp4bdp"
        
        # 원본 경로를 '/'로 분할
        IFS='/' read -A path_parts <<< "$line"
        
        # 각 디렉토리와 파일 이름을 순회하며 처리
        for ((i=1; i<=${#path_parts}; i++)); do
            part=${path_parts[i]}
            if [[ "$part" == .* ]]; then
                part="dot${part}"
            fi
            backup_path+="/$part"
            
            # 마지막 부분(파일)이 아니면 디렉토리 생성
            if ((i < ${#path_parts})); then
                mkdir -p "$backup_path"
            fi
        done
        
        # 파일 백업
        install -v -C -m u=rw,go=r -D "$line" "$backup_path"
    }
    echo "CLEANING..."
    find "$BUP" -mtime +30 -name "*.zip" -type f -delete -print
) >> $LOG 2>&1

