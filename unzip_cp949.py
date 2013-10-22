#! /usr/bin/env python
# -*- coding: utf-8 -*-

import sys, os, zipfile

def unzip(file, dir):
	if dir is not None:
		os.mkdir(dir)

	zfobj = zipfile.ZipFile(file)
	for info in zfobj.infolist():
		info.filename =  info.filename.decode('cp949').encode('utf-8')
		zfobj.extract(info, dir)

		print(info.filename)

if __name__ == '__main__':
	argc = len(sys.argv)

	if argc == 1:
		print('Usage: {0} file [exdir]'.format(sys.argv[0]))
	elif argc == 2:
		unzip(sys.argv[1], None)
	elif argc == 3:
		unzip(sys.argv[1], sys.argv[2])
