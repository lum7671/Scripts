# upsum: Update Summarizer

`upsum`은 macOS 시스템 업데이트 로그를 분석하고, Gemini AI를 사용하여 요약한 후, 결과를 이메일로 전송하는 파이썬 기반의 CLI 도구입니다. 

macOS의 `launchd` 또는 `crontab`과 함께 사용하여 일일 업데이트 보고서를 자동으로 받아보는 데 유용합니다. (macOS에서는 `launchd`가 권장됩니다)

## 주요 기능

-   지정된 디렉토리에서 가장 최근의 로그 파일을 자동으로 감지합니다 (기본: `/private/tmp` - macOS update_all.zsh 로그 위치).
-   로그를 분석하여 **재부팅 필요 여부**와 **업데이트된 패키지 목록(버전 포함)**을 추출합니다.
-   macOS 시스템 업데이트, Homebrew, Mac App Store, 개발 도구(Python, Node.js, Rust 등) 업데이트를 구분하여 요약합니다.
-   Google Gemini API를 통해 자연스러운 한국어 요약문을 생성합니다.
-   SMTP를 통해 지정된 이메일 주소로 요약 보고서를 발송합니다.
-   `--dry-run` 옵션을 통해 이메일을 보내지 않고 결과만 확인할 수 있습니다.

## 설치 및 설정

### 1. 프로젝트 클론 및 의존성 설치

이 프로젝트는 [Rye](https://rye-up.com/)를 사용하여 파이썬 환경 및 의존성을 관리합니다.

```bash
git clone https://github.com/lum7671/upsum.git
cd upsum
rye sync
```

### 2. 환경 변수 설정

프로그램은 민감한 정보(API 키, 이메일 계정 등)를 환경 변수로부터 읽어옵니다. 프로젝트 루트 디렉토리에 있는 `.env.example` 파일을 `.env` 파일로 복사한 후, 내용을 자신의 환경에 맞게 수정하세요.

```bash
cp .env.example .env
```

`.env` 파일을 열고 다음 변수들의 값을 채워주세요.

```dotenv
# .env

# Google AI Studio에서 발급받은 Gemini API 키
GEMINI_API_KEY="YOUR_GEMINI_API_KEY"

# 이메일 발송을 위한 SMTP 서버 정보 (예: Gmail)
SMTP_HOST="smtp.gmail.com"
SMTP_PORT=587
SMTP_USER="YOUR_EMAIL@gmail.com"
# Gmail의 경우, 2단계 인증 사용 시 '앱 비밀번호'를 사용해야 합니다.
SMTP_PASSWORD="YOUR_APP_PASSWORD" 

# 요약 보고서를 받을 이메일 주소
MAIL_TO="recipient@example.com"
```

## 사용법

프로그램은 `upsum`이라는 CLI 명령어로 실행할 수 있습니다.

### 기본 실행

최신 로그 파일을 요약하고 이메일을 전송합니다. 로그는 기본적으로 `/private/tmp` 디렉토리에서 찾습니다 (update_all.zsh 스크립트의 기본 로그 위치).

```bash
rye run upsum
```

### Dry Run (테스트 실행)

이메일을 보내지 않고, 생성된 요약문을 터미널에서 확인하고 싶을 때 사용합니다.

```bash
rye run upsum --dry-run
```

### 다른 로그 디렉토리 지정

기본값이 아닌 다른 디렉토리에 있는 로그를 처리하려면 `--log-dir` 옵션을 사용하세요.

```bash
rye run upsum --log-dir ~/Library/Logs/UpdateAll/
```

## 자동 실행 설정

### macOS launchd 사용 (권장)

macOS에서는 `cron` 대신 `launchd`를 사용하는 것이 권장됩니다. 다음은 매일 새벽 4시에 upsum을 실행하는 launchd plist 파일 예제입니다.

`~/Library/LaunchAgents/com.user.upsum.plist` 파일을 생성하고 다음 내용을 추가하세요:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.upsum</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/YOUR_USERNAME/.rye/shims/rye</string>
        <string>run</string>
        <string>-p</string>
        <string>/Users/YOUR_USERNAME/git/Scripts/macos/upsum</string>
        <string>upsum</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>4</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/private/tmp/upsum.log</string>
    <key>StandardErrorPath</key>
    <string>/private/tmp/upsum_error.log</string>
</dict>
</plist>
```

**주의:** `YOUR_USERNAME`을 실제 사용자 이름으로 변경하세요.

plist 파일을 등록하려면:

```bash
launchctl load ~/Library/LaunchAgents/com.user.upsum.plist
```

등록을 해제하려면:

```bash
launchctl unload ~/Library/LaunchAgents/com.user.upsum.plist
```

### crontab 사용 (대안)

매일 새벽 4시에 자동으로 업데이트 요약을 이메일로 받으려면 `crontab -e`를 실행하고 다음 라인을 추가하세요. 경로는 자신의 환경에 맞게 수정해야 합니다.

```crontab
# 매일 새벽 4시에 upsum 실행
0 4 * * * $HOME/.rye/shims/rye run -p $HOME/git/Scripts/macos/upsum upsum > /private/tmp/upsum_cron.log 2>&1
```

**참고:** `crontab`에서 `rye run`을 실행하려면 전체 경로를 명시해주는 것이 안정적입니다. `which rye` 명령어로 `rye`의 설치 경로를 확인할 수 있습니다. `-p` 옵션으로 프로젝트 경로를 지정해야 올바르게 컨텍스트를 찾을 수 있습니다.