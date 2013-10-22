#! /usr/bin/env python
# -*- coding: utf-8 -*-

import os.path
import commands
import sys
import string

# print commands.getoutput("ls")

images=[]  # pathfile, file, filename, used count, [[file, linenumber], ...] 
sources=[] # file

def chkdir(_dir):
    global images
    global sources
    
    for a_dir in os.listdir(_dir):
        a_file=os.path.join(_dir, a_dir)
        if os.path.isdir(a_file):
            # print "[dir]", a_file
            if a_dir=="build":
                continue
            chkdir(a_file)
        if os.path.isfile(a_file):
            s=os.path.splitext(a_file)
            # print "[1]", s
            if s[1]==".m" or s[1]==".h":
                # print "[.m or .h file]", a_file
                sources.append(a_file)
            if s[1]==".png" or s[1]==".gif":
                ss=os.path.split(a_file)
                sss=os.path.splitext(ss[1])
                # print "[2]", ss
                # ss=os.path.base
                # print "[image files]", a_file
                sv1="@\""+ss[1]+"\""
                sv2="@\""+sss[0]+"\""
                images.append([a_file, sv1, sv2, 0, []])



# chkdir(os.getcwd())
chkdir(sys.argv[1])
# chkdir("/Users/x/Works/NateFlag/")


for x in sources:
    fc=0
    f=open(x)
    ln=0
    for line in f:
        ln=ln+1
        for m in images:
            if string.find(line, m[1])!=-1 or string.find(line, m[2])!=-1:
                m[3]=m[3]+1
                m[4].append([x, ln])
    f.close()
    # print "[SOURCE] ", x

# exit(0)

from stat import *

images.sort(key=lambda item:item[3])
# images.sort(lambda x,y:x[3]>y[3])
tb=0
for x in images:
    if x[3]==0:
        tb=tb+os.stat(x[0])[ST_SIZE]
        # print os.stat(x[0])[ST_SIZE], " bytes"
    print '[+] {0:80}\tfound count : {1}'.format(x[0], x[3])
    for l in x[4]:
        print "\t=> {0:80}\t{1:5d} line".format(l[0], l[1])

print "\n"
print "=================================================="
print "  You can be save disk about {0} bytes.".format(tb)
print "=================================================="
