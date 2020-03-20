#!/usr/bin/env python
# -*- coding: utf-8 -*-

"""
:description:   MySQL의 sid, gid 를 체크해서 user_hist task를 재시작 한다. ( daemon )
:authors:       장두현<nate.jang@sk.com>
"""
from __future__ import print_function

import argparse
import logging.config
import os
import signal
import time
from logging import handlers, Formatter
from pathlib import Path
from subprocess import Popen
from subprocess import call

import daemon
import pymysql
from daemon.pidfile import PIDLockFile
from send2slack import send_slack

# Error Retry 간격
retrySec = 30  # 30초

# Error Retry 횟수
errCnt = 0

# sid, gid 비교 간격
checkTime = 10 * 60  # 10분

# log backup 일수
daysBackup = 30

# debug
# retrySec = 10  # 10초
# checkTime = 10  # 10초

# mysqlServerUrl="aurora-re.recopick.com" # real
mysqlServerUrl="proxy.recopick.com"     # local


def get_sid_gid_sid_from_mysql():
    """
    MySQL recopick.SERVICE 와
    recopick.SERVICE_PRODUCT 테이블에서 service_id, group_id 데이터를
    반환 한다.
    :return:
    """

    hash_sidgid = 0
    hash_sid = 0

    # MySQL Connection 연결
    with pymysql.connect(host='aurora-re.recopick.com', user='ubuntu', password='reco7788!#%',
                         db='recopick', charset='utf8') as curs:

        # Connection 으로부터 Cursor 생성
        # curs = conn.cursor()

        # SQL 문 실행
        sql = "SELECT service_id, group_id FROM SERVICE WHERE ignore_logs=0 ORDER BY service_id;"
        curs.execute(sql)

        # 데이타 Fetch
        rows01 = curs.fetchall()
        if len(rows01) > 0:
            hash_sidgid = hash(rows01)

        sql = "SELECT service_id FROM SERVICE_PRODUCT WHERE type='user' and enabled=1 ORDER BY service_id;"
        curs.execute(sql)

        # 데이타 Fetch
        rows02 = curs.fetchall()
        if len(rows02) > 0:
            hash_sid = hash(rows02)
    return rows01, rows02, "{0},{1}".format(hash_sidgid, hash_sid)


def get_sid_gid_sid_from_chkfile(args_):
    """
    MySQL recopick.SERVICE 와
    recopick.SERVICE_PRODUCT 테이블에서 service_id, group_id 데이터를
    반환 한다.
    :return:
    """

    line = "0,0"
    file01 = Path(args_.chk_file)
    if file01.exists():
        with open(args_.chk_file, 'r') as f:
            line = f.readline()
    return line.strip()


def save_sid_gid_sid_to_chkfile(args_, hash_result_):
    """
    MySQL과 값 비교를 위해서
    /tmp 디렉토리에 파일로 값을 저장한다.
    :param args_:
    :param hash_result_:
    :return:
    """

    b_rtn = False
    if hash_result_ != "0,0":
        with open(args_.chk_file, 'w') as f:
            f.write(hash_result_)
            f.flush()
            args_.logger.info("Saved(%s) : %s" % (args_.chk_file, hash_result_))
            b_rtn = True
    return b_rtn


def restart_user_hist(args_):
    """
    sid, gid에 변화가 있으면 user_hist 를 재시작을 한다.
    :param args_:
    :return:
    """

    args_.logger.info("Restart user_hist task!!!")
    with open(args.log_file, 'a') as f:
        args_.logger.info("Stop : user_hist")
        call(["/home/hadoop/flink/bin/run_flink.sh", "stop", "user_hist", "prod"], stdout=f, stderr=f)
        time.sleep(10)
        args_.logger.info("Kill : user_hist")
        call(["/home/hadoop/flink/bin/run_flink.sh", "kill", "user_hist", "prod"], stdout=f, stderr=f)
        time.sleep(10)
        args_.logger.info("Start : user_hist")
        Popen(["/home/hadoop/flink/bin/run_flink.sh", "start", "user_hist", "prod"], stdout=f, stderr=f)
        f.flush()
        time.sleep(10)
    args_.logger.info("Finished!!! (Restart user_hist)")


