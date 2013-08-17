#!/usr/bin/env python

# Tool to package an XVA with an existing ova.xml
# This is a reduced version of http://www-archive.xenproject.org/files/xva/xva.py
# which was originally created by David Markey <david.markey@citrix.com>.
# Author: Robert Breker <robert.breker@citrix.com>, Citrix Systems.
# Licence: GNU LESSER GENERAL PUBLIC LICENSE V3, http://www.gnu.org/licenses/lgpl-3.0.txt
# THIS SOFTWARE COMES WITH ABSOLUTELY NO WARRANTY! USE AT YOUR OWN RISK!

import os
import tarfile
import cStringIO
import sys
import copy
import argparse
import hashlib


def make_xva(output_path, sparse, ova_xml_path, disk_path, disk_reference):
    output_file = tarfile.open(output_path, mode='w|')
    print "Generating XVA file %s" % output_path

    info = tarfile.TarInfo(name="ova.xml")

    ova_file = open(ova_xml_path)
    ova_content = str(ova_file.read()).replace("@VDI_SIZE@", str(os.stat(disk_path).st_size))
    ova_file.close()
    string = cStringIO.StringIO(ova_content)
    string.seek(0)

    info.size = len(ova_content)

    try:
        output_file.addfile(tarinfo=info, fileobj=string)
    except:
        self.handle_exception()

    chunksize = 1048576

    basefilename = 0
    input_file = open(disk_path, "rb")
    input_file.seek(0, os.SEEK_END)
    input_file_size = input_file.tell()
    input_file.seek(0)

    position = 0
    print "\nProcessing disk %s(%s bytes)" % (disk_path, input_file_size)
    read_len = -1

    while True:
        input_buffer = input_file.read(chunksize)
        read_len = len(input_buffer)
        if read_len == 0:
             break
        force = False

        if position == 0:
             force = True

        if (input_file_size - position) < (chunksize * 2):
            force = True

        position = position + chunksize

        input_file.seek(position)

        zeroes = input_buffer.count('\0')

        if zeroes == chunksize and not force and sparse:
            basefilename = basefilename + 1
        else:
            string = cStringIO.StringIO(input_buffer)
            string.seek(0)
            info = tarfile.TarInfo(
                 name="%s/%08d" % (disk_reference, basefilename))
            info.size = read_len

            try:
                output_file.addfile(tarinfo=info, fileobj=string)
            except:
                 self.handle_exception()

            hash = hashlib.sha1(input_buffer).hexdigest()
            string = cStringIO.StringIO(hash)
            info = tarfile.TarInfo(
                name="%s/%08d.checksum" % (disk_reference, basefilename))
            info.size = 40

            try:
                output_file.addfile(tarinfo=info, fileobj=string)
            except:
                self.handle_exception()

            basefilename = basefilename + 1
    output_file.close()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='XVA generator')
    parser.add_argument(
        '--output_path', '-o', required=True, help='Output xva path')
    parser.add_argument(
        '--ova_xml_path', required=True, help='Path of the ova.xml for the xva')
    parser.add_argument(
        '--disk_path', required=True,  help='Path of the disk for the xva')
    parser.add_argument(
        '--disk_reference', required=True,  help='The XVA reference to the disk')
    args = parser.parse_args()
    make_xva(args.output_path, True, args.ova_xml_path, args.disk_path, args.disk_reference)
