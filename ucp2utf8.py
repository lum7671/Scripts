#!/usr/bin/env python2
#-*- coding: utf-8 -*-
import sys
reload(sys)
sys.setdefaultencoding('utf-8')

if len(sys.argv) > 1:
    foo = sys.argv[1].lower()
    print(foo.decode('unicode_escape').encode('utf-8'))
    exit(1)
#print("Usage:\n" + sys.argv[0] + "'\Uc11c\Ubc84\Uc5d0 \Ubb38\Uc81c\Uac00 \Ubc1c\Uc0dd\Ud588\Uc2b5\Ub2c8\Ub2e4.'")
exit(1)

foo = '\Uc11c\Ubc84\Uc5d0 \Ubb38\Uc81c\Uac00 \Ubc1c\Uc0dd\Ud588\Uc2b5\Ub2c8\Ub2e4.'
print(foo)
# foo = foo.decode('raw_unicode_escape')

foo = foo.lower() # replace('\U', '\u')
print(foo)

foo = foo.decode('unicode_escape')
print(type(foo))

foo = foo.encode('utf-8')
print(type(foo))
print(foo)

