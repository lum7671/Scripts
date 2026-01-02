# update_all.zsh 개선 작업 (2026-01-02)

## 로그 분석 결과

실행 로그: `update_all-20260102_114802.log`

---

## 발견된 문제점

### 1. 🔴 심각한 오류 (High Priority)

#### 1.1 .NET 도구 업데이트 미처리 예외
- **위치**: 로그 83-103번째 줄
- **오류**:
  ```
  Unhandled exception: System.IO.DirectoryNotFoundException: 
  Could not find a part of the path '/Users/1001028/.dotnet/tools/.store/sdk/1.0.0/sdk/1.0.0/tools'
  ```
- **원인**: 손상되었거나 누락된 .NET SDK 도구 디렉토리
- **영향**: 스크립트 실행 중단 가능성
- **해결 방안**:
  - `dotnet tool update` 명령에 오류 처리 추가 (`|| true`)
  - 영어 로케일 강제 설정 (`LANG=en_US.UTF-8`)
  - 개별 도구 실패 시에도 계속 진행

#### 1.2 upsum 디렉토리 경로 오류
- **위치**: 로그 182번째 줄
- **오류**: `ERROR: upsum directory not found at /home/dietpi/git/upsum`
- **원인**: Linux/DietPi 전용 하드코딩된 경로가 macOS에서 동작 안 함
- **해결 방안**: `/home/dietpi/git/upsum` → `$HOME/git/Scripts/macos/upsum`

#### 1.3 Homebrew deprecated 플래그
- **위치**: 로그 9-13번째 줄
- **경고**: `Warning: Calling the --[no-]quarantine switch is deprecated!`
- **해결 방안**: `brew upgrade --cask` 명령에서 `--no-quarantine` 플래그 제거

---

### 2. 🟡 경고 및 개선 사항 (Medium Priority)

#### 2.1 NVM 호환성 경고
- **위치**: 로그 59번째 줄
- **경고**: `nvm is not compatible with the "NPM_CONFIG_PREFIX" environment variable`
- **현재 상태**: 스크립트가 변수를 unset하지만, nvm 로딩 시점에 이미 경고 출력
- **해결 방안**: nvm.sh 로딩 전에 `NPM_CONFIG_PREFIX` unset 또는 stderr 리디렉션

#### 2.2 .NET 로케일 불일치
- **위치**: 로그 84-114번째 줄
- **문제**: .NET CLI가 한국어 메시지 출력하여 로그 파싱 어려움
- **해결 방안**: `DOTNET_CLI_UI_LANGUAGE=en` 환경변수 설정

#### 2.3 Git 저장소 uncommitted 변경사항
- **위치**: 로그 180번째 줄
- **메시지**: `Warning: Uncommitted changes in /Users/1001028/git/lsr/ - skipping pull`
- **현재 상태**: 정상 동작 (의도된 스킵)
- **개선 가능**: 마지막에 스킵된 저장소 요약 표시

#### 2.4 Deprecated formula 경고
- **위치**: 로그 14-16번째 줄
- **경고**: `icu4c@77` 사용 중단 예정
- **개선 가능**: `brew doctor` 출력 파싱하여 사용자에게 알림

---

### 3. 🟢 성능 개선 (Low Priority)

#### 3.1 Emacs 업데이트 verbose 출력
- **위치**: 로그 132-175번째 줄
- **문제**: 151개 패키지 상태를 모두 출력 (ANSI escape 포함)
- **개선 가능**: 중요한 정보만 필터링하여 출력

#### 3.2 Git 저장소 순차 업데이트
- **현재**: 저장소를 하나씩 순차적으로 업데이트
- **개선 가능**: 병렬 처리로 속도 향상 (background jobs 활용)

#### 3.3 전체 실패 추적 부재
- **문제**: 개별 업데이트 실패 시 최종 요약 없음
- **개선 가능**: `FAILED_UPDATES` 배열로 실패 항목 추적 및 요약 출력

---

## 수정 계획

