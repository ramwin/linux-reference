#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Xiang Wang @ ramwin@qq.com 2016-04-15 09:12:56

import uuid
file = open('bigtext.csv','w')
text = '\n'.join(
        map(
            lambda x: '"%d","%s","%s"'%(x,uuid.uuid1(x).hex[0:10], uuid.uuid1(x).hex[-8:]),
            range(10000,100000)
        )
    )
file.write(text)
file.close()
