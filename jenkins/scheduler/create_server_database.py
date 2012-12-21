#!/usr/bin/env python

import database
import sys

database.set_database('server.database', sys.stdin.read())
