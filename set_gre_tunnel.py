#!/usr/bin/python

import copy
import paramiko
import re
import socket
import sys


def exec_command(ssh, cmd):
    print("cmd: %s" % cmd)
    _, stdout, stderr = ssh.exec_command(cmd)
    ret_code = stdout.channel.recv_exit_status()
    errs = stderr.readlines()
    if errs and errs[0]:
        err = errs[0].strip('\n')
        print("err: %s" % err)

    outs = stdout.readlines()
    out = ""
    if outs and outs[0]:
        out = outs[0].strip('\n')
        print("out: %s" % out)

    print("ret_code: %d"%ret_code)

    if ret_code > 0:
        raise paramiko.ssh_exception.SSHException('Error running %s: Ret code %d'%(cmd, ret_code))

    if len(out) > 0:
        return out

    return


def delete_gre_connection(ssh, gre_net):
    # Only delete the scripts, the network may be in use by VMs and therefore can't be deleted
    try:
        print("==============================================================")
        print("delete gre connection\n")
        # delete existing gre rules and scripts under udev
        exec_command(ssh, "rm -f /etc/udev/rules.d/90-gre-tunnel.rules")
        exec_command(ssh, "rm -f /etc/udev/scripts/create-gre-tunnels.sh")
    except Exception as e:
        print("Delete gre connection error, %s" % e)


def create_ssh_connection(username, password, ip):
    print("==============================================================")
    print("create ssh connection %s\n" % ip)
    # start ssh connection
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ssh.connect(ip, 22, username, password, timeout=60)
    return ssh


def create_udev_rules(ssh):
    print("==============================================================")
    print("set udev rules\n")
    exec_command(ssh,
        "echo 'SUBSYSTEM==\"net\" ACTION==\"add\" KERNEL==\"xapi*\" "
        "RUN+=\"/etc/udev/scripts/create-gre-tunnels.sh\"\'"
        "> /etc/udev/rules.d/90-gre-tunnel.rules")


def create_udev_script(ssh, local_ip, remote_ips, gre_net):
    print("==============================================================")
    print("create udev script")
    exec_command(ssh,
        "bridge=$(xe network-list name-label=%s params=bridge minimal=true)\n"
        "cat > /etc/udev/scripts/create-gre-tunnels.sh << CREATE_GRE_EOF\n"
        "#!/bin/bash\n"
        "sleep 5\n"
        "if /sbin/ip link show $bridge > /dev/null 2>&1; then\n"
        "if ! /sbin/ip addr show $bridge|grep \"inet %s\" > /dev/null 2>&1; then\n"
        "/sbin/ip addr add %s/255.255.255.0 dev $bridge\n"
        "for ip in %s;\n"
        "do\n"
        "ovs-vsctl add-port $bridge port\$ip -- set interface port\$ip type=gre options:remote_ip=\$ip\n"
        "done\n"
        "ovs-vsctl set bridge $bridge stp_enable=true\n"
        "fi\n"
        "fi\n"
        "CREATE_GRE_EOF\n"
        "chmod +x /etc/udev/scripts/create-gre-tunnels.sh" % (gre_net, local_ip, local_ip, remote_ips))
    # Activate the GRE tunnel if the networks exist
    exec_command(ssh, "/etc/udev/scripts/create-gre-tunnels.sh")


def create_gre_network(ssh, gre_net):
    print("==============================================================")
    print("create gre network")
    matching_networks = exec_command(ssh, "xe network-list name-label=%s minimal=true" % gre_net)
    if len(matching_networks) > 0:
        print("Not attempting to create GRE network; it already exists (delete failed?)")
        return
    exec_command(ssh, "xe network-create name-label=%s" % gre_net)


def validate_ips(ip_list):
    pattern = re.compile(r'(?<![\.\d])(?:\d{1,3}\.){3}\d{1,3}(?![\.\d])')
    final_ip_list = []
    for ip in ip_list:
        try:
            host_ip = socket.gethostbyname(ip)
        except Exception as e:
            print("Error:\n\tHostname %s is invalid" % ip)
            return False, final_ip_list
        if not pattern.match(host_ip):
            print("Error:\n\t Ip or hostname %s is invalid" % ip)
            return False, final_ip_list
        else:
            final_ip_list.append(host_ip)
    return True, final_ip_list


if __name__=='__main__':
    if len(sys.argv) < 5:
        print("Error: \n\tNo enough information given!\nUsage:")
        print("\tpython set_gre_tunnel.py root_passwd gre_net_name ip1 ip2 ip3 ...\n")
        exit()

    password = sys.argv[1]
    gre_net = sys.argv[2] 
    all_ips = sys.argv[3:]
    gre_ip_pre = "192.168.100.%s"
    gre_ip_start = 10
    print("==============================================================")
    print("Information:")
    print("\tRoot password: %s" % password)
    print("\tGRE network name: %s" % gre_net)
    print("\tIP list: %s" % all_ips)
    result, ip_list = validate_ips(all_ips)
    if not result:
        exit()
    print("\tIp list: %s" % ip_list)
    print("==============================================================")
    reboot_hosts = []
    for ip in ip_list:
        remote_ip_list = copy.deepcopy(ip_list)
        remote_ip_list.remove(ip)
        remote_ips = ""
        for temp_ip in remote_ip_list:
            remote_ips = temp_ip + " " + remote_ips
        ssh = create_ssh_connection("root", password, ip)
        scripts_exist = exec_command(ssh, "[ ! -e /etc/udev/rules.d/90-gre-tunnel.rules ] || echo 'found'") == 'found'
        if scripts_exist:
            delete_gre_connection(ssh, gre_net)
            reboot_hosts.append(ip)
        create_gre_network(ssh, gre_net)
        create_udev_rules(ssh)
        gre_ip_start += 1
        gre_ip = gre_ip_pre % gre_ip_start
        create_udev_script(ssh, gre_ip, remote_ips, gre_net)
        # close ssh connection
        ssh.close()
    print("==============================================================")
    if len(reboot_hosts) > 0:
        print("\tFollowing hosts had old GRE tunnels and may need rebooting: %s" % reboot_hosts)
    else:
        print("\tAdded GRE tunnel to all hosts.  Tried to activate, but if things don't work, try rebooting them")

