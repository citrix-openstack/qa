#!/usr/bin/env python

import argparse
import httplib
import traceback
import sys
import os
import XenAPI
import time
import socket


def add_himn(session, vm_name, device):
    try:
        VM = session.xenapi.VM
        network = session.xenapi.network
        VIF = session.xenapi.VIF

        _vms = VM.get_all()
        _vms = [_vm for _vm in _vms
                if VM.get_record(_vm).get('name_label') == vm_name]
        if len(_vms) < 1:
            print('%s cannot be found' % vm_name)
        elif len(_vms) > 1:
            print('More than one vm is named %s, '
                  'please change it to be unique' % vm_name)

        _vm = _vms[0]
        vm = VM.get_record(_vm)
        if vm.get('power_state') != 'Halted':
            print('HIMN must be created when VM is powered off. '
                  'Please shut down VM (%s) first then retry.' % vm_name)

        _nets = network.get_all()
        _nets = [_net for _net in _nets
                 if network.get_record(_net).get('bridge') == 'xenapi']
        if len(_nets) < 1:
            print('bridge xenapi cannot be found')
        _net = _nets[0]

        _vifs = VIF.get_all()
        _vifs = [_vif for _vif in _vifs
                 if VIF.get_record(_vif).get('VM') == _vm
                 and VIF.get_record(_vif).get('network') == _net]
        if len(_vifs) > 0:
            print('HIMN plugged to %s already exists' % vm_name)
        else:
            _vif = VIF.create({
                'VM': _vm,
                'network': _net,
                'device': device,
                'MAC': "",
                'MTU': "1500",
                "qos_algorithm_type": "",
                "qos_algorithm_params": {},
                "other_config": {}})
            if _vif:
                print('HIMN has been successfully added to %s' % vm_name)
            else:
                print('HIMN failed to be added to %s' % vm_name)
    except Exception, e:
        traceback.print_exc()


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        prog='./add_himn.py',
        description='To add management network to VM')
    parser.add_argument('host',
                        help='host name or IP address of XenServer')
    parser.add_argument('password', help='password of root')
    parser.add_argument('vm', help='name of target VM')
    args = parser.parse_args()
    try:
        socket.gethostbyname(args.host)
    except:
        print('host is inaccessible')
        exit(1)
    print('Connecting to %s ...' % args.host)
    try:
        session = XenAPI.Session('https://' + args.host)
        session.xenapi.login_with_password('root', args.password)
    except:
        print('password is incorrect')
        exit(1)
    add_himn(session, args.vm, '9')
