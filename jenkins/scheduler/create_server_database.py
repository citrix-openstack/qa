#!/usr/bin/env python

import database
import sys

servers_dot_py, = sys.argv[1:]

with open(servers_dot_py, 'rb') as f:
    database.set_database('server.database', f.read())
