#!/usr/bin/expect -f
#===================================================
# PCS 로그인 스크립트.
# 도움말 : ./pcs-login
# 아래 환경 변수들 설정하셔요.
#===================================================
set PCS_ID "1001028"
set PCS_PW "kX2#xhy\["

set VPN_ID $PCS_ID
set VPN_PW "hP9g\[JCu,o"

proc get_host { arg } {  # HOST 와 IP 를 적당히 설정
  switch $arg {
    "web" { return "172.21.42.181" } \
    "db" { return "172.22.42.182" } \
    default { return $arg }
  }
}
#===================================================

set VPN_IP "10.40.30.215"
set VPN_PORT 20022

#set timeout 30

proc connect {vpn_id vpn_pw pcs_ip} {
  #expect "Login:"
  #send -- "$vpn_id\r"
  expect "password:"
  send -- "$vpn_pw\r"
  expect "Input Device"
  send -- "i\r"
  expect "Input ipaddress"
  send -- "$pcs_ip\r"
  expect "Input Service"
  return 1
}


proc login { pcs_id pcs_pw } {
	set PICKAT2_ID "pickat2"
	set PICKAT2_PW "vlzotadmin3#"
	expect "Login:"
	send -- "$pcs_id\r"
	expect "Password:"
	send -- "$pcs_pw\r"
	expect "$"
	send -- "su - $PICKAT2_ID\r"
	expect "암호:"
	send -- "$PICKAT2_PW\r"
	return 1
}


proc help {} {
  puts "텔넷접속 : ./pcs-login \[HOST\]"
  puts "FTP 접속 :"
  puts "  1) proxy 실행: ./pcs-login sftpd \[HOST\]"
  puts "  2) sftp 실행 : ./pcs-login sftp"
  puts "FTP 업로드 :"
  puts "  1) proxy 실행: ./pcs-login sftpd \[HOST\]"
  puts "  2) sftp 실행 : ./pcs-login sftp \[FILE_TO_UPLOAD\]"
  puts "** 파일내 PCS_ID,PCS_PW,VPN_ID,VPN_PW, get_host 설정 필수"
  puts "** HOST : get-host 에 지정된 키. 예) dr-web"
}

set cmd [lrange $argv 0 0]
set arg1 [lrange $argv 1 1]
if { [llength $argv] == 0 } { # help.
  help; exit 1
} elseif { $cmd == "sftpd" } { # sftp proxy
  spawn ssh $VPN_ID@$VPN_IP -p $VPN_PORT
  connect $VPN_ID $VPN_PW [ get_host $arg1 ]
  send -- "sf\r"
  login $PCS_ID $PCS_PW
} elseif { $cmd == "sftp" } { # sftp client
  # spawn sftp -P 10121 $VPN_ID@$VPN_IP
	spawn sftp -P 20022 $VPN_ID@$VPN_IP
  expect "password:"
  send -- "$VPN_PW\r"
  if { [llength $argv] > 1 } { # file upload
    expect "sftp>"
    send -- "put $arg1\r"
  }
} else {  # ssh
  spawn ssh $VPN_ID@$VPN_IP -p $VPN_PORT
  connect $VPN_ID $VPN_PW [ get_host $cmd ]
  send -- "s\r"
  login $PCS_ID $PCS_PW
}

interact
