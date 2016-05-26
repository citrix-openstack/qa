#!/usr/bin/python

import copy
import paramiko
import re
import sys


def exec_command(ssh, cmd):
    print("cmd: %s" % cmd)
    _, stdout, _ = ssh.exec_command(cmd)
    outs = stdout.readlines()
    if outs and outs[0]:
        out = outs[0].strip('\n')
        print("out: %s" % out)
        return out
    else:
        return


def delete_gre_connection(ssh, gre_net):
    try:
        print("==============================================================")
        print("delete gre connection\n")
        # delete existing gre rules and scripts under udev
        exec_command(ssh, "rm -f /etc/udev/rules.d/90-gre-tunnel.rules")
        exec_command(ssh, "rm -f /etc/udev/scripts/create-gre-tunnels.sh")
        # delete gre bridge
        net_uuid = exec_command(ssh, "xe network-list name-label=%s params=uuid minimal=true" % gre_net)
        if not net_uuid:
            print("No gre network at the moment")
            return
        gre_bridge = exec_command(ssh, "xe network-param-get param-name=bridge uuid=%s" % net_uuid)
        exec_command(ssh, "ovs-vsctl del-br %s" % gre_bridge)
        exec_command(ssh, "xe network-destroy uuid=%s" % net_uuid)
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
        "if ! /sbin/ip link show $bridge > /dev/null 2>&1; then\n"
        "# The bridge maybe will be appeared delay, wait a while\n"
        "sleep 1 \n"
        "fi\n"
        "if /sbin/ip link show $bridge > /dev/null 2>&1; then\n"
        "if ! /sbin/ip addr show $bridge|grep \"inet \" > /dev/null 2>&1; then\n"
        "/sbin/ip addr add %s/255.255.255.0 dev $bridge\n"
        "for ip in %s;\n"
        "do\n"
        "ovs-vsctl add-port $bridge port\$ip -- set interface port\$ip type=gre options:remote_ip=\$ip\n"
        "done\n"
        "ovs-vsctl set bridge $bridge stp_enable=true\n"
        "fi\n"
        "fi\n"
        "CREATE_GRE_EOF\n"
        "chmod +x /etc/udev/scripts/create-gre-tunnels.sh" % (gre_net, local_ip, remote_ips))


def create_gre_network(ssh, gre_net):
    print("==============================================================")
    print("create gre network")
    exec_command(ssh, "xe network-create name-label=%s" % gre_net)


def validate_ips(ip_list):
    pattern = re.compile(r'(?<![\.\d])(?:\d{1,3}\.){3}\d{1,3}(?![\.\d])')
    for ip in ip_list:
        if not pattern.match(ip):
            print("Error:\n\tIp %s is not valid" % ip)
            return False
    return True


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
    print("==============================================================")
    result = validate_ips(all_ips)
    if not result:
        exit()
    for ip in all_ips:
        remote_ip_list = copy.deepcopy(all_ips)
        remote_ip_list.remove(ip)
        remote_ips = ""
        for temp_ip in remote_ip_list:
            remote_ips = temp_ip + " " + remote_ips
        ssh = create_ssh_connection("root", password, ip)
        delete_gre_connection(ssh, gre_net)
        create_gre_network(ssh, gre_net)
        create_udev_rules(ssh)
        gre_ip_start += 1
        gre_ip = gre_ip_pre % gre_ip_start
        create_udev_script(ssh, gre_ip, remote_ips, gre_net)
        # close ssh connection
        ssh.close()

