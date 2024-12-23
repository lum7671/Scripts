#!/usr/bin/env zsh

# 전체 설치 가능한 macOS 버전 나열
# softwareupdate --list-full-installers

# 특정 버전의 macOS 인스톨러 다운로드
# softwareupdate --fetch-full-installer --full-installer-version 13.2.1

# 최신 macOS 인스톨러 다운로드 및 자동 설치
softwareupdate --fetch-full-installer --launch-installer

# EOL
