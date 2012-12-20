import database
import sys

database.set_database('server.database', sys.stdin.read())
