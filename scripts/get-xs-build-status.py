#!/usr/bin/env python

import datetime
import os
import re
import sys
import time
import urllib
import logging

site = 'cam'
lock = '/tmp/get-xs-build-status.run'
#site = 'pa'

xenbuilder_url = 'https://xenbuilder.uk.xensource.com/builds?q_view=summary&q_product=openstack&q_branch=trunk'
xenbuilder_result_url = 'https://xenbuilder.uk.xensource.com/builds?q_view=details&q_product=openstack&q_branch=trunk&q_number=%s'
jenkins_result_url = 'http://localhost:8080/job/os-vpx-build/postBuildResult'
jenkins_configure_url = 'http://localhost:8080/job/os-vpx-build/lastBuild/configSubmit'
jenkins_test_trigger_url = 'http://localhost:8080/job/os-vpx-test-all/build?delay=0sec'
bn_regex = re.compile(r'/tail/openstack/trunk/(.*)/%s' % site)


logger = logging.getLogger('get-xs-build-status')

def get_status():
    fd = urllib.urlopen(xenbuilder_url)
    try:
        return fd.readlines()
    finally:
        fd.close()


def get_status_lines():
    result = []
    for l in get_status():
        result += l.split('</tr>')
    return [x for x in result if 'tail' in x and ('<td>%s</td>' % site) in x]


def parse_status_line(lines):
    for line in lines:
        m = bn_regex.search(line)
        build_no = m and m.group(1) or 0
        result = parse_status_result(line)
        if result is not None:
            return build_no, result
    return None


def parse_status_result(line):
    if 'failed' in line:
        return False
    elif 'succeeded' in line:
        return True
    else:
        return None


def get_detail(result):
    fd = urllib.urlopen(xenbuilder_result_url % result[0])
    try:
        return fd.readlines()
    finally:
        fd.close()


def get_duration(result):
    lines = []
    for l in get_detail(result):
        lines += l.split('</tr>')
    bits = [x.split('<td') for x in lines]
    bits = [x for x in bits if len(x) > 2 and site in x[2]][0]
    def parse(bit):
        try:
            return datetime.datetime.strptime(bit[1:-8], '%Y-%m-%d %H:%M:%S')
        except ValueError, e:
            logger.exception(e)
            # Somehow, result can contain a timestamp with no milliseconds
            return datetime.datetime.strptime(bit[1:-6], '%Y-%m-%d %H:%M:%S')
    started = parse(bits[6])
    ended = parse(bits[7])
    diff = ended - started
    return 1000 * (diff.seconds + diff.days * 24 * 60 * 60)


def get_last_result():
    try:
        with file('last_result', 'rb') as f:
            return eval(f.readline())
    except:
        return None, None


def set_last_result(res):
    with file('last_result', 'wb') as f:
        f.write(str(res))


def make_jenkins_result_xml(result):
    duration = get_duration(result)
    if result[1]:
        result_code = 0
    else:
        result_code = 1
    result_url = hexbinary('%s&_=' % (xenbuilder_result_url % result[0]))
    return '<run><log encoding="hexBinary">%s</log>' \
           '<result>%d<result><duration>%d</duration></run>' % (result_url,
                                                                result_code,
                                                                duration)


def make_jenkins_configure_body(result):
    displayName = result[0]
    description = ''
    json = (
        '{"displayName":"%(displayName)s","description":"%(description)s"}' %
        locals())
    Submit = 'Save'
    return urllib.urlencode(locals())


def hexbinary(s):
    result = ''
    for c in s:
        result += '%x' % ord(c)
    return result


def get(get_url):
    logger.info('Getting %(get_url)s.' % locals())
    url = urllib.urlopen(get_url)
    try:
        return url.readlines()
    finally:
        url.close()


def post(post_url, body):
    logger.info('Posting: %(post_url)s, %(body)s.' % locals())
    url = urllib.urlopen(post_url, body)
    try:
        url.readlines()
    finally:
        url.close()


def update_forest_from_build(build_number):
    cmd = 'forest.hg/update-forest-from-build %s' % build_number
    logger.debug('Running %s', cmd)
    os.system(cmd)


def update_forest_from_repo(repo):
    cmd = 'forest.hg/update-forest-from-repo %s' % repo
    logger.debug('Running %s', cmd)
    os.system(cmd)


if __name__ == "__main__":
    logging.basicConfig(filename='/var/log/get-xs-build-status.log', level=logging.DEBUG)
    logger.debug('Started at: %s' % datetime.datetime.now())
    can_delete = True
    try:
        if os.path.exists(lock):
            logger.debug('An instance of this program is already running, bailing!')
            can_delete = False
        else:
            logger.debug('Creating lock file at %s' % lock)
            f = open(lock, 'w')
            f.close()
            last_result = get_last_result()
            new_result = parse_status_line(get_status_lines())
            if new_result is not None and new_result != last_result:
                logger.info('New build: %s' % str(new_result))
                post(jenkins_result_url, make_jenkins_result_xml(new_result))
                post(jenkins_configure_url, make_jenkins_configure_body(new_result))
                if new_result[1]:
                    update_forest_from_build(new_result[0])
                    get(jenkins_test_trigger_url)
                last_result = new_result
                set_last_result(last_result)
            else:
                logger.debug('Checking qa.hg instead')
                update_forest_from_repo('qa.hg')
        logger.debug('Ended at: %s' % datetime.datetime.now())
    except Exception, exn:
        logger.error(exn)
    finally:
        if can_delete:
           logging.debug('Removing lock file at %s' % lock)
           os.remove(lock)

