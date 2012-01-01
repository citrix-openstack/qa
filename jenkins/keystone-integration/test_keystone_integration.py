"""Keystone Integration test for nova, glance and swift"""

import httplib2
import unittest
import sys
import json
import time

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
FIVE_KB = 5 * 1024
FIVE_GB = 5 * 1024 * 1024 * 1024


def setup_tenants_users():
    resp, content = utils.create_tenant(TENANT_A, ADMIN_AUTH_TOKEN,
                                        keystone_api_url)
    data = json.loads(content)
    if data['tenant']['name'] == TENANT_A:
        tenanta_id = data['tenant']['id']
    resp, content = utils.create_tenant(TENANT_B, ADMIN_AUTH_TOKEN,
                                        keystone_api_url)
    data = json.loads(content)
    if data['tenant']['name'] == TENANT_B:
        tenantb_id = data['tenant']['id']
    resp, content = utils.create_tenant(TENANT_C, ADMIN_AUTH_TOKEN,
                                        keystone_api_url)
    data = json.loads(content)
    if data['tenant']['name'] == TENANT_C:
        tenantc_id = data['tenant']['id']

    resp, content = utils.create_user(tenanta_id, USER_A, ADMIN_AUTH_TOKEN,
                                      keystone_api_url, 'a@bc.com', USER_A)
    data = json.loads(content)
    if data['user']['name'] == USER_A:
        usera_id = data['user']['id']
    resp, content = utils.create_user(tenantb_id, USER_B, ADMIN_AUTH_TOKEN,
                                      keystone_api_url, 'b@abc.com', USER_B)
    data = json.loads(content)
    if data['user']['name'] == USER_B:
        userb_id = data['user']['id']
    resp, content = utils.create_user(tenantb_id, USER_B1, ADMIN_AUTH_TOKEN,
                                      keystone_api_url, 'b1@abc.com', USER_B1)
    data = json.loads(content)
    if data['user']['name'] == USER_B1:
        userb1_id = data['user']['id']
    resp, content = utils.create_user(tenantc_id, USER_C, ADMIN_AUTH_TOKEN,
                                      keystone_api_url, 'c@abc.com', USER_C)
    data = json.loads(content)
    if data['user']['name'] == USER_C:
        userc_id = data['user']['id']
    resp, content = utils.create_user(tenanta_id, TENANT_ADMIN,
                                      ADMIN_AUTH_TOKEN,
                                      keystone_api_url,
                                      'tenant_admin@bac.com', TENANT_ADMIN)
    data = json.loads(content)
    if data['user']['name'] == TENANT_ADMIN:
        tenantadmin_id = data['user']['id']
    utils.create_role_ref(usera_id, "4", tenanta_id,
                                          ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_role_ref(tenantadmin_id, "1", tenanta_id,
                                          ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_role_ref(userb_id, "4", tenantb_id,
                                          ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_role_ref(userb1_id, "4", tenantb_id,
                                          ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_role_ref(userc_id, "4", tenantc_id,
                                          ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenanta_id, 1, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenanta_id, 2, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenanta_id, 3, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenanta_id, 4, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenanta_id, 5, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenantb_id, 1, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenantb_id, 2, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenantb_id, 3, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenantb_id, 4, ADMIN_AUTH_TOKEN, keystone_api_url)
    utils.create_endpoint(tenantb_id, 5, ADMIN_AUTH_TOKEN, keystone_api_url)


def authenticate_user(usr, pwd):
    resp = utils.get_token(usr, pwd, keystone_api_url, 'token')
    return resp


def get_servers(nova_api_url, tenant_id, auth_token):
    header = httplib2.Http(".cache")
    url = '%s%s/servers' % (nova_api_url, tenant_id)
    resp, content = header.request(url, "GET", body='',
                                   headers={"Content-Type": "application/json",
                                            "X-Auth-Token": auth_token})
    return (resp, json.loads(content))


def create_server(tenant_id, server_name, auth_token):
    header = httplib2.Http(".cache")
    url = '%s%s/servers' % (nova_api_url, tenant_id)
    body = '{"server" : { "name" : "%s","imageRef" : "3","flavorRef" : "1"}}' \
             % (server_name)
    resp, content = header.request(url, "POST", body,
                                   headers={"Content-Type": "application/json",
                                            "X-Auth-Token":  auth_token})
    #print "createserver :: resp : %s content :%s " % (type(resp), content)
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        return (resp, json.loads(content))
    else:
        raise NameError("Unable to Create Server %s" % (server_name))


def reboot_server(tenant_id, auth_token, server_id):
    #POST    /servers/id/action
    header = httplib2.Http(".cache")
    url = '%s%s/servers/%s/action' % (nova_api_url, tenant_id, server_id)
    resp, content = header.request(url, "POST", body='{"reboot" : \
                                                       {"type" : "HARD"}}',
                                   headers={"Content-Type": "application/json",
                                            "X-Auth-Token": auth_token})
    print "Reboot Server::resp %s content %s " % (resp, content)
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        return resp
    else:
        raise NameError("Unable to reboot")


def is_server_build(tenant_id, server_id, auth_token):
    header = httplib2.Http(".cache")
    url = '%s%s/servers/%s' % (nova_api_url, tenant_id, server_id)
    resp, content = header.request(url, "GET", body='',
                                   headers={"Content-Type": "application/json",
                                            "X-Auth-Token": auth_token})
    content = json.loads(content)
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        if content['server']['status'] == "ACTIVE":
            return True
        else:
            return False
    else:
        raise NameError("Unable to find the status of the Build:resp, content")


def delete_server(nova_api_url, tenant_id, auth_token, server_id):
    header = httplib2.Http(".cache")
    url = '%s%s/servers/%s' % (nova_api_url, tenant_id, server_id)
    print "urls is ", url
    resp, content = header.request(url, "DELETE", body='',
                                   headers={"Content-Type": "application/json",
                                            "X-Auth-Token": auth_token})
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        print "Server got Terminated/Deleted"
        return resp
    else:
        raise NameError("Unable to delete the server : resp %s content %s" \
                        % (resp, content))


def list_images(tenant_id, auth_token):
    header = httplib2.Http(".cache")
    url = '%simages' % (nova_api_url)
    resp, content = header.request(url, "GET", body='',
                                   headers={"Content-Type": "application/json",
                                    "X-Auth-Token": auth_token})
    print "Image list ::resp %s content %s " % (resp, content)
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        return (resp, json.loads(content))
    else:
        raise NameError("Unable to Create Server %s" % (server_name))


def post_images(auth_token, image_name, is_public, owner):
    image_data = "*" * FIVE_KB
    header = httplib2.Http(".cache")
    path = "%simages" % (glance_api_url)
    resp, content = header.request(path, "POST", body=image_data,
                                   headers={'Content-Type':
                                            'application/octet-stream',
                                    'X-Auth-Token': auth_token,
                                    'X-Image-Meta-Name': image_name,
                                    'X-Image-Meta-Disk-Format': 'ari',
                                    'X-Image-Meta-Container-Format': 'ari',
                                    'X-Image-Meta-Status': 'active',
                                    'X-Image-Meta-Is-Public': is_public,
                                    'X-Image-Meta-Owner': owner})
    return (resp, content)


def delete_images(glance_api_url, auth_token, image_id):
    header = httplib2.Http(".cache")
    url = '%simages/%d' % (glance_api_url, image_id)
    resp, content = header.request(url, "DELETE", body='',
                                   headers={"Content-Type": "application/json",
                                            "X-Auth-Token":  auth_token})
    return resp, content


def Modify_Quota_Value_instanceCount(firsttenant_id, secondtenant_id, \
                                     auth_token, no_of_instance):
    header = httplib2.Http(".cache")
    url = '%s%s/admin/quota_sets/%s' % (nova_api_url, firsttenant_id,
                                        secondtenant_id)
    mybody = '{"quota_set": {"instances": " %s" }}' % (no_of_instance)
    resp, content = header.request(url, "PUT", body=mybody,
                                   headers={"Content-Type": "application/json",
                                            "X-Auth-Token":  auth_token})
    #print "eval(content)"
    #print eval(content)
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        return resp
    else:
        raise NameError("Unable to modify quota : resp %s content %s" \
                        % (resp, content))


def get_quota_instance(firsttenant_id, secondtenant_id, auth_token):
    header = httplib2.Http(".cache")
    url = '%s%s/admin/quota_sets/%s' % (nova_api_url, firsttenant_id,
                                        secondtenant_id)
    mybody = '{"quota_set": { }}'
    resp, content = header.request(url, "PUT", body=mybody,
                                   headers={"Content-Type": "application/json",
                                            "X-Auth-Token":  auth_token})
    #print "eval(content)"
    #print eval(content)
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        return resp
    else:
        raise NameError("Unable to get quota : resp %s content %s" \
                        % (resp, content))


def get_flavors(auth_token):
    header = httplib2.Http(".cache")
    url = '%sflavors' % (URL_V2)
    resp, content = header.request(url, "GET", body='',
                                   headers={"Content-Type": "application/json",
                                            "X-Auth-Token":  auth_token})
    #print "eval(content)"
    #print eval(content)
    print "Flavors list ::resp %s content %s " % (resp, content)


def list_containers(swift_api_url, tenant_id, auth_token):
    #Create a container on swift from a given name
    tenant_account = 'AUTH_' + tenant_id
    header = httplib2.Http(".cache")
    url = '%s%s' % (swift_api_url, tenant_account)
    resp, content = header.request(url, "GET", body='',
                                   headers={"Content-Type": "application/json",
                                            "Content-Length": "0",
                                            "X-Auth-Token": auth_token})
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        print "Container List %s" % content
        return resp, content
    else:
        raise NameError("Unable to list containers: resp %s content %s" \
                        % (resp, content))


#List containers
def create_container(tenant_id, auth_token, container):
    #Create a container on swift from a given name
    tenant_account = 'AUTH_' + tenant_id
    header = httplib2.Http(".cache")
    url = '%s%s/%s' % (swift_api_url, tenant_account, container)
    resp, content = header.request(url, "PUT", body='',
                                   headers={"Content-Type": "application/json",
                                            "Content-Length": "0",
                                            "X-Auth-Token": auth_token})
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        print "Created Container %s" % container
        return resp, content
    else:
        raise NameError("Unable to create the container: resp %s content %s" \
                        % (resp, content))


def delete_container(swift_api_url, tenant_id, auth_token, container):
    #Delete a container for a given name from swift
    tenant_account = 'AUTH_' + tenant_id
    header = httplib2.Http(".cache")
    url = '%s%s/%s' % (swift_api_url, tenant_account, container)
    resp, content = header.request(url, "DELETE", body='',
                                   headers={"Content-Type": "application/json",
                                            "Content-Length": "0",
                                            "X-Auth-Token": auth_token})
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        print "Container:%s got deleted" % container
        return resp, content
    else:
        raise NameError("Unable to delete the container: resp %s content %s" \
                        % (resp, content))


def delete_object(swift_api_url, tenant_id, auth_token, container, object):
    #Delete a object for a given container and object name
    tenant_account = 'AUTH_' + tenant_id
    header = httplib2.Http(".cache")
    url = '%s%s/%s/%s' % (swift_api_url, tenant_account, container, object)
    resp, content = header.request(url, "DELETE", body='',
                                   headers={"Content-Type": "application/json",
                                            "Content-Length": "0",
                                            "X-Auth-Token": auth_token})
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        print "Deleted Object %s" % object
        return resp, content
    else:
        raise NameError("Unable to delete the object: resp %s content %s" \
                        % (resp, content))


def list_objects(swift_api_url, tenant_id, auth_token, container):
    #Get all objects for a given container Query options:
    tenant_account = 'AUTH_' + tenant_id
    header = httplib2.Http(".cache")
    url = '%s%s/%s' % (swift_api_url, tenant_account, container)
    resp, content = header.request(url, "GET", body='',
                                   headers={"Content-Type": "application/json",
                                            "Content-Length": "0",
                                            "X-Auth-Token": auth_token})
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        print "Object List : %s" % content
        return resp, content
    else:
        raise NameError("Unable to list objects: resp %s content %s" \
                        % (resp, content))


def upload_object(tenant_id, auth_token, container, object):
    tenant_account = 'AUTH_' + tenant_id
    header = httplib2.Http(".cache")
    url = '%s%s/%s/%s' % (swift_api_url, tenant_account, container, object)
    resp, content = header.request(url, "PUT", body='',
                                   headers={"Content-Type": "application/json",
                                            "Content-Length": "0",
                                            "X-Auth-Token": auth_token})
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        print "Uploaded object %s " % object
        return resp, content
    else:
        raise NameError("Unable to upload the object: resp %s content %s" \
                        % (resp, content))


class Keystone_Integration_Nova_TestCases(unittest.TestCase):

    def test_whenEmptyTokenRebootsAnyServer_throwsAnException(self):
        self.assertRaises(Exception, reboot_server, (TENANT_A,
                                                     ' ',
                                                     usera_server_id))
        self.assertRaises(Exception, reboot_server, (TENANT_B,
                                                     ' ',
                                                     userb_server_id))
        self.assertRaises(Exception, reboot_server, (TENANT_A,
                                                     ' ',
                                                     tenantadmin_server_id))

    def test_whenInvalidTokenRebootsAnyServer_throwsAnException(self):
        self.assertRaises(Exception, reboot_server, (TENANT_A,
                                                     '13abc',
                                                     usera_server_id))
        self.assertRaises(Exception, reboot_server, (TENANT_B,
                                                     'pqr78',
                                                     userb_server_id))
        self.assertRaises(Exception, reboot_server, (TENANT_A,
                                                     'vnn4684fjk52434543kjf',
                                                     tenantadmin_server_id))

    def test_whenEmptyTokenDeleteAnyServer_throwsAnException(self):
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_A,
                                                     ' ', usera_server_id))
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_B,
                                                     ' ', userb_server_id))
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_A,
                                                     ' ',
                                                     tenantadmin_server_id))

    def test_whenInvalidTokenDeleteAnyServer_throwsAnException(self):
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_A,
                                                     '13abc',
                                                     usera_server_id))
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_B,
                                                     'pqr28',
                                                     userb_server_id))
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_A,
                                                     'vnn4684fjk52434543kjf',
                                                     tenantadmin_server_id))

    def test_whenEmptyTokenGetServer_throwsAnException(self):
        self.assertRaises(Exception, get_servers, (nova_api_url, TENANT_A,
                                                   ' '))
        self.assertRaises(Exception, get_servers, (nova_api_url, TENANT_B,
                                                   ' '))

    def test_whenInvalidTokenGetServer_throwsAnException(self):
        self.assertRaises(Exception, get_servers, (nova_api_url, TENANT_A,
                                                  'abcd1234pqrs7890'))
        self.assertRaises(Exception, get_servers, (nova_api_url, TENANT_B,
                                                  'abcd1234pqrs7890'))

    def test_whenEmptyTokenCreateServer_throwsAnException(self):
        self.assertRaises(Exception, create_server, (TENANT_A,
                                                      'userAB_server', ' '))
        self.assertRaises(Exception, create_server, (TENANT_B,
                                                      'userAB_server', ' '))

    def test_whenInvalidTokenCreateServer_throwsAnException(self):
        self.assertRaises(Exception, create_server, (TENANT_A,
                                                     'userX_server', 'xyz123'))
        self.assertRaises(Exception, create_server, (TENANT_B,
                                                     'userX_server', 'xyz123'))
