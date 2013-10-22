#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# author : Doo-Hyun Jang <ring0320@skcomms.co.kr>
#
# Description :
# This script make "UTF8" sub directory for UTF-8 encoding.
# It is only changing name with UTF-8, contents is not changing.
#

import os
import os.path
import commands
import sys
import string
import shutil
import errno

current_path=os.getcwd()
utf8_path=""
copy_path="UTF8"
cvs_path="CVS"

# TODO : 현재 스크립트명
# self_file=sys.argv[0]
# print "XXXXXX" + self_file
self_file="utf8.py"

def dirlist(_dir):
	global utf8_path
	global copy_path
	global cvs_path
	global self_file

	try:
		_dir.decode('EUC-KR')
	except UnicodeDecodeError:
		root_utf8=_dir
	else:
		root_utf8=_dir.decode('EUC-KR').encode('UTF-8')
	for a_dir in os.listdir(_dir):
		# TODO : 예외를 배열로 처리할 수 있음.
		if a_dir == cvs_path:
			continue
		if a_dir == copy_path:
			continue
		if a_dir == self_file:
			continue

		try:
			a_dir.decode('EUC-KR')
		except UnicodeDecodeError:
			a_utf8=a_dir
		else:
			a_utf8=a_dir.decode('EUC-KR').encode('UTF-8')
			
			
		src_file=os.path.join(_dir, a_dir)
		utf8_path=os.path.join(root_utf8, a_utf8)
		if os.path.isdir(src_file) :
			print "DIR : " + utf8_path
			try:
				os.makedirs(string.replace(utf8_path,"/doc/", "/doc/UTF8/"))
			except OSError as exc:
				if exc.errno == errno.EEXIST:
					pass
				else:
					raise
			dirlist(src_file)
		else:
			# TODO : 문서파일이면 으로 한정.
                        #if os.path.isfile(a_dir) :
                        #	print "FILE : " + a_utf8
			dest_file="%s/%s" % (string.replace(root_utf8,"/doc/", "/doc/UTF8/"), a_utf8)
			if os.path.isfile(src_file):
				print "COPY FILE : %s" % (dest_file)
				shutil.copy(src_file, dest_file)
			else:
				print ">>> SKIP FILE : %s" % (dest_file)

dirlist(current_path)
