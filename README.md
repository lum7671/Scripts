# Scripts

Scripts

## 주요 스크립트

### update_all.zsh

macOS 환경의 모든 패키지 관리자와 개발 도구를 한번에 업데이트하는 포괄적인 스크립트

**업데이트 대상:**

- macOS 시스템 업데이트 (softwareupdate)
- Homebrew (brew) - 패키지 및 Cask 업데이트
- Mac App Store 앱 (mas)
- Python 툴체인 (Rye)
- Rust 및 Cargo 패키지
- Node.js 및 NPM 글로벌 패키지
- Ruby 환경 (rbenv)
- Java 환경 (jenv)
- .NET 글로벌 도구
- Python pip 패키지
- Zsh 환경 (Oh My Zsh, zgenom)
- Emacs 패키지 (Doom Emacs)
- Git 저장소들

**사용법:**

```bash
./update_all.zsh
```

**특징:**

- 인터넷 연결 확인
- 각 도구별 개별 함수로 구조화
- 상세한 로그 출력 및 에러 핸들링
- 설치되지 않은 도구는 자동으로 스킵

### update_dns.zsh

oh.mypi.co, for.64-b.it DNS 업데이트