# Quota tests

    def test_whenAdminUserModifyQuotaOfAnyTenantByCorrectToken_Pass(self):
        resp = Modify_Quota_Value_instanceCount(TENANT_A, TENANT_A,
                                                tenantadmin_token, 20)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        self.assertRaises(Exception, Modify_Quota_Value_instanceCount,
                          (TENANT_A, TENANT_B, tenantadmin_token, 20))

    def test_whenNonAdminUserModifyQuotaOtherTenant_throwsAnException(self):
        self.assertRaises(Exception, Modify_Quota_Value_instanceCount,
                          (TENANT_B, TENANT_A, user_b_token, 20))
        self.assertRaises(Exception, Modify_Quota_Value_instanceCount,
                          (TENANT_B, TENANT_B, user_b_token, 20))
        self.assertRaises(Exception, Modify_Quota_Value_instanceCount,
                          (TENANT_B, TENANT_A, user_a_token, 20))
        self.assertRaises(Exception, Modify_Quota_Value_instanceCount,
                          (TENANT_B, TENANT_B, user_a_token, 20))

    def test_whenAdminUserModifyQuotaTenantEmptyToken_throwsAnException(self):
        self.assertRaises(Exception, Modify_Quota_Value_instanceCount,
                          (TENANT_A, TENANT_A, "", 20))
        self.assertRaises(Exception, Modify_Quota_Value_instanceCount,
                          (TENANT_A, TENANT_B, "", 20))

    def test_whenNonAdminUserModifyQuotaOtherTenant_throwsAnException(self):
        self.assertRaises(Exception, Modify_Quota_Value_instanceCount,
                          (TENANT_A, TENANT_A, user_a_token, 20))
        self.assertRaises(Exception, Modify_Quota_Value_instanceCount,
                          (TENANT_A, TENANT_B, user_a_token, 20))

