import sys
import argparse
import socket
import urllib2


def generate_test(src_stream, dst_stream, xs_address, xs_password):
    sections = []

    def newsection(section):
        sections.append(section)

    section = []
    for line in src_stream.readlines():
        if 'Appendix' in line:
            break
        if '' == line.strip():
            newsection(section)
            section = []
        else:
            section.append(line.replace('\n', ''))

    raw_sections = []

    for section in sections:
        for line in section:
            if line.startswith("    "):
                raw_sections.append(section)
            break

    def replace_vars(line):
        return line.replace("address_of_your_xenserver", xs_address).replace(
            "my_xenserver_root_password", xs_password)

    dst_stream.write("set -eux\n")
    for section in raw_sections:
        for line in section:
            dst_stream.write(replace_vars(line.strip()) + "\n")


def resolve_host(hostname):
     return socket.gethostbyname(hostname)


def devstack_readme_stream():
    return urllib2.urlopen("https://raw.github.com/openstack-dev/devstack/master/tools/xen/README.md")


def main():
    parser = argparse.ArgumentParser(description="Get official instructions for devstack")
    parser.add_argument('host', help='Hypervisor to use')
    parser.add_argument('password', help='Password for the hypervisor')
    args = parser.parse_args()

    generate_test(
        devstack_readme_stream(),
        sys.stdout,
        resolve_host(args.host),
        args.password)


if __name__ == "__main__":
    main()
