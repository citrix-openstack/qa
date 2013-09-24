import tarfile
import argparse
import StringIO


def get_args():
    parser = argparse.ArgumentParser(description='Rename network bridges in an'
        ' xva file: xapi1 -> openstack1 and xapi2 -> openstack2')
    parser.add_argument('source_xva_file', help='source xva file')
    parser.add_argument('target_xva_file', help='target xva file')
    return parser.parse_args()


def hack_xva(src, tgt):
    with open(src, 'rb') as src_stream:
        with open(tgt, 'wb') as tgt_stream:
            with tarfile.open(mode='r|gz', fileobj=src_stream) as src_tar:
                with tarfile.open(mode='w|gz', fileobj=tgt_stream) as tgt_tar:
                    original_info = src_tar.next()
                    xml_file = src_tar.extractfile(original_info).read()
                    modded_xml = xml_file.replace('xapi1', 'openstack1').replace('xapi2', 'openstack2')

                    modified_xml_file = StringIO.StringIO(modded_xml)

                    tinfo = tarfile.TarInfo()
                    tinfo.name = original_info.name
                    tinfo.size = len(modded_xml)
                    tinfo.mtime = original_info.mtime
                    tinfo.type = original_info.type
                    tinfo.uid = original_info.uid
                    tinfo.gid = original_info.gid
                    tinfo.uname = original_info.uname
                    tinfo.gname = original_info.gname
                    tinfo.pax_headers = original_info.pax_headers

                    tgt_tar.addfile(tinfo, modified_xml_file)

                    while True:
                        tinfo = src_tar.next()
                        if tinfo is None:
                            break
                        tgt_tar.addfile(tinfo, src_tar.extractfile(tinfo))


def main():
    args = get_args()
    hack_xva(args.source_xva_file, args.target_xva_file)


if __name__ == "__main__":
    main()