#=============================

    def test_whenAdminUserRetrieveQuotaOfAnyTenantByCorrectToken_Pass(self):
        resp = get_quota_instance(TENANT_A, TENANT_A, tenantadmin_token)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        resp = get_quota_instance(TENANT_A, TENANT_A, user_a_token)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        resp = get_quota_instance(TENANT_B, TENANT_B, user_b_token)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        self.assertRaises(Exception, get_quota_instance, (TENANT_A, TENANT_B,
                                                          tenantadmin_token))

    def test_whenNonAdminUserRetrieveQuotaOfAnyTenant_throwsAnException(self):
        self.assertRaises(Exception, get_quota_instance, (TENANT_B, TENANT_A,
                                                          user_b_token))
        self.assertRaises(Exception, get_quota_instance, (TENANT_B, TENANT_A,
                                                          user_a_token))
        self.assertRaises(Exception, get_quota_instance, (TENANT_B, TENANT_B,
                                                          user_a_token))

#======end of Quota Test

    def test_Reboot_whenUseraRebootsUserbServer_throwsAnException(self):
        self.assertRaises(Exception, reboot_server, (TENANT_A, user_a_token,
                                                     userb_server_id))

    def test_Reboot_whenAdminUserRebootsUserbServer_throwsAnException(self):
        self.assertRaises(Exception, reboot_server, (TENANT_A,
                                                     tenantadmin_token,
                                                     userb_server_id))

    def test_Reboot_whenUserbRebootsUseraServer_throwsAnException(self):
        self.assertRaises(Exception, reboot_server, (TENANT_B, user_b_token,
                                                     usera_server_id))

    def test_Reboot_whenUserbRebootsAdminUserServer_throwsAnException(self):
        self.assertRaises(Exception, reboot_server, (TENANT_B, user_b_token,
                                                     tenantadmin_server_id))

#    def test_whenUseraRebootsUseraServer_pass(self):
#        """
#        This function test whether admin user and a member user can reboot the
#        instances of the users in the same tenant and other tenant
#        """
#        resp = reboot_server(TENANT_A, user_a_token, usera_server_id)
#        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

    def test_whenAdminUserRebootsUseraServer_pass(self):
        resp = reboot_server(TENANT_A, tenantadmin_token, usera_server_id)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

    def test_whenUseraRebootsAdminUserServer_pass(self):
        resp = reboot_server(TENANT_A, user_a_token, tenantadmin_server_id)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

#-----delete

    def test_whenUserbDeletesUseraServer_throwsAnException(self):
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_B,
                                                     user_b_token,
                                                     usera_server_id))

    def test_whenAdminUserDeleteUseraServer_pass(self):
        resp = delete_server(nova_api_url, TENANT_A, tenantadmin_token,
                             usera_server_id)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

    def test_whenUseraDeletesUserbServer_throwsAnException(self):
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_A,
                                                     user_a_token,
                                                     userb_server_id))

    def test_whenAdminUserDeletesUserbServer_throwsAnException(self):
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_A,
                                                     tenantadmin_token,
                                                     userb_server_id))

    def test_whenUserbDeleteUserbServer_pass(self):
        """
        This function test whether admin user and a member user can delete the
        instances of the users in the same tenant and other tenant
        """
        resp = delete_server(nova_api_url, TENANT_B, user_b_token,
                             userb_server_id)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

    def test_whenUserbDeletesAdminUserServer_throwsAnException(self):
        self.assertRaises(Exception, delete_server, (nova_api_url, TENANT_B,
                                                     user_b_token,
                                                     tenantadmin_server_id))

    def test_whenUseraDeleteAdminUserServer_pass(self):
        resp = delete_server(nova_api_url, TENANT_A, user_a_token,
                             tenantadmin_server_id)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])


class Keystone_Integration_Glance_TestCases(unittest.TestCase):

    def test_whenEmptyTokenCreatesImage_throwsAnException(self):
        self.assertRaises(Exception, post_images, ('', 'Image123', True))
        self.assertRaises(Exception, post_images, ('', 'Imagexyz', False))

    def test_whenInvalidTokenCreatesImage_throwsAnException(self):
        self.assertRaises(Exception, post_images, ('hfhefd', 'Image123', True))
        self.assertRaises(Exception, post_images, ('InvalidToken',
                                                    'Imagexyz', False))
