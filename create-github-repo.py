import sys
import requests
import json


def create_repo(username, password, org, repo):
    gurl = 'https://api.github.com'
    getrepo = gurl + '/repos/%s/%s' % (org, repo)
    createrepo = gurl + '/orgs/%s/repos' % org
    params = dict(auth=(username, password))

    r = requests.get(getrepo, **params)

    if 404 == r.status_code:
        print "creating repo..."
        requests.post(createrepo, data=
            json.dumps({
                'name': repo,
                'team_id': 122958,
            }), **params)
        r = requests.get(getrepo, **params)
        assert 200 == r.status_code
        print "repo created"
    else:
        print "repo exists"


def main():
    username, password, org, repo = sys.argv[1:]
    assert repo.endswith('.git')
    repo = repo[:-len('.git')]
    create_repo(username, password, org, repo)


if __name__ == "__main__":
    main()