def add_errcount(args_, errstr):
    """
    에러 횟수가 많아지면 slack 으로 알림을 준다.
    :param args_:
    :param errstr:
    :return:
    """

    global errCnt
    errCnt += 1
    args_.logger.error(errstr)
    if errCnt == 10:
        errCnt = 0
        send_slack(errstr)


def check_sid_gid(args_):
    """
    데몬 실행
    :return:
    """
    args_.logger.info("=== DAEMON #2 ===")
    while True:
        (rows01, rows02, hash_result) = get_sid_gid_sid_from_mysql()
        if hash_result != "0,0":
            read_line = get_sid_gid_sid_from_chkfile(args_)
            if hash_result == read_line:
                args_.logger.info("[CHECK POINT] same same same same!!!")
            else:
                args_.logger.info("[CHECK POINT] updated updated updated updated!!!\n"
                                  "MySQL_ROWS : {0} <==> ChkFile : {1}\n"
                                  "[ORIGIN] #2 SERVICE: {2}\n"
                                  "[ORIGIN] #2 SERVICE_PRODUCT: {3}\n".format(hash_result, read_line, rows01, rows02))

                while True:
                    # save different data
                    if save_sid_gid_sid_to_chkfile(args_, hash_result):
                        break
                    add_errcount(args_, "MySQL #3, ERROR: CANNOT SAVE TO CHECK FILE!!!\n"
                                        "RESULT: {0}\n"
                                        "[ORIGIN] #4 SERVICE: {1}\n"
                                        "[ORIGIN] #4 SERVICE_PRODUCT: {2}\n".format(hash_result, rows01, rows02))
                    time.sleep(retrySec)

                # Restart user_hist task
                restart_user_hist(args_)
        else:
            add_errcount(args_, "MySQL #2, ERROR: RESPONSE DATA, RESULT: {0}".format(hash_result))
        time.sleep(checkTime)


def f_start(args_):
    args_.logger.info("{0}: STARTING...".format(args_.daemon_name))
    args_.logger.info("{0}: PID_FILE = {1}".format(args_.daemon_name, args_.pid_file))
    args_.logger.info("{0}: LOG_FILE = {1}".format(args_.daemon_name, args_.log_file))
    args_.logger.info("{0}: TMP_FILE = {1}".format(args_.daemon_name, args_.chk_file))

    plf = PIDLockFile(args_.pid_file)
    pid = plf.is_locked()
    if pid:
        args_.logger.warning("{0}: Running already (pid: {1})".format(args_.daemon_name, pid))
        return

    # 초기 설정
    my_file = Path(args_.chk_file)
    if my_file.exists():
        os.remove(args_.chk_file)

    global errCnt
    errCnt = 0
    while True:
        (rows01, rows02, hash_result) = get_sid_gid_sid_from_mysql()
        args_.logger.info("MySQL_ROWS : {0}\n"
                          "[ORIGIN] #1 SERVICE: {1}\n"
                          "[ORIGIN] #1 SERVICE_PRODUCT: {2}\n".format(hash_result, rows01, rows02))
        if save_sid_gid_sid_to_chkfile(args_, hash_result):
            # user_hist task 를 재시작 한다.
            restart_user_hist(args_)
            break  # save 되면
        add_errcount(args_, "MySQL #1, ERROR: CANNOT SAVE TO CHECK FILE!!!\n"
                            "RESULT: {0}\n"
                            "[ORIGIN] #3 SERVICE: {1}\n"
                            "[ORIGIN] #3 SERVICE_PRODUCT: {2}\n".format(hash_result, rows01, rows02))
    time.sleep(retrySec)

    files = []
    for handle in args_.logger.handlers:
        if isinstance(handle, handlers.TimedRotatingFileHandler):
            args_.logger.info("LOG FILE PATH : %s" % handle.baseFilename)
        files.append(handle.stream.fileno())

    with daemon.DaemonContext(
            working_directory=args_.working_directory,
            files_preserve=files,
            umask=0o002,
            pidfile=PIDLockFile(args_.pid_file, timeout=2.0),
            stdout=open(args_.stdout_file, "a"),
            stderr=open(args_.stderr_file, "a")):

        # 재시작 후 체크시간 지연
        time.sleep(checkTime)
        check_sid_gid(args_)


