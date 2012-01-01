#!/usr/bin/env python

import datetime
import os
import re
import sys
import time
import urllib
import logging

lock = '/tmp/all-xs-build-status.run'
branches = [('openstack', 'trunk', 'cam', 'os-vpx/os-vpx-phase-build'),
            ('openstack', 'trunk', 'blr', 'os-vpx/os-vpx-phase-build'),
            ('openstack', 'trunk', 'pa', 'os-vpx/os-vpx-phase-build'),
            ('carbon', 'trunk', 'cam', 'core/xe-phase-1-build'),
            ('carbon', 'trunk', 'blr', 'core/xe-phase-1-build'),
            ('carbon', 'trunk', 'pa', 'core/xe-phase-1-build')]

xenbuilder_url_pattern = 'https://xenbuilder.uk.xensource.com/builds?q_view=details&q_product=%(product)s&q_branch=%(branch)s'
xenbuilder_result_url_pattern = 'https://xenbuilder.uk.xensource.com/builds?q_view=details&q_product=%(product)s&q_branch=%(branch)s&q_number=%(number)s'
jenkins_result_url_pattern = 'http://localhost:8080/job/build-%(product)s-%(site)s/postBuildResult'
jenkins_configure_url_pattern = 'http://localhost:8080/job/build-%(product)s-%(site)s/lastBuild/configSubmit'
bn_regex_pattern = r'/tail/%(product)s/%(branch)s/([0-9]*)/%(site)s/%(job)s'
last_result_file_pattern = 'last_result_%(product)s_%(branch)s_%(site)s'


logger = logging.getLogger('get-xs-build-status')

def get_status(product, branch):
    fd = urllib.urlopen(xenbuilder_url_pattern % locals())
    try:
        return fd.readlines()
    finally:
        fd.close()


def get_status_lines(product, branch, site):
    result = []
    for l in get_status(product, branch):
        result += l.split('</tr>')
    return [x for x in result if 'tail' in x and ('<td>%s</td>' % site) in x]


def parse_status_line(product, branch, site, job, lines):
    for line in lines:
        bn_regex = re.compile(bn_regex_pattern % locals())
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


def get_detail(product, branch, result):
    number = result[0]
    fd = urllib.urlopen(xenbuilder_result_url_pattern % locals())
    try:
        return fd.readlines()
    finally:
        fd.close()


def get_duration(product, branch, result):
    lines = []
    for l in get_detail(product, branch, result):
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


def get_last_result(product, branch, site):
    try:
        with file(last_result_file_pattern % locals(), 'rb') as f:
            return eval(f.readline())
    except:
        return None, None


def set_last_result(product, branch, site, res):
    with file(last_result_file_pattern % locals(), 'wb') as f:
        f.write(str(res))


def make_jenkins_result_xml(product, branch, result):
    duration = get_duration(product, branch, result)
    if result[1]:
        result_code = 0
    else:
        result_code = 1
    number = result[0]
    result_url = hexbinary('%s&_=' % (xenbuilder_result_url_pattern %
                                      locals()))
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


if __name__ == "__main__":
    logging.basicConfig(level=logging.DEBUG)
    logger.debug('Started at: %s' % datetime.datetime.now())
    can_delete = True
    if os.path.exists(lock):
        logger.debug('An instance of this program is already running, bailing!')
        can_delete = False
    else:
        try:
            logger.debug('Creating lock file at %s' % lock)
            f = open(lock, 'w')
            f.close()

            for product, branch, site, job in branches:
                last_result = get_last_result(product, branch, site)
                try:
                    new_result = \
                               parse_status_line(product, branch, site, job,
                                                 get_status_lines(product, branch,
                                                                  site,))
                    if new_result is not None and new_result != last_result:
                        logger.info(
                            'New build for %(product)s %(branch)s %(site)s: '
                            '%(new_result)s' % locals())
                        post(jenkins_result_url_pattern % locals(),
                             make_jenkins_result_xml(product, branch, new_result))
                        post(jenkins_configure_url_pattern % locals(),
                             make_jenkins_configure_body(new_result))
                        last_result = new_result
                        set_last_result(product, branch, site, last_result)
                except Exception, exn:
                    logger.error(exn)
                    raise
            logger.debug('Ended at: %s' % datetime.datetime.now())
        finally:
            if can_delete:
               logging.debug('Removing lock file at %s' % lock)
               os.remove(lock)