#.......test:usera(tenanta)/userb(tenantb) on tenantadmin(tenanta)Public Image
#...Same Tenant....

    def test_whenUseraGetPublicImageofSameTenantUser_Pass(self):
        headers = {'X-Auth-Token': user_a_token}
        path = "%simages/%d" % (glance_api_url, tenantadmin_PublicImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)

    def test_whenUserbGetPublicImageofDiffTenantUser_Pass(self):
        headers = {'X-Auth-Token': user_b_token}
        path = "%simages/%d" % (glance_api_url, tenantadmin_PublicImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)

    def test_whenUseraViewPublicDetailImageofSameTenant_Pass(self):
        headers = {'X-Auth-Token': user_a_token,
                   'Content-Type': 'application/octet-stream'}
        path = "%simages/detail" % (glance_api_url)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)

    def test_whenUserbViewPublicDetailImageofDiffTenant_Pass(self):
        headers = {'X-Auth-Token': user_b_token,
                   'Content-Type': 'application/octet-stream'}
        path = "%simages/detail" % (glance_api_url)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)

    def test_whenUserAManipulatePublicImageofSameTenant_Pass(self):
        headers = {'X-Auth-Token': user_a_token,
                   'Content-Type': 'application/json',
                   'X-Image-Meta-Is-Public': 'False'}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PublicImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        self.assertEqual(data['image']['name'], "PublicImage1")
        self.assertEqual(data['image']['is_public'], False)
        self.assertEqual(data['image']['owner'], tenanta_id)
        headers = {'X-Auth-Token': user_a_token,
                   'Content-Type': 'application/json',
                   'X-Image-Meta-Is-Public': 'True'}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PublicImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        data = json.loads(content)
        self.assertEqual(data['image']['name'], "PublicImage1")
        self.assertEqual(data['image']['is_public'], True)
        self.assertEqual(data['image']['owner'], tenanta_id)

    def test_whenUserbManipulatePublicImageofDiffTenant_Error(self):
        headers = {'X-Auth-Token': user_b_token,
                   'Content-Type': 'application/json',
                   'X-Image-Meta-Is-Public': 'False'}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PublicImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        self.assertEqual(response.status, 404)

#.......test for usera(tenanta) and tenantadmin(tenanta) Private Image
#...Same Tenant....

    def test_whenUseraGetPrivateImageofSameTenantAUser_Pass(self):
        headers = {'X-Auth-Token': user_a_token}
        path = "%simages/%d" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)

#.......test for userb(tenantb) and tenantadmin(tenanta):Private Image...
#.......Different Tenants....

    def test_whenUserbGiveHimselfPermission_Error(self):
        headers = {'X-Auth-Token': user_b_token,
                   'X-Image-Meta-Is-Public': 'True'}
        path = "%simages/%d" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        self.assertEqual(response.status, 404)

    def test_whenUserbGiveHimselfOwnership_ErrorContentNotFound(self):
        headers = {'X-Auth-Token': user_b_token,
                   'X-Image-Meta-Owner': TENANT_B}
        path = "%simages/%d" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        self.assertEqual(response.status, 404)

    def test_whenUserbDeletesTenantAImage_ErrorContentNotFound(self):
        headers = {'X-Auth-Token':  user_b_token}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', headers=headers)
        self.assertEqual(response.status, 404)

    def test_whenTenantAdminViewItsImage_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token,
                   'Content-Type': 'application/octet-stream'}
        path = "%simages" % (glance_api_url)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == tenantadmin_PrivateImage_id:
                self.assertEqual(d['size'], FIVE_KB)
                self.assertEqual(d['name'], 'PrivateImage2')
                break

    def test_whenTenantAdminViewItsImageDetail_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token,
                   'Content-Type': 'application/octet-stream'}
        path = "%simages/detail" % (glance_api_url)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)

    def test_whenTenantAdminGetItsImageMetadata_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token,
                   'Content-Type': 'application/json'}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'HEAD', headers=headers)
        self.assertEqual(response.status, 200)
        self.assertEqual(response['x-image-meta-name'], "PrivateImage2")
        self.assertEqual(response['x-image-meta-is_public'], "False")
        self.assertEqual(response['x-image-meta-owner'], tenanta_id)

    def test_whenTenantAdminManipulateItsImage_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token,
                   'Content-Type': 'application/json',
                   'X-Image-Meta-Is-Public': 'True'}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        self.assertEqual(data['image']['name'], "PrivateImage2")
        self.assertEqual(data['image']['is_public'], True)
        self.assertEqual(data['image']['owner'], tenanta_id)
        #Now Userb can see the Image specifically
        headers = {'X-Auth-Token': user_b_token,
                   'Content-Type': 'application/json'}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        headers = {'X-Auth-Token': tenantadmin_token,
                   'Content-Type': 'application/json',
                   'X-Image-Meta-Is-Public': 'False'}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        self.assertEqual(data['image']['name'], "PrivateImage2")
        self.assertEqual(data['image']['is_public'], False)
        self.assertEqual(data['image']['owner'], tenanta_id)

#   def test_whenTenantAdminCantGiveImagetoUserB_Pass(self):
#        headers = {'X-Auth-Token': tenantadmin_token,
#                   'Content-Type': 'application/octet-stream',
#                   'X-Image-Meta-Owner': TENANT_B}
#        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
#        http = httplib2.Http()
#        response, content = http.request(path, 'PUT', headers=headers)
#        self.assertEqual(response.status, 404)
#        data = json.loads(content)
#        self.assertEqual(data['image']['name'], "PrivateImage2")
#        self.assertEqual(data['image']['is_public'], False)
#        self.assertEqual(data['image']['owner'], TENANT_B)

    def test_NowUserBViewPublicImageTenantA_Pass(self):
        headers = {'X-Auth-Token': user_b_token}
        path = "%simages" % (glance_api_url)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)

    def test_NowUserBViewPublicImageTenantADetail_Pass(self):
        headers = {'X-Auth-Token': user_b_token}
        path = "%simages/detail" % (glance_api_url)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)

    def test_whenUserBChangeIsPublic_Error(self):
        headers = {'X-Auth-Token': user_b_token,
                   'X-Image-Meta-Is-Public': 'True'}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        self.assertEqual(response.status, 404)

    def test_NowUserBgiveHimselfOwnership_Error(self):
        headers = {'X-Auth-Token': user_b_token,
                   'X-Image-Meta-Owner': USER_B}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        self.assertEqual(response.status, 404)

    def test_whenUserBDeletesOtherTenantImage_Error(self):
        headers = {'X-Auth-Token': user_b_token}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', headers=headers)
        self.assertEqual(response.status, 404)

    def test_whenAdminUserCanNOTViewPrivateImageDefault_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token}
        path = "%simages" % (glance_api_url)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateImage_id:
                i = 1
                break
            else:
                i = None
                self.assertEqual(i, None)

        # Admin should see the image if we're looking for private
        # images specifically
    def test_whenAdminUserGetPrivateImageUsera_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token}
        path = "%simages?is_public=false" % (glance_api_url)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)

        for d in data['images']:
            if d['id'] == usera_PrivateImage_id:
                break
        if d != None:
            self.assertEqual(d['id'], usera_PrivateImage_id)
            self.assertEqual(d['size'], FIVE_KB)
            self.assertEqual(d['name'], "PrivateImage3")

    def test_whenAdminUserGetPrivateImageDetailUsera_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token}
        path = ("%simages/detail?is_public=false" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateImage_id:
                break
        if d != None:
            self.assertEqual(d['id'], usera_PrivateImage_id)
            self.assertEqual(d['size'], FIVE_KB)
            self.assertEqual(d['name'], "PrivateImage3")
            self.assertEqual(d['is_public'], False)
            self.assertEqual(d['owner'], tenanta_id)

    def test_whenAdminUserGetPrivateImageMetadataUsera_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token}
        path = ("%simages/%d" % (glance_api_url, usera_PrivateImage_id))
        http = httplib2.Http()
        response, content = http.request(path, 'HEAD', headers=headers)
        self.assertEqual(response.status, 200)
        self.assertEqual(response['x-image-meta-name'], "PrivateImage3")
        self.assertEqual(response['x-image-meta-is_public'], "False")
        self.assertEqual(response['x-image-meta-owner'], tenanta_id)

    def test_whenAdminUserManipulatePrivateImageUsera_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token,
                   'X-Image-Meta-Is-Public': 'True',
                   'X-Image-Meta-Owner': TENANT_B}
        path = ("%simages/%s" % (glance_api_url, usera_PrivateImage_id))
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        self.assertEqual(data['image']['name'], "PrivateImage3")
        self.assertEqual(data['image']['is_public'], True)
