#!/usr/bin/env python

import database
import sys

lock, = sys.argv[1:]

database.release_lock('server.database', lock)
