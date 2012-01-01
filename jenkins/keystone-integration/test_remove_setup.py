"""cleanup"""

import httplib2
import sys
import json
import test_keystone_integration as int_keystone
import common as utils

TENANT_A = "tenanta"
TENANT_B = "tenantb"
TENANT_C = "tenantc"
USER_A = "usera"
USER_B = "userb"
USER_B1 = "userb1"
USER_C = "userc"
TENANT_ADMIN = "tenantadmin"
ADMIN_AUTH_TOKEN = "999888777666"

nova_api_url = sys.argv[1] + "/v1.1/"
keystone_api_url = sys.argv[2] + "/v2.0/"
glance_api_url = sys.argv[3] + "/v1/"
swift_api_url = sys.argv[4] + "/v1/"
tenantadmin_server_id = None
usera_server_id = None
userb_server_id = None

resp, content = int_keystone.get_servers(nova_api_url, TENANT_A,
                                         ADMIN_AUTH_TOKEN)
if int(resp['status']) in [200, 201, 202, 203, 204]:
    data = content
    for d in data['servers']:
        if d['name'] == 'usera_server':
            usera_server_id = d['id']
            print "usera_server_id: %s" % usera_server_id

resp, content = int_keystone.get_servers(nova_api_url, TENANT_ADMIN,
                                         ADMIN_AUTH_TOKEN)
if int(resp['status']) in [200, 201, 202, 203, 204]:
    data = content
    for d in data['servers']:
        if d['name'] == 'tenantadmin_server':
            tenantadmin_server_id = d['id']
            print "tenantadmin_server_id: %s" % tenantadmin_server_id
#tenantadmin_server_id = content['servers'][1]['id']

resp, content = int_keystone.get_servers(nova_api_url, TENANT_B,
                                         ADMIN_AUTH_TOKEN)
if int(resp['status']) in [200, 201, 202, 203, 204]:
    data = content
    for d in data['servers']:
        if d['name'] == 'userb_server':
            userb_server_id = d['id']
            print "userb_server_id: %s" % userb_server_id


def clean_setup():
    if usera_server_id:
        int_keystone.delete_server(nova_api_url, TENANT_A, ADMIN_AUTH_TOKEN,
                               usera_server_id)
    if userb_server_id:
        int_keystone.delete_server(nova_api_url, TENANT_B, ADMIN_AUTH_TOKEN,
                               userb_server_id)
    if tenantadmin_server_id:
        int_keystone.delete_server(nova_api_url, TENANT_A, ADMIN_AUTH_TOKEN,
                               tenantadmin_server_id)

    tenanta_id, usera_id = utils.get_usrandtenant_id(USER_A, USER_A,
                                                     keystone_api_url)
    utils.delete_user(usera_id, ADMIN_AUTH_TOKEN, keystone_api_url)

    tenantb_id, userb_id = utils.get_usrandtenant_id(USER_B, USER_B,
                                                     keystone_api_url)
    utils.delete_user(userb_id, ADMIN_AUTH_TOKEN, keystone_api_url)

    tenantb_id, userb1_id = utils.get_usrandtenant_id(USER_B1, USER_B1,
                                                      keystone_api_url)
    utils.delete_user(userb1_id, ADMIN_AUTH_TOKEN, keystone_api_url)

    tenantc_id, userc_id = utils.get_usrandtenant_id(USER_C, USER_C,
                                                     keystone_api_url)
    utils.delete_user(userc_id, ADMIN_AUTH_TOKEN, keystone_api_url)

    tenanta_id, tenantadmin_id = utils.get_usrandtenant_id(TENANT_ADMIN,
                                                     TENANT_ADMIN,
                                                     keystone_api_url)
    utils.delete_user(tenantadmin_id, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.delete_tenant(tenanta_id, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.delete_tenant(tenantb_id, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.delete_tenant(tenantc_id, ADMIN_AUTH_TOKEN, keystone_api_url)
    print 'Deleted Users and Tenants from remove_setup.py...'


clean_setup()
