import os
import re
import glob
import smtplib
import argparse
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path
from dotenv import load_dotenv
from google.genai import Client
from markdown_it import MarkdownIt
import datetime


# Get today's date
today = datetime.date.today()

# Format the date as "YYYY년 MM월 DD일"
__formatted_date__ = today.strftime("%Y년 %m월 %d일")


def find_latest_log_file(log_dir):
    """지정된 디렉토리에서 가장 최근의 로그 파일을 찾습니다."""
    log_dir_path = Path(log_dir).expanduser()
    if not log_dir_path.exists() or not log_dir_path.is_dir():
        raise FileNotFoundError(f"Log directory not found: {log_dir_path}")

    list_of_files = glob.glob(str(log_dir_path / '*'))
    if not list_of_files:
        return None
    latest_file = max(list_of_files, key=os.path.getmtime)
    return latest_file

def parse_log_file(file_path):
    """로그 파일을 파싱하여 재부팅 필요 여부와 전체 로그 내용을 반환합니다."""
    with open(file_path, 'r') as f:
        content = f.read()

    reboot_required = "reboot is required" in content.lower() or "rebooting" in content.lower()

    parsed_data = {
        "reboot_required": reboot_required,
        "log_content": content,
    }
    return parsed_data

def generate_summary_with_gemini(api_key, parsed_data):
    """Gemini API를 사용하여 요약문을 생성합니다."""
    client = Client(api_key=api_key)

    log_content = parsed_data["log_content"]

    prompt = f"""
    당신은 macOS 시스템 관리자를 위한 보고서 작성 도우미입니다. 
    업데이트된 패키지 목록을 **깔끔하고 간결하게** 정리한 보고서를 작성해주세요.
    작성일은 오늘 날짜인 `{__formatted_date__}` 로 사용해 주세요.

    **로그 내용:**
    ```
    {log_content}
    ```

    **작성 지침:**

    1. **형식은 깔끔하고 간결하게:**
       - 한 항목 한 줄: `패키지명: 이전버전 → 새로운버전`
       - 장황한 설명은 제외
       - 필요한 정보만 명확하게

    2. **출처별로 구분:**
       - **## macOS System Updates** (macOS 시스템 업데이트)
       - **## Homebrew Formulae** (커맨드라인 도구)
       - **## Homebrew Casks** (GUI 애플리케이션)
       - **## Mac App Store**
       - **## Python (Pip)**
       - **## Node.js/NPM**
       - **## Rust/Cargo**
       - **## Ruby (Gem)**
       - **## Java (Jenv)**
       - **.NET**
       - **## Rye**
       - **## Oh My Zsh**
       - **## Emacs**
       - **## Git Repositories** (git 저장소 업데이트)

    3. **버전 표기법:**
       - 형식: `패키지: 1.0.0 → 2.0.0`
       - 버전 정보가 없으면: `패키지: 업데이트됨` 또는 `패키지: 설치됨`

    4. **유의사항:**
       - 각 섹션에 업데이트된 항목만 포함 (변경사항 없으면 섹션 생략)
       - 오류나 실패한 항목은 섹션 끝에 **[실패]** 표시
       - Deprecated 경고는 **[경고]** 표시

    5. **보고서 예시:**

    # {__formatted_date__} macOS 시스템 업데이트 보고서

    ## Homebrew Formulae (10개)
    - git: 2.43.0 → 2.44.0
    - node: 20.11.0 → 20.12.0
    - python@3.12: 3.12.1 → 3.12.2
    - openssl: 3.1.1 → 3.1.2
    - curl: 8.4.0 → 8.5.0
    - (5개 추가 패키지 업데이트)

    ## Homebrew Casks (3개)
    - visual-studio-code: 1.85.0 → 1.86.0
    - docker: 4.26.1 → 4.27.0
    - firefox: 121.0 → 122.0

    ## Mac App Store (2개)
    - Xcode: 15.1 → 15.2
    - Keynote: 14.0 → 14.1

    ## Python (Pip) (5개)
    - requests: 2.31.0 → 2.32.0
    - flask: 3.0.0 → 3.0.1
    - (3개 추가 패키지 업데이트)

    ## Node.js/NPM
    - Node.js: v24.11.0 → v24.12.0 (nvm via LTS)
    - npm 글로벌: 8개 패키지 업데이트

    ## Rust
    - rustc: 1.91.0 → 1.92.0

    ## Rye
    - Rye: 0.43.0 → 0.44.0

    ## Emacs
    - Doom Emacs: 151개 패키지 최신 상태 유지

    ## Git Repositories (5개)
    - /Users/user/git/Scripts: 업데이트됨
    - /Users/user/git/KISS: 업데이트됨
    - (3개 저장소 추가 업데이트)
    - /Users/user/git/lsr: 스킵 (uncommitted changes)

    ## ⚠️ 경고 및 오류
    - Homebrew: icu4c@77 deprecated (대체 패키지 고려)
    - .NET: 도구 일부 업데이트 실패 [실패]

    ---

    위 예시 형식을 따라서 제공된 로그를 분석하고 보고서를 작성해주세요.
    """

    response = client.models.generate_content(
        model="models/gemini-2.5-flash",
        contents=prompt
    )
    return response.text

