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

class ChangeRecord(object):
    def __init__(self, createdOn, revision, project, changeref, change_url):
        self.createdOn = createdOn
        self.project = project
        self.changeref = changeref
        self.change_url = change_url
        self.revision = revision
        self.parents = []
        self.oldChangeSets = []
        self.ignoreReasons = []
        logger.debug('New change record %s'%self)

    def addParent(self, parent):
        self.parents.append(parent)
        logger.debug("CR [%s]: added parent: %s " % (self, parent))

    def addOldChangeset(self, oldchangeset):
        self.oldChangeSets.append(oldchangeset)
        logger.debug("CR [%s]: added old change %s" % (oldchangeset, self))

    def obsoletes(self, otherCR):
        for parent in otherCR.parents:
            if parent in self.oldChangeSets:
                return True
        return False

    def dependsOn(self, otherCR):
        return otherCR.revision in self.parents

    def ignore(self, reason):
        self.ignoreReasons.append(reason)

    def ignored(self):
        return len(self.ignoreReasons) > 0

    def outputLine(self):
        if len(self.ignoreReasons) > 0:
            return "# %s: Ignored (%s)"%(self, ",".join(self.ignoreReasons))
        return str(self)

    def __repr__(self):
        return "%s %s %s"%(self.project, self.changeref, self.change_url)

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

        project = change['project']

        changeref = latest_patchset['ref']
        change_url = change['url']

        cr = ChangeRecord(change['createdOn'], latest_patchset['revision'], project, changeref, change_url)
        for parent in latest_patchset['parents']:
            cr.addParent(parent)
        for patchset in change['patchSets']:
            if patchset['ref'] == changeref:
                continue
            cr.addOldChangeset(patchset['revision'])

        if 'approvals' in latest_patchset:
            bad_approvals = [x for x in latest_patchset['approvals'] if x['type'] == 'Workflow' and (
                x['value'] == '-1' or x['value'] == '-2')]
            if len(bad_approvals) > 0:
                cr.ignore('Workflow -1/-2')

            bad_approvals = [x for x in latest_patchset['approvals'] if x['type'] == 'Code-Review' and x['value'] == '-2']
            if len(bad_approvals) > 0:
                cr.ignore('Code-Review -2')

            bad_approvals = [x for x in latest_patchset['approvals'] if x['type'] == 'Code-Review' and x['value'] == '-1' and x['by']['username'] in owners]
            if len(bad_approvals) > 0:
                cr.ignore('team -1')

            # If Jenkins complains, don't consider for our CI.  Could be a merge failure, or a pep8/unit test issue caused by a syntax error
            bad_approvals = [x for x in latest_patchset['approvals'] if x['type'] == 'Code-Review' and x['value'] == '-1' and x['by']['username'] == 'jenkins']
            if len(bad_approvals) > 0:
                cr.ignore('jenkins -1')

        return cr


    change_records = []
    for line in stdout.readlines():
        change = json.loads(line)
        change_record = to_change_record(change)
        if change_record:
            change_records.append(change_record)
    client.close()

    anyChanges=True
    while (anyChanges):
        anyChanges = False
        for cr in change_records:
            if cr.ignored():
                # Skip changes already ignored
                continue
            for cr2 in change_records:
                if cr2.obsoletes(cr):
                    cr.ignore('Obsoleted by %s'%cr2)
                    anyChanges = True
                if cr2.ignored() and cr.dependsOn(cr2):
                    cr.ignore('Required change %s already ignored'%cr2)
                    anyChanges = True

    logger.debug('===== End of debug messages =====')
    for change_record in sorted(change_records):
        change_id = change_record.change_url.split('/')[-1]
        if args.ignore and change_id in args.ignore:
            change_record.ignore('Ignore of change_id %s'%change_id)
        sys.stdout.write("%s\n"%change_record.outputLine())



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
