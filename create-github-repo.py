import sys
import requests
import json


DST_ORG = "citrix-openstack-build"
GURL = 'https://api.github.com'
GETREPO = GURL + '/repos/%s/%s'
FORKREPO = GURL + '/repos/%s/%s/forks'


class Repo(object):
    def __init__(self, provider, org, name):
        self.org = org
        self.name = name
        self.provider = provider

    def __str__(self):
        return "Repository %s %s %s" % (self.provider, self.org, self.name)


def create_repo_from_line(repoline):
    varname, org, repo, provider = repoline.strip().split(' ')
    assert repo.endswith('.git')
    return Repo(provider, org, repo[:-len('.git')])


def status_is_ok(status):
    return status >= 200 and status < 300


def fork_repo(username, password, repo):
    params = dict(auth=(username, password))

    r = requests.post(FORKREPO % (repo.org, repo.name), **params)
    assert status_is_ok(r.status_code)


def repo_missing(username, password, repo):
    params = dict(auth=(username, password))

    r = requests.get(GETREPO % (repo.org, repo.name), **params)
    if r.status_code == 404:
        return True
    assert status_is_ok(r.status_code)


def deal_with_repos(username, password, repos):
    print "Checking that all repos exist"
    missing = []
    total = 0
    for repo_record in repos:
        total += 1
        if repo_missing(username, password, repo_record):
            missing.append(repo_record)

    if len(missing):
        print "Some repos are missing:"
        for repo in missing:
            print " ", repo
        return 1

    print "OK"

    for src_repo in repos:
        dst_repo = Repo('github', DST_ORG, src_repo.name)
        if repo_missing(username, password, dst_repo):
            print dst_repo, "does not exist, forking", src_repo
            fork_repo(username, password, src_repo)

    print "OK"

    return 0


def main():
    username, password = sys.argv[1:]
    repo_records = [create_repo_from_line(line) for line in sys.stdin.readlines()]
    sys.exit(deal_with_repos(username, password, repo_records))


if __name__ == "__main__":
    main()
