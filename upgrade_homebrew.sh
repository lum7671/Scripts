#!/bin/bash

PATH="/usr/local/bin:$PATH"

# 로그 파일 설정
LOG_FILE="/tmp/upgrade_log.txt"

# 현재 날짜와 시간
CURRENT_DATE=$(date "+%Y-%m-%d %H:%M:%S")

# 로그 시작
echo "===== 업그레이드 시작: $CURRENT_DATE =====" >> "$LOG_FILE"

# Homebrew 업데이트
echo "Homebrew 업데이트 중..." >> "$LOG_FILE"
brew update >> "$LOG_FILE" 2>&1

# Homebrew 업그레이드
echo "Homebrew 패키지 업그레이드 중..." >> "$LOG_FILE"
brew upgrade >> "$LOG_FILE" 2>&1

# Homebrew Cask 업그레이드 (GUI 애플리케이션)
echo "Homebrew Cask 애플리케이션 업그레이드 중..." >> "$LOG_FILE"
brew upgrade --cask >> "$LOG_FILE" 2>&1

# 정리
echo "정리 중..." >> "$LOG_FILE"
brew cleanup >> "$LOG_FILE" 2>&1

# 로그 종료
echo "===== 업그레이드 완료: $(date "+%Y-%m-%d %H:%M:%S") =====" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