def f_stop(args_):
    plf = PIDLockFile(args_.pid_file)
    if plf.is_locked():
        pid = plf.read_pid()
        if pid != 0:
            args_.logger.info("{0}: Stopping... pid({1})".format(args_.daemon_name, pid))
            os.kill(pid, signal.SIGTERM)
    else:
        args_.logger.error("{0}: NOT running".format(args_.daemon_name))


def f_restart(args_):
    f_stop(args_)
    f_start(args_)


def f_status(args_):
    plf = PIDLockFile(args_.pid_file)
    if plf.is_locked():
        args_.logger.info("{0}: running, PID = {1}".format(args_.daemon_name, plf.read_pid()))
    else:
        args_.logger.info("{0}: NOT running".format(args_.daemon_name))


if __name__ == "__main__":

    # run_daemon()
    here = os.path.abspath(os.path.dirname(__file__))
    base_name = os.path.basename(__file__).split('.')[0]

    # To avoid dealing with permissions and to simplify this example
    # setting working directory, pid file and log file location etc.
    # to the directory where the script is located. Normally these files
    # go to various subdirectories of /var

    # working directory, normally /var/lib/<daemon_name>
    working_directory = here

    # log file, normally /var/log/<daemon_name>.log
    log_path = "%s/log/" % here
    if not os.path.isdir(log_path) and not os.path.exists(log_path):
        os.mkdir(log_path)
    log_file = os.path.join(log_path, "{0}.log".format(base_name))

    # pid lock file, normally /var/run/<daemon_name>.pid
    pid_path = "%s/run/" % here
    if not os.path.isdir(pid_path) and not os.path.exists(pid_path):
        os.mkdir(pid_path)
    pid_file = os.path.join(pid_path, "{0}.pid".format(base_name))

    # stdout, normally /var/log/<daemon_name>.stdout
    stdout_file = os.path.join(log_path, "{0}.stdout".format(base_name))

    # stderr, normally /var/log/<daemon_name>.stderr
    stderr_file = os.path.join(log_path, "{0}.stderr".format(base_name))

    tmp_path = "%s/tmp/" % here
    if not os.path.isdir(tmp_path) and not os.path.exists(tmp_path):
        os.mkdir(tmp_path)
    chk_file = os.path.join(tmp_path, "{0}.chk".format(base_name))

    parser = argparse.ArgumentParser(
        description="Minimalistic example of using python-daemon with pidlockfile"
    )
    parser.add_argument(
        "-v", "--verbose",
        help="print additional messages to stdout",
        action="store_true"
    )
    parser.set_defaults(working_directory=working_directory)
    parser.set_defaults(log_file=log_file)
    parser.set_defaults(pid_file=pid_file)
    parser.set_defaults(stdout_file=stdout_file)
    parser.set_defaults(stderr_file=stderr_file)
    parser.set_defaults(chk_file=chk_file)
    parser.set_defaults(daemon_name=base_name)
    subparsers = parser.add_subparsers(title="commands")
    sp_start = subparsers.add_parser("start", description="start daemon")
    sp_start.set_defaults(func=f_start)
    sp_stop = subparsers.add_parser("stop", description="stop daemon")
    sp_stop.set_defaults(func=f_stop)
    sp_restart = subparsers.add_parser("restart", description="restart daemon")
    sp_restart.set_defaults(func=f_restart)
    sp_status = subparsers.add_parser("status", description="check daemon status")
    sp_status.set_defaults(func=f_status)
    args = parser.parse_args()

    logging.config.fileConfig('check_sidgid_logging.ini')
    logger = logging.getLogger("root")
    if args.verbose:
        logger = logging.getLogger("all")
    handler = handlers.TimedRotatingFileHandler(log_file, when="d", interval=1, backupCount=daysBackup)
    format = '%(asctime)s [%(levelname)s] %(message)s'
    formatter = Formatter(format)
    handler.setFormatter(formatter)
    logger.addHandler(handler)

    args.logger = logger
    args.func(args)