from email.mime.multipart import MIMEMultipart
from markdown_it import MarkdownIt

def send_email(subject, body, smtp_config):
    """요약된 내용을 이메일로 전송합니다."""
    
    # Convert markdown to HTML
    md = MarkdownIt()
    html_body = md.render(body)

    # Create a multipart message
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = smtp_config["from"] if smtp_config["from"] else "upsum@example.com"
    msg['To'] = smtp_config["to"]

    # Attach parts
    part1 = MIMEText(body, 'plain', 'utf-8')
    part2 = MIMEText(html_body, 'html', 'utf-8')
    msg.attach(part1)
    msg.attach(part2)

    try:
        port = smtp_config["port"]
        host = smtp_config["host"]
        
        # 포트 선택에 따라 SSL/TLS 구분
        if port == 465:
            # SSL 포트 - SMTP_SSL 사용
            print(f"SMTP SSL 연결 시도: {host}:{port}")
            with smtplib.SMTP_SSL(host, port, timeout=30) as server:
                if smtp_config["user"] and smtp_config["password"]:
                    server.login(smtp_config["user"], smtp_config["password"])
                server.sendmail(msg['From'], [smtp_config["to"]], msg.as_string())
        else:
            # TLS 포트 (587) 또는 일반 포트 - SMTP 사용
            print(f"SMTP 연결 시도: {host}:{port}")
            with smtplib.SMTP(host, port, timeout=30) as server:
                if port == 587:
                    print("STARTTLS 명령 시도...")
                    server.starttls()
                
                if smtp_config["user"] and smtp_config["password"]:
                    print(f"사용자 인증 시도: {smtp_config['user']}")
                    server.login(smtp_config["user"], smtp_config["password"])
                
                print(f"메일 전송 중: {smtp_config['to']}")
                server.sendmail(msg['From'], [smtp_config["to"]], msg.as_string())
                
    except smtplib.SMTPAuthenticationError as e:
        error_msg = f"SMTP 인증 실패: {str(e)}\n사용자 이름과 비밀번호를 확인해주세요."
        print(f"ERROR: {error_msg}")
        raise Exception(error_msg)
    except smtplib.SMTPNotSupportedError as e:
        error_msg = f"SMTP 기능 미지원: {str(e)}\n서버가 TLS/SSL을 지원하지 않을 수 있습니다."
        print(f"ERROR: {error_msg}")
        raise Exception(error_msg)
    except smtplib.SMTPServerDisconnected as e:
        error_msg = f"SMTP 서버 연결 끊김: {str(e)}\n서버 주소와 포트를 확인해주세요."
        print(f"ERROR: {error_msg}")
        raise Exception(error_msg)
    except TimeoutError as e:
        error_msg = f"SMTP 연결 타임아웃: {str(e)}\n서버 주소, 포트, 방화벽을 확인해주세요. Synology MailPlus 사용 시 포트 465(SSL) 또는 587(TLS)을 권장합니다."
        print(f"ERROR: {error_msg}")
        raise Exception(error_msg)
    except smtplib.SMTPException as e:
        error_msg = f"SMTP 오류 발생: {str(e)}\n자세한 오류: {e.smtp_error.decode('utf-8') if hasattr(e, 'smtp_error') else '알 수 없는 오류'}"
        print(f"ERROR: {error_msg}")
        raise Exception(error_msg)
    except Exception as e:
        error_msg = f"이메일 전송 중 오류 발생: {type(e).__name__}: {str(e)}\n\n[디버깅 정보]\n- 호스트: {smtp_config['host']}\n- 포트: {smtp_config['port']}\n- 수신자: {smtp_config['to']}"
        print(f"ERROR: {error_msg}")
        raise Exception(error_msg)

