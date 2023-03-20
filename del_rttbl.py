#!/usr/bin/env python3

import os
import subprocess

ck001 = "172.30.1."
ck002 = "via"
ck003 = "10.211."
ck004 = "dev"
ck005 = "utun"

print(f"FIND RULE : '{ck001}*' '{ck002}' '{ck003}*' '{ck004}' '{ck005}'")

p = subprocess.Popen("ip route",
                     stdout=subprocess.PIPE,
                     stderr=subprocess.PIPE,
                     shell=True)
(output, err) = p.communicate()
outstr = str(output, 'utf-8')
if False:
    outstr = """
default via link#16 dev utun2
default via 172.30.1.254 dev en0
1.0.0.0/8 via 10.211.96.241 dev utun2
2.0.0.0/7 via 10.211.96.241 dev utun2
4.0.0.0/6 via 10.211.96.241 dev utun2
8.0.0.0/5 via 10.211.96.241 dev utun2
10.40.29.172/32 via 10.211.96.241 dev utun2
10.40.29.173/32 via 10.211.96.241 dev utun2
10.211.96.241/32 via 10.211.96.241 dev utun2
16.0.0.0/4 via 10.211.96.241 dev utun2
32.0.0.0/3 via 10.211.96.241 dev utun2
64.0.0.0/2 via 10.211.96.241 dev utun2
127.0.0.0/8 via 127.0.0.1 dev lo0
127.0.0.1/32 via 127.0.0.1 dev lo0
128.0.0.0/1 via 10.211.96.241 dev utun2
169.254.0.0/16 dev en0  scope link
172.30.1.0/27 via 10.211.96.241 dev utun2
172.30.1.0/24 dev en0  scope link
172.30.1.32/28 via 10.211.96.241 dev utun2
172.30.1.48/29 via 10.211.96.241 dev utun2
172.30.1.56/31 via 10.211.96.241 dev utun2
172.30.1.58/32 dev en0  scope link
172.30.1.59/32 via 10.211.96.241 dev utun2
172.30.1.60/30 via 10.211.96.241 dev utun2
172.30.1.64/26 via 10.211.96.241 dev utun2
172.30.1.128/26 via 10.211.96.241 dev utun2
172.30.1.192/27 via 10.211.96.241 dev utun2
172.30.1.224/28 via 10.211.96.241 dev utun2
172.30.1.240/29 via 10.211.96.241 dev utun2
172.30.1.248/30 via 10.211.96.241 dev utun2
172.30.1.252/31 via 10.211.96.241 dev utun2
172.30.1.254/32 dev en0  scope link
172.30.1.255/32 via 10.211.96.241 dev utun2
210.211.86.53/32 via 172.30.1.254 dev en0
224.0.0.0/4 dev utun2  scope link
224.0.0.0/4 dev en0  scope link
255.255.255.255/32 dev utun2  scope link
255.255.255.255/32 dev en0  scope link
"""

for line in outstr.split('\n'):
    t = line.split()
    # print(t[0][:9])
    if len(t) == 5 \
       and t[0][:len(ck001)] == ck001 \
       and t[1][:len(ck002)] == ck002 \
       and t[2][:len(ck003)] == ck003 \
       and t[3][:len(ck004)] == ck004 \
       and t[4][:len(ck005)] == ck005:
        cmd = f"sudo route -n delete {t[0]}"
        print(f"EXECUTE : {cmd}")
        os.system(cmd)
