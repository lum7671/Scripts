#!/usr/bin/env python
# 
# https://stackoverflow.com/questions/4770297/convert-utc-datetime-string-to-local-datetime-with-python#4771733
# 

from datetime import datetime
from dateutil import tz
import sys

def usage():
    print("Usage:\n% {} 2011-01-21\ 02:37:21".format(sys.argv[0]))

if len(sys.argv) != 2:
    usage()
    exit(0)

# METHOD 1: Hardcode zones:
# from_zone = tz.gettz('UTC')
# to_zone = tz.gettz('Asia/Seoul') # KST

# METHOD 2: Auto-detect zones:
from_zone = tz.tzutc()
to_zone = tz.tzlocal()

# utc = datetime.utcnow()
utc = sys.argv[1]
utc = utc[:10] + ' ' + utc[11:] # support '2011-01-21T02:37:21' format
utc = datetime.strptime(utc, '%Y-%m-%d %H:%M:%S')

# Tell the datetime object that it's in UTC time zone since 
# datetime objects are 'naive' by default
utc = utc.replace(tzinfo=from_zone)

# Convert time zone
kst = utc.astimezone(to_zone)
print(kst)