def main():
    """메인 실행 함수"""
    load_dotenv()

    parser = argparse.ArgumentParser(description="Summarize macOS system update logs and send an email.")
    parser.add_argument("--log-dir", default="/private/tmp", help="Directory where log files are stored (default: /private/tmp for macOS update_all.zsh logs).")
    parser.add_argument("--dry-run", action="store_true", help="Print summary to console instead of sending email.")
    parser.add_argument("--log-file", help="Specific log file to process, bypassing log directory search.")
    args = parser.parse_args()

    try:
        # 환경 변수 로드
        gemini_api_key = os.getenv("GEMINI_API_KEY")
        smtp_config = {
            "host": os.getenv("SMTP_HOST"),
            "port": int(os.getenv("SMTP_PORT", 587)),
            "user": os.getenv("SMTP_USER", ""), # 기본값 빈 문자열
            "password": os.getenv("SMTP_PASSWORD", ""), # 기본값 빈 문자열
            "from": os.getenv("MAIL_FROM", ""), # 기본값 빈 문자열
            "to": os.getenv("MAIL_TO"),
        }

        if not gemini_api_key:
            print("Error: GEMINI_API_KEY is not set.")
            print("Please create a .env file based on .env.example and fill in the values.")
            return

        # SMTP_HOST와 MAIL_TO는 필수
        if not smtp_config["host"] or not smtp_config["to"]:
            print("Error: Required environment variables (SMTP_HOST, MAIL_TO) are not set.")
            print("Please create a .env file based on .env.example and fill in the values.")
            return

        # 1. 로그 파일 결정 (지정된 파일 또는 최신 파일 검색)
        target_log_file = None
        if args.log_file:
            target_log_file = Path(args.log_file).expanduser()
            if not target_log_file.exists():
                print(f"Error: Specified log file not found: {target_log_file}")
                return
        else:
            target_log_file = find_latest_log_file(args.log_dir)
            if not target_log_file:
                print(f"No log files found in {args.log_dir}. Nothing to do.")
                return
        
        print(f"Processing log file: {target_log_file}")

        # 2. 로그 파일 파싱
        parsed_data = parse_log_file(target_log_file)

        # 3. Gemini로 요약 생성
        summary = generate_summary_with_gemini(gemini_api_key, parsed_data)
        
        subject = f"{__formatted_date__} 시스템 업데이트 요약"

        print("--- Generated Summary ---")
        print(summary)
        print("-------------------------")

        # 4. 이메일 전송 또는 드라이런 출력
        if args.dry_run:
            print("Dry run enabled. No email will be sent.")
        else:
            print(f"Sending email summary to {smtp_config['to']}...")
            send_email(subject, summary, smtp_config)
            print("Email sent successfully.")

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    main()