#        self.assertEqual(data['image']['owner'], TENANT_B)

        headers = {'X-Auth-Token': tenantadmin_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateImage_id:
                break

        if d != None:
            self.assertEqual(d['id'], usera_PrivateImage_id)
            self.assertEqual(d['size'], FIVE_KB)
            self.assertEqual(d['name'], "PrivateImage3")

    def test_whenAdminUserNOTViewPrivateImageDefault_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token}
        path = "%simages" % (glance_api_url)
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == userb_PrivateImage_id:
                i = 1
                break
            else:
                i = None
        self.assertEqual(i, None)
        # Admin should see the image if we're looking for private
        # images specifically

    def test_whenAdminUserGetPrivateImageUserb_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token}
        path = ("%simages/detail?is_public=false" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == userb_PrivateImage_id:
                self.assertEqual(d['size'], FIVE_KB)
                self.assertEqual(d['name'], "PrivateImage5")
                self.assertEqual(d['is_public'], False)
                self.assertEqual(d['owner'], tenantb_id)
                break

    def test_whenUserASharePrivateImageUserb_Pass(self):
        headers = {'X-Auth-Token': user_a_token}
        body = json.dumps({'memberships': [{'member_id': tenantb_id,
                                            'can_share': True}]})
        path = "%simages/%s/members" % \
                (glance_api_url, usera_PrivateSharedImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', body=body,
                                   headers=headers)
        self.assertEqual(response.status, 204)

    def test_whenUserAViewItsSharePrivateImage_Pass(self):
        headers = {'X-Auth-Token': user_a_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                self.assertEqual(d['size'], FIVE_KB)
                self.assertEqual(d['name'], "PrivateSharedImage3")
                break

    def test_UserBNowViewUserASharePrivateImage_Pass(self):
        headers = {'X-Auth-Token': user_b_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                self.assertEqual(d['size'], FIVE_KB)
                self.assertEqual(d['name'], "PrivateSharedImage3")
                break

    def test_whenAdminUserViewSharePrivateImageSameTenant_Pass(self):
        headers = {'X-Auth-Token': tenantadmin_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                self.assertEqual(d['size'], FIVE_KB)
                self.assertEqual(d['name'], "PrivateSharedImage3")
                break

    def test_whenUserB1CantViewSharePrivateImageDiffTenantButMember_Pass(self):
        headers = {'X-Auth-Token': user_b1_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                self.assertEqual(d['size'], FIVE_KB)
                self.assertEqual(d['name'], "PrivateSharedImage3")
                i = 1
                break
            else:
                i = None
        self.assertNotEqual(i, None)

    def test_whenUserCViewSharePrivateImageDiffTenantNoMember_Error(self):
        headers = {'X-Auth-Token': user_c_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                i = 1
                break
            else:
                i = None
        self.assertEqual(i, None)

        headers = {'X-Auth-Token': user_a_token}
        path = "%simages/%s/members/%s" % \
                (glance_api_url, usera_PrivateSharedImage_id, TENANT_C)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', body='',
                                   headers=headers)
        self.assertEqual(response.status, 204)

        headers = {'X-Auth-Token': user_c_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                self.assertEqual(d['size'], FIVE_KB)
                self.assertEqual(d['name'], "PrivateSharedImage3")
                break

    def test_whenUseraReplaceMemberSharedImage_Pass(self):
        headers = {'X-Auth-Token': user_a_token}
        body = json.dumps({'memberships': [{'member_id': tenantc_id,
                                            'can_share': False}]})
        path = "%simages/%s/members" % \
                (glance_api_url, usera_PrivateSharedImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', body=body,
                                   headers=headers)
        self.assertEqual(response.status, 204)

        #Now user B cannot see the image
        headers = {'X-Auth-Token': user_b_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                i = 1
                break
            else:
                i = None
        self.assertEqual(i, None)

    def test_whenUserBRemovesMemberTenantC_Error(self):
        headers = {'X-Auth-Token': user_a_token}
        body = json.dumps({'memberships': [{'member_id': tenantc_id,
                                            'can_share': True}]})
        path = "%simages/%s/members" % \
                (glance_api_url, usera_PrivateSharedImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', body=body,
                                   headers=headers)
        self.assertEqual(response.status, 204)

        headers = {'X-Auth-Token': user_a_token}
        body = json.dumps({'memberships': [{'member_id': tenantb_id,
                                            'can_share': True}]})
        path = "%simages/%s/members" % \
                (glance_api_url, usera_PrivateSharedImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', body=body,
                                   headers=headers)
        self.assertEqual(response.status, 204)

        headers = {'X-Auth-Token': user_b_token}
        path = "%simages/%s/members/%s" % \
                (glance_api_url, usera_PrivateSharedImage_id, tenantc_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', body='',
                                   headers=headers)
        self.assertEqual(response.status, 204)

        headers = {'X-Auth-Token': user_c_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                i = 1
                break
            else:
                i = None
        self.assertEqual(i, None)

    def test_whenUserBRemovesMemberTenantA_Pass(self):
        headers = {'X-Auth-Token': user_b_token}
        path = "%simages/%s/members/%s" % \
                (glance_api_url, usera_PrivateSharedImage_id, tenanta_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', body='',
                                   headers=headers)
        self.assertEqual(response.status, 204)
        #User A can see the image as it is owned by it...
        headers = {'X-Auth-Token': user_a_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                i = 1
                break
            else:
                i = None
        self.assertNotEqual(i, None)

    def test_whenUserCRemovesMemberTenantB_Pass(self):
        headers = {'X-Auth-Token': user_a_token}
        body = json.dumps({'memberships': [{'member_id': tenantb_id,
                                            'can_share': True}]})
        path = "%simages/%s/members" % \
                (glance_api_url, usera_PrivateSharedImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', body=body,
                                   headers=headers)
        self.assertEqual(response.status, 204)

        headers = {'X-Auth-Token': user_a_token}
        body = json.dumps({'memberships': [{'member_id': tenantc_id,
                                            'can_share': True}]})
        path = "%simages/%s/members" % \
                (glance_api_url, usera_PrivateSharedImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'PUT', body=body,
                                   headers=headers)
        self.assertEqual(response.status, 204)

        headers = {'X-Auth-Token': user_c_token}
        path = "%simages/%s/members/%s" % \
                (glance_api_url, usera_PrivateSharedImage_id, tenantb_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', body='',
                                   headers=headers)
        self.assertEqual(response.status, 204)

        headers = {'X-Auth-Token': user_b_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                i = 1
                break
            else:
                i = None
        self.assertEqual(i, None)

        headers = {'X-Auth-Token': user_a_token}
        path = "%simages/%s/members/%s" % \
                (glance_api_url, usera_PrivateSharedImage_id, tenantc_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', body='',
                                   headers=headers)
        self.assertEqual(response.status, 204)

        headers = {'X-Auth-Token': user_c_token}
        path = ("%simages" % (glance_api_url))
        http = httplib2.Http()
        response, content = http.request(path, 'GET', headers=headers)
        self.assertEqual(response.status, 200)
        data = json.loads(content)
        for d in data['images']:
            if d['id'] == usera_PrivateSharedImage_id:
                i = 1
                break
            else:
                i = None
        self.assertEqual(i, None)


class Keystone_Integration_Swift_TestCases(unittest.TestCase):

    def test_whenEmptyTokenCreateContainer_throwsAnException(self):
        self.assertRaises(Exception, create_container, (tenanta_id, ' ',
                                                        'containerA'))
        self.assertRaises(Exception, create_container, (tenantb_id, ' ',
                                                        'containerB'))

    def test_whenInvalidTokenCreateContainer_throwsAnException(self):
        self.assertRaises(Exception, create_container, (tenanta_id,
                                                        'InvalidToken',
                                                        'containerA'))
        self.assertRaises(Exception, create_container, (tenantb_id,
                                                        'InvalidToken',
                                                        'containerB'))

    def test_whenEmptyTokenListContainers_throwsAnException(self):
        self.assertRaises(Exception, list_containers, (swift_api_url,
                                                       tenanta_id,
                                                        ' '))
        self.assertRaises(Exception, list_containers, (swift_api_url,
                                                       tenantb_id, ' '))

    def test_whenInvalidTokenListContainers_throwsAnException(self):
        self.assertRaises(Exception, list_containers, (swift_api_url,
                                                       tenanta_id,
                                                       'InvalidToken'))
        self.assertRaises(Exception, list_containers, (swift_api_url,
                                                       tenantb_id,
                                                       'InvalidToken'))

    def test_whenEmptyTokenDeleteContainer_throwsAnException(self):
        self.assertRaises(Exception, delete_container, (swift_api_url,
                                                        tenanta_id, ' ',
                                                        'containerA'))
        self.assertRaises(Exception, delete_container, (swift_api_url,
                                                        tenantb_id, ' ',
                                                        'containerB'))

    def test_whenInvalidTokenDeleteContainer_throwsAnException(self):
        self.assertRaises(Exception, delete_container, (swift_api_url,
                                                        tenanta_id,
                                                        'InvalidToken',
                                                        'containerA'))
        self.assertRaises(Exception, delete_container, (swift_api_url,
                                                        tenantb_id,
                                                        'InvalidToken',
                                                        'containerB'))

    def test_whenEmptyTokenUploadobject_throwsAnException(self):
        self.assertRaises(Exception, upload_object, (tenanta_id, ' ',
                                                     'containerA', 'objectA'))
        self.assertRaises(Exception, upload_object, (tenantb_id, ' ',
                                                     'containerB', 'objectB'))

    def test_whenInvalidTokenUploadobject_throwsAnException(self):
        self.assertRaises(Exception, upload_object, (tenanta_id,
                                                     'InvalidToken',
                                                     'containerA', 'objectA'))
        self.assertRaises(Exception, upload_object, (tenantb_id,
                                                     'InvalidToken',
                                                     'containerB', 'objectB'))

    def test_whenEmptyTokenListobject_throwsAnException(self):
        self.assertRaises(Exception, list_objects, (swift_api_url, tenanta_id,
                                                    ' ',
                                                    'containerA'))
        self.assertRaises(Exception, list_objects, (swift_api_url, tenantb_id,
                                                    ' ',
                                                    'containerB'))

    def test_whenInvalidTokenListobject_throwsAnException(self):
        self.assertRaises(Exception, list_objects, (swift_api_url, tenanta_id,
                                                    'InvalidToken',
                                                     'containerA'))
        self.assertRaises(Exception, list_objects, (swift_api_url, tenantb_id,
                                                    'InvalidToken',
                                                     'containerB'))

    def test_whenEmptyTokenDeleteObject_throwsAnException(self):
        self.assertRaises(Exception, delete_object, (swift_api_url,
                                                     tenanta_id, ' ',
                                                     'containerA', 'objectA'))
        self.assertRaises(Exception, delete_object, (swift_api_url,
                                                     tenantb_id, ' ',
                                                     'containerB', 'objectB'))

    def test_whenInvalidTokenDeletObject_throwsAnException(self):
        self.assertRaises(Exception, delete_object, (swift_api_url,
                                                     tenanta_id,
                                                     'InvalidToken',
                                                     'containerA', 'objectA'))
        self.assertRaises(Exception, delete_object, (swift_api_url,
                                                     tenantb_id,
                                                     'InvalidToken',
                                                     'containerB', 'objectB'))
#------------------------------

    def test_AdminUserCanlistDiffTenantUserContainer_Error(self):
        self.assertRaises(Exception, list_containers, (swift_api_url,
                                                       tenantb_id,
                                                       tenantadmin_token))

    def test_AdminUserCanlistSameTenantUserContainer_Pass(self):
        resp, content = list_containers(swift_api_url, tenanta_id,
                                        tenantadmin_token)
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        data = content.split('\n')
        self.assertIn('containerA1', data)

    def test_AdminUserCanlistSameTenantObject_Pass(self):
        resp, content = list_objects(swift_api_url, tenanta_id,
                                     tenantadmin_token, 'containerA1')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        data = content.split('\n')
        self.assertIn('objectA1', data)

    def test_AdminUserCanlistDiffTenantObject_Error(self):
        self.assertRaises(Exception, list_objects, (swift_api_url, tenantb_id,
                                        tenantadmin_token, 'containerB'))

#---------------------

    def test_AdminUserCreateSameTenantContainer_Pass(self):
        resp, content = create_container(tenanta_id, tenantadmin_token,
                                         'newcontainerA')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        resp, content = list_containers(swift_api_url, tenanta_id,
                                        tenantadmin_token)
        data = content.split('\n')
        self.assertIn('newcontainerA', data)
        delete_container(swift_api_url, tenanta_id, tenantadmin_token,
                         'newcontainerA')

    def test_AdminUserCreateDiffTenantUserContainer_Fail(self):
        self.assertRaises(Exception, create_container, (tenantb_id,
                                                        tenantadmin_token,
                                                        'newcontainerA2'))

    def test_AdminUserUploadSameTenantObject_Pass(self):
        resp, content = upload_object(tenanta_id, tenantadmin_token,
                                      'containerA1', 'newobjectA')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        resp, content = list_objects(swift_api_url, tenanta_id,
                                     tenantadmin_token,
                                     'containerA1')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        data = content.split('\n')
        self.assertIn('newobjectA', data)
        delete_object(swift_api_url, tenanta_id, tenantadmin_token,
                      'containerA1', 'newobjectA')

    def test_AdminUserUploadDiffTenantObject_Error(self):
        self.assertRaises(Exception, upload_object, (tenantb_id,
                                                     tenantadmin_token,
                                                     'containerB',
                                                     'newobjectA2'))

#--------------------------

    def test_AdminUserCanDeleteSameTenantUserContainer_Pass(self):
        resp, content = create_container(tenanta_id, user_a_token,
                                         'tempcontainer')
        resp, content = delete_container(swift_api_url, tenanta_id,
                                         tenantadmin_token, 'tempcontainer')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

    def test_AdminUserCanDeleteDiffTenantUserContainer(self):
        resp, content = create_container(tenantb_id, user_b_token,
                                         'tempcontainer')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        self.assertRaises(Exception, delete_container, (swift_api_url,
                                                        tenantb_id,
                                                        tenantadmin_token,
                                                        'tempcontainer'))
        resp, content = delete_container(swift_api_url, tenantb_id,
                                         user_b_token, 'tempcontainer')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

    def test_AdminUserCanDeleteSameTenantObject(self):
        resp, content = upload_object(tenanta_id, user_a_token, 'containerA1',
                                      'tempobject')
        resp, content = delete_object(swift_api_url, tenanta_id,
                                      tenantadmin_token, 'containerA1',
                                      'tempobject')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

    def test_AdminUserCanDeleteUpdateDiffTenantObject(self):
        resp, content = upload_object(tenantb_id, user_b_token,
                                      'containerB', 'tempobject')
        self.assertRaises(Exception, delete_object, (swift_api_url,
                                                        tenantb_id,
                                                        tenantadmin_token,
                                                        'containerB',
                                                        'tempobject'))
        resp, content = delete_object(swift_api_url, tenantb_id,
                                         user_b_token, 'containerB',
                                         'tempobject')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

#------------------------------for userA (Member)
#------------------------------

    def test_MemberUserACanlistDiffTenantUserContainer_Error(self):
        self.assertRaises(Exception, list_containers, (swift_api_url,
                                                       tenantb_id,
                                                       user_a_token))

#    def test_MemberUserAlistSameTenantAdminUserContainer_Fail(self):
#        resp, content = list_containers(swift_api_url, tenanta_id,
#                                        user_a_token)
#        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
#        print "UserA has Member Role....Cannot list Admin containers"
#        data = content.split('\n')
#        self.assertNotIn('containerA2', data)

    def test_MemberUserAlistSameTenantAdminUsersObject_Fail(self):
        self.assertRaises(Exception, list_objects, (swift_api_url, tenanta_id,
                                                    user_a_token,
                                                    'containerA2'))

    def test_MemberUserAlistDiffTenantObject_Error(self):
        self.assertRaises(Exception, list_objects, (swift_api_url, tenantb_id,
                                                    user_a_token,
                                                    'containerB'))
#---------------------

    def test_MemberUserACreateSameTenantContainer_Pass(self):
        resp, content = create_container(tenanta_id, user_a_token,
                                         'newcontainerA1')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        resp, content = list_containers(swift_api_url, tenanta_id,
                                        user_a_token)
        data = content.split('\n')
        self.assertIn('newcontainerA1', data)
        delete_container(swift_api_url, tenanta_id, user_a_token,
                         'newcontainerA1')

    def test_MemberUserACreateDiffTenantUserContainer_Fail(self):
        self.assertRaises(Exception, create_container, (tenantb_id,
                                                        user_a_token,
                                                        'newcontainerA2'))

    def test_MemberUserAUploadSameTenantAdminObject_Fail(self):
        self.assertRaises(Exception, upload_object, (tenanta_id, user_a_token,
                                                     'containerA2',
                                                     'newobjectA2'))

    def test_MemberUserAUploadDiffTenantObject_Error(self):
        self.assertRaises(Exception, upload_object, (tenantb_id,
                                                     user_a_token,
                                                     'containerB',
                                                     'newobjectA2'))

#--------------------------

    def test_MemberUserADeleteSameTenantAdminUserContainer_Fail(self):
        resp, content = create_container(tenanta_id, tenantadmin_token,
                                         'tempcontainer')
        self.assertRaises(Exception, delete_container, (swift_api_url,
                                                      tenanta_id, user_a_token,
                                                      'tempcontainer'))

    def test_MemberUserADeleteDiffTenantUserContainer_Fail(self):
        resp, content = create_container(tenantb_id, user_b_token,
                                         'tempcontainer')
        self.assertRaises(Exception, delete_container, (swift_api_url,
                                                        tenantb_id,
                                                        user_a_token,
                                                        'tempcontainer'))
        resp, content = delete_container(swift_api_url, tenantb_id,
                                         user_b_token, 'tempcontainer')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

#    def test_MemberUserADeleteSameTenantAdminObject(self):
#        resp, content = upload_object(tenanta_id, tenantadmin_token,
#                                      'containerA2',
#                                      'tempobject123')
#        print "Upload response: %s" % int(resp['status'])
#        resp, content = delete_object(swift_api_url, tenanta_id, user_a_token,
#                                      'containerA2', 'tempobject123')
#        print "1. Delete response: %s" % int(resp['status'])
#        self.assertNotIn(int(resp['status']), [200, 201, 202, 203, 204])
#        resp, content = delete_object(swift_api_url, tenanta_id,
#                                      tenantadmin_token,
#                                      'containerA2',
#                                      'tempobject123')
#        print "2. Delete response: %s" % int(resp['status'])
#        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

    def test_MemberUserADeleteDiffTenantObject(self):
        resp, content = upload_object(tenantb_id, user_b_token,
                                      'containerB', 'tempobject')
        self.assertRaises(Exception, delete_object, (swift_api_url,
                                                        tenantb_id,
                                                        user_a_token,
                                                        'containerB',
                                                        'tempobject'))
        resp, content = delete_object(swift_api_url, tenantb_id, user_b_token,
                                      'containerB', 'tempobject')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])


#-----------------------------
#tenantA create containerA1 and upload an objectA1 using tenantadmin token
# tenantA create containerA2 and upload an objectA2 using userA token
#  - test whether tenantadmin can
#   --update/create/list/delete containerA1
#   --update/create/list/delete containerA2
#   --update/list/delete objectA1
#   --update/list/delete objectA2
#  - test whether userA can
#   --update/list/delete containerA1
#   --update/list/delete containerA2
#   --update/list/delete objectA1
#   --update/list/delete objectA2
#  - test whether userB can
#   --update/list/delete containerA1
#   --update/list/delete containerA2
#   --update/list/delete objectA1
#   --update/list/delete objectA2
#tenantB create containerB1 and upload an objectB1 using userB token
#tenantB create containerB2 and upload an objectB2 using userB1 token
#     - test whether admin user can
#   --update/list/delete containerB1
#   --update/list/delete containerB2
#   --update/list/delete objectB1
#   --update/list/delete objectB2
#Tests are Remaining for swift...
class TestCleanup(unittest.TestCase):

    def test_cleanup_users(self):
        headers = {'X-Auth-Token': tenantadmin_token}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PublicImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', headers=headers)
        self.assertEqual(response.status, 200)

        headers = {'X-Auth-Token': tenantadmin_token}
        path = "%simages/%s" % (glance_api_url, usera_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', headers=headers)
        self.assertEqual(response.status, 200)

        headers = {'X-Auth-Token': user_b_token}
        path = "%simages/%s" % (glance_api_url, userb_PublicImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', headers=headers)
        self.assertEqual(response.status, 200)

        headers = {'X-Auth-Token': user_b_token}
        path = "%simages/%s" % (glance_api_url, userb_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', headers=headers)
        self.assertEqual(response.status, 200)

        headers = {'X-Auth-Token': user_a_token}
        path = "%simages/%s" % (glance_api_url, usera_PrivateSharedImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', headers=headers)
        self.assertEqual(response.status, 200)

        headers = {'X-Auth-Token': tenantadmin_token}
        path = "%simages/%s" % (glance_api_url, tenantadmin_PrivateImage_id)
        http = httplib2.Http()
        response, content = http.request(path, 'DELETE', headers=headers)
        self.assertEqual(response.status, 200)
        print 'Deleted all the images...'

        resp, content = delete_object(swift_api_url, tenanta_id, user_a_token,
                                      'containerA1', 'objectA1')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

        resp, content = delete_object(swift_api_url, tenanta_id,
                                      tenantadmin_token,
                                      'containerA2', 'objectA2')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

        resp, content = delete_object(swift_api_url, tenantb_id, user_b_token,
                                      'containerB', 'objectB1')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

        resp, content = delete_container(swift_api_url, tenanta_id,
                                         user_a_token, 'containerA1')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

        resp, content = delete_container(swift_api_url, tenanta_id,
                                         tenantadmin_token, 'containerA2')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])

        resp, content = delete_container(swift_api_url, tenantb_id,
                                         user_b_token, 'containerB')
        self.assertIn(int(resp['status']), [200, 201, 202, 203, 204])
        print 'Deleted Containers and Objects...'

        utils.delete_user(usera_id, ADMIN_AUTH_TOKEN, keystone_api_url)
        utils.delete_user(userb_id, ADMIN_AUTH_TOKEN, keystone_api_url)
        utils.delete_user(userb1_id, ADMIN_AUTH_TOKEN, keystone_api_url)
        utils.delete_user(userc_id, ADMIN_AUTH_TOKEN, keystone_api_url)
        utils.delete_user(tenantadmin_id, ADMIN_AUTH_TOKEN, keystone_api_url)
        utils.delete_tenant(tenanta_id, ADMIN_AUTH_TOKEN, keystone_api_url)
        utils.delete_tenant(tenantb_id, ADMIN_AUTH_TOKEN, keystone_api_url)
        utils.delete_tenant(tenantc_id, ADMIN_AUTH_TOKEN, keystone_api_url)
        print 'Deleted Users and Tenants...'

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print "Test didn't receive API Urls.Exiting from the Integration Test"
        exit()

    nova_api_url = sys.argv[1] + "/v1.1/"
    keystone_api_url = sys.argv[2] + "/v2.0/"
    glance_api_url = sys.argv[3] + "/v1/"
    swift_api_url = sys.argv[4] + "/v1/"
    #1. setting up the tenants and users.
    #utils.setup_keystone_urls(url)
    #fixing the api urls
    #utils.setup_keystone_url(sys.argv[2])
    #nova_api_url = sys.argv[1] + "/v1.0/"
    print "Setting up Tenants and Users..."
    setup_tenants_users()

    tenanta_id, usera_id = utils.get_usrandtenant_id(USER_A, USER_A,
                                                     keystone_api_url)
    tenantb_id, userb_id = utils.get_usrandtenant_id(USER_B, USER_B,
                                                     keystone_api_url)
    tenantb_id, userb1_id = utils.get_usrandtenant_id(USER_B1, USER_B1,
                                                keystone_api_url)
    tenantc_id, userc_id = utils.get_usrandtenant_id(USER_C, USER_C,
                                               keystone_api_url)
    tenanta_id, tenantadmin_id = utils.get_usrandtenant_id(TENANT_ADMIN,
                                                     TENANT_ADMIN,
                                                     keystone_api_url)
    print "tenanta_id : %s, tenantb_id : %s, tenantc_id : %s,\n"\
     "usera_id : %s, userb_id : %s, userb1_id : %s, userc_id : %s, "\
     "tenantadmin_id : %s " % (tenanta_id, tenantb_id, tenantc_id,
                               usera_id, userb_id, userb1_id, userc_id,
                               tenantadmin_id)
    #cleanup_users()

    print "Authenticating Users and getting Tokens..."
    user_a_token = authenticate_user(USER_A, USER_A)
    user_b_token = authenticate_user(USER_B, USER_B)
    user_b1_token = authenticate_user(USER_B1, USER_B1)
    user_c_token = authenticate_user(USER_C, USER_C)
    tenantadmin_token = authenticate_user(TENANT_ADMIN, TENANT_ADMIN)
    print " user_a_tokenv = %s \n user_b_token=%s \n user_b1_token=%s \n"\
    " user_c_token=%s \n tenantadmin_token=%s" \
    % (user_a_token, user_b_token, user_b1_token, user_c_token,
       tenantadmin_token)

    resp, content = create_server(TENANT_A, "usera_server", user_a_token)

    if int(resp['status']) in [200, 201, 202, 203, 204]:
        usera_server_id = content['server']['id']
    else:
        print "Unable to create the server  , Response =%s Server Resp: %s"\
         % (resp, content)
        raise NameError("Unable to create the Server")
    "tenantadmin_server"
    #verifying status of the build
    while not is_server_build(TENANT_A, usera_server_id, user_a_token):
        time.sleep(60)

    print "usera_server is ACTIVE now"
    resp, content = create_server(TENANT_A, "tenantadmin_server",
                                  tenantadmin_token)
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        tenantadmin_server_id = content['server']['id']
    else:
        print "Unable to create the server  , Response =%s Server"
        "Resp : %s" % (resp, content)
        raise NameError("Unable to create the Server")

    while not is_server_build(TENANT_A, tenantadmin_server_id, tenantadmin_token):
        time.sleep(60)

    print "tenantadmin_server is ACTIVE now"
    resp, content = create_server(TENANT_B, "userb_server",
                                              user_b_token)
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        userb_server_id = content['server']['id']
    else:
        print "Unable to create the server  , Response =%s \
        Server Resp : %s" % (resp, content)
        raise NameError("Unable to create the Server")

    while not is_server_build(TENANT_B, userb_server_id, user_b_token):
        time.sleep(60)
    print "userb_server is ACTIVE now"

    print "Uploading Images for Glance test..."
    resp, content = post_images(tenantadmin_token, 'PublicImage1', 'True',
                                tenanta_id)
    print "Response is  %s " % (resp['status'])
    content = json.loads(content)
    tenantadmin_PublicImage_id = content['image']['id']
    print "tenantadmin_PublicImage_id : %s" % tenantadmin_PublicImage_id

    resp, content = post_images(tenantadmin_token, 'PrivateImage2', 'False',
                                tenanta_id)

    print "Response is  %s " % (resp['status'])
    content = json.loads(content)
    tenantadmin_PrivateImage_id = content['image']['id']
    print "tenantadmin_PrivateImage_id : %s" % tenantadmin_PrivateImage_id

    resp, content = post_images(user_a_token, 'PrivateSharedImage3', 'False',
                                 tenanta_id)
    print "Response is  %s " % (resp['status'])
    content = json.loads(content)
    usera_PrivateSharedImage_id = content['image']['id']
    print "usera_PrivateSharedImage_id: %s" % usera_PrivateSharedImage_id

    resp, content = post_images(user_a_token, 'PrivateImage3', 'False',
                                tenanta_id)
    print "Response is  %s " % (resp['status'])
    content = json.loads(content)
    usera_PrivateImage_id = content['image']['id']
    print "usera_PrivateImage_id: %s" % usera_PrivateImage_id

    resp, content = post_images(user_b_token, 'PubicImage4', 'True',
                                tenantb_id)
    print "Response is  %s " % (resp['status'])
    content = json.loads(content)
    userb_PublicImage_id = content['image']['id']
    print"userb_PublicImage_id: %s" % userb_PublicImage_id

    resp, content = post_images(user_b_token, 'PrivateImage5', 'False',
                                 tenantb_id)
    content = json.loads(content)
    print "Response is  %s" % (resp['status'])
    userb_PrivateImage_id = content['image']['id']
    print"userb_PrivateImage_id: %s" % userb_PrivateImage_id

    create_container(tenanta_id, user_a_token, 'containerA1')
    create_container(tenanta_id, tenantadmin_token, 'containerA2')
    upload_object(tenanta_id, user_a_token, 'containerA1', 'objectA1')
    upload_object(tenanta_id, tenantadmin_token, 'containerA2', 'objectA2')
    create_container(tenantb_id, user_b_token, 'containerB')
    upload_object(tenantb_id, user_b_token, 'containerB', 'objectB1')

    unittest.main(argv=[sys.argv[0]])
