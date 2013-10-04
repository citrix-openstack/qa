import requests
import json
import sys


username, password = sys.argv[1:]

repoz = []
resp = requests.get('https://api.github.com/orgs/citrix-openstack/repos')
repoz += json.loads(resp.text)

link_header = resp.headers['link']
for link in link_header.split(','):
    if link.endswith('rel="next"'):
        url = link.split('>')[0][1:]
        resp = requests.get(url)
        repoz += json.loads(resp.text)


for repo in repoz:
    if repo['name'].startswith('build-'):
        print repo['name'], repo['url']
        requests.delete(repo['url'], auth=(username, password))
