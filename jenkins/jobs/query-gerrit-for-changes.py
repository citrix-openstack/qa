import sys
import os
import argparse
import paramiko
import json
import logging


logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)


def create_query_expression(owners):
    return '( ' + ' OR '.join('owner:%s' % owner for owner in owners) + ') '


def query_for_extra_changes(changes):
    if changes:
        result = ' OR '
        result += ' OR '.join('( change:%s AND status:open )' % change for change in changes)
        return result
    else:
        return ''


def main(args):
    hostname = args.host
    port = int(args.port)
    username = args.username
    keyfile = args.keyfile
    owners = args.watched_owners.split(',')

    client = paramiko.SSHClient()
    client.load_system_host_keys()
    client.set_missing_host_key_policy(paramiko.WarningPolicy())
    client.connect(hostname, port=port, username=username, key_filename=keyfile)
    cmd = "gerrit query --patch-sets --format=JSON --current-patch-set status:open AND branch:%s AND %s %s" % \
           (args.branch, create_query_expression(owners), query_for_extra_changes(args.change))
    logger.debug(cmd)
    stdin, stdout, stderr = client.exec_command(cmd)


    def to_change_record(change):
        logger.debug("Processing change: %s" % change)
        if 'currentPatchSet' not in change:
            return
        latest_patchset = change['currentPatchSet']

        if latest_patchset['isDraft']:
            return
        bad_approvals = [x for x in latest_patchset['approvals'] if x['type'] == 'Workflow' and (
            x['value'] == '-1' or x['value'] == '-2')]
        if len(bad_approvals) > 0:
            return

        bad_approvals = [x for x in latest_patchset['approvals'] if x['type'] == 'Code-Review' and x['value'] == '-2']
        if len(bad_approvals) > 0:
            return

        bad_approvals = [x for x in latest_patchset['approvals'] if x['type'] == 'Code-Review' and x['value'] == '-1' and x['by']['username'] in owners]
        if len(bad_approvals) > 0:
            return

        project = change['project']

        changeref = latest_patchset['ref']
        change_url = change['url']
        return (change['createdOn'], project, changeref, change_url)


    change_records = []
    for line in stdout.readlines():
        change = json.loads(line)
        change_record = to_change_record(change)
        if change_record:
            change_records.append(change_record)


    for change_record in sorted(change_records):
        change_id = change_record[-1].split('/')[-1]
        if args.ignore and change_id in args.ignore:
            continue
        sys.stdout.write("%s %s %s\n" % change_record[1:])

    client.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Get changes repo from OpenStack gerrit')
    parser.add_argument('username', help='Gerrit username to use')
    parser.add_argument('keyfile', help='SSH key to use')
    parser.add_argument('watched_owners',
        help='Comma separated list of Owner ids whose changes to be collected')
    parser.add_argument('--host', default='review.openstack.org',
        help='Specify a host. default: review.openstack.org')
    parser.add_argument('--port', default='29418',
        help='Specify a port. default: 29418')
    parser.add_argument('--change', action='append',
        help='Extra change ids to pick')
    parser.add_argument('--ignore', action='append',
        help='Change IDs to ignore')
    parser.add_argument('--branch', default='master',
        help='Branch to use (e.g. stable/icehouse)')
    args = parser.parse_args()
    main(args)
