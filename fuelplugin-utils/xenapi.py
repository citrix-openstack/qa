#!/usr/bin/env python

import argparse
import XenAPI

if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='ipython -i xenapi.py host password')
    parser.add_argument('host')
    parser.add_argument('password')
    args = parser.parse_args()
    session = XenAPI.Session('https://' + args.host)
    session.xenapi.login_with_password('root', args.password)