### Step 1: .NET 오류 처리 개선
- [ ] `update_dotnet()` 함수에 오류 처리 추가
- [ ] 영어 로케일 강제 설정
- [ ] 개별 도구 실패 무시하고 계속 진행

### Step 2: upsum 경로 수정
- [ ] `run_upsum()` 함수의 하드코딩된 경로 수정
- [ ] macOS 호환 경로로 변경: `$HOME/git/Scripts/macos/upsum`

### Step 3: Homebrew deprecated 플래그 제거
- [ ] `update_homebrew()` 함수에서 `--no-quarantine` 제거
- [ ] 관련 주석 업데이트

### Step 4: NVM 경고 억제
- [ ] nvm.sh 소싱 전에 `NPM_CONFIG_PREFIX` unset 이동
- [ ] 또는 stderr 리디렉션으로 경고 숨김

### Step 5: 실패 추적 기능 추가
- [ ] `FAILED_UPDATES` 전역 배열 선언
- [ ] 각 update 함수에서 실패 시 배열에 추가
- [ ] `main()` 함수에서 최종 요약 출력

### Step 6: (선택) 성능 개선
- [ ] Git 저장소 병렬 업데이트
- [ ] Emacs 출력 필터링
- [ ] Deprecated formula 자동 감지

---

## 구현 우선순위

1. **Step 1-3 (High Priority)**: 즉시 수정 필요한 오류들
2. **Step 4-5 (Medium Priority)**: 사용성 개선
3. **Step 6 (Low Priority)**: 향후 개선 사항

---

## 참고 사항

- 모든 수정은 기존 기능을 유지하면서 진행
- 각 step별로 테스트 가능하도록 분리
- 로그 출력 일관성 유지 (info/error/success/skip)

---

## Linux → macOS 포팅 작업 (2026-01-02)

### upsum 도구 macOS 포팅 완료

`upsum` 디렉토리의 Python 스크립트가 DietPi Linux 전용에서 macOS 호환으로 변경되었습니다.

#### 수정된 파일

1. **upsum/src/upsum/\_\_main\_\_.py**
   - DietPi OS 업데이트 체크 로직 제거
   - Gemini AI 프롬프트를 macOS 시스템 전용으로 재작성
     - macOS 시스템 업데이트 (softwareupdate)
     - Homebrew formulae 및 casks
     - Mac App Store 앱
     - 개발 도구 (Python/Rye, Node.js, Rust, Ruby, Java, .NET)
     - Doom Emacs, Oh My Zsh
     - Git 저장소 업데이트
   - 기본 로그 디렉토리: `~/logs` → `/private/tmp`

2. **upsum/README.md**
   - macOS 환경 명시 및 launchd 사용 권장
   - Linux 경로(`/home/dietpi`) → macOS 경로(`$HOME`, `/Users/username`)
   - launchd plist 파일 예제 추가
   - crontab 예제를 macOS 경로로 업데이트

3. **upsum/.env.example** (신규 생성)
   - 환경 변수 설정 템플릿 제공
   - Gmail 앱 비밀번호 사용법 안내
   - macOS Mail.app SMTP 설정 참고사항

#### 사용 방법

```bash
# upsum 디렉토리로 이동
cd upsum

# 환경 변수 설정
cp .env.example .env
# .env 파일을 편집하여 실제 API 키와 이메일 설정 입력

# 테스트 실행 (dry-run)
rye run upsum --dry-run

# 실제 이메일 발송
rye run upsum
```

#### 자동화 설정 (launchd)

매일 새벽 4시에 자동 실행하려면 `~/Library/LaunchAgents/com.user.upsum.plist` 파일을 생성하세요. 자세한 내용은 `upsum/README.md` 참조.

---

## 전체 시스템 업데이트 흐름

1. **update_all.zsh 실행** → `/private/tmp/update_all-YYYYMMDD_HHMMSS.log` 생성
2. **upsum 자동 실행** (launchd 또는 cron) → 로그 분석 및 이메일 발송
3. **이메일 수신** → macOS 시스템 업데이트 요약 확인
