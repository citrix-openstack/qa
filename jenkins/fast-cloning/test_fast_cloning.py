"""Fast cloning test"""

import httplib
import httplib2
import sys
import json
import time


def _do_request(method, path, body=''):
    conn = httplib2.Http(".cache")
    url = '%s%s/%s' % (nova_api_url, tenant_id, path)
    resp, content = conn.request(url, method, body,
                                 headers={"Content-Type": "application/json",
                                          "X-Auth-Token":  auth_token})
    if int(resp['status']) in [200, 201, 202, 203, 204]:
        if content:
            content = json.loads(content)
        return content
    else:
        raise Exception('%s %s failed' % (method, path), resp, content)


def create_instance(server_name, image_ref, flavor_id):
    body = ('{"server": {"name": "%s", "imageRef": "%s", "flavorRef": "%d"}}'
        % (server_name, image_ref, flavor_id))
    content = _do_request('POST', 'servers', body)
    return content['server']['id']


def is_instance_active(server_id):
    content = _do_request('GET', 'servers/%s' % server_id)
    status = content['server']['status']
    if status == 'ACTIVE':
        return True
    elif status == 'ERROR':
        raise Exception('Instance went into ERROR state')
    else:
        return False


def delete_instance(server_id):
    _do_request('DELETE', 'servers/%s' % server_id)


def is_instance_deleted(server_id):
    content = _do_request('GET', 'servers')
    for server in content['servers']:
        if server['id'] == server_id:
           return False
    return True


def find_image(): 
    content = _do_request('GET', 'images')
    for image in content['images']:
        return image['id']
    raise Exception('Cannot find any images')


if __name__ == '__main__':
    if len(sys.argv) < 5:
        print("Test didn't receive all parameters."
                      " Exiting from the Fast cloning Test")
        sys.exit(1)

    nova_api_url = sys.argv[1] + "/v1.1/"
    number_of_instances = int(sys.argv[2])
    image_ref = sys.argv[3]
    flavor_id = int(sys.argv[4])
    timeout = 5
    instance_id_list = []
    total_launch_time = 0

    tenant_id="Administrator"
    auth_token="999888777666"

    if image_ref == '':
        # Need to determine the image_ref for ourselves.  Just take the
        # first one that we find.
        image_ref = find_image()

    # Launching multiple instances
    print "Number of instances to be launched is", number_of_instances
    for i in range(1, (number_of_instances + 1)):
        initial_time = time.time()
        instance_id = create_instance("useradmin_instance", image_ref,
                                      flavor_id)
        instance_id_list.append(instance_id)
        while True:
            try:
                if is_instance_active(instance_id):
                    break
            except httplib.BadStatusLine, exn:
                print "Warning: got BadStatusLine"
            time.sleep(timeout)
        final_time = time.time()
        if i is 1:
            first_launch_time = final_time - initial_time
        else:
            total_launch_time += (final_time - initial_time)
        print "Launched instance", instance_id, "in", \
                             (final_time - initial_time), "secs"

    # Deleting all instances
    for instance_id in instance_id_list:
        delete_instance(instance_id)
        while True:
            try:
                if is_instance_deleted(instance_id):
                    break
            except httplib.BadStatusLine, exn:
                print "Warning: got BadStatusLine"
            time.sleep(timeout)
        print "Deleted instance", instance_id

    # Measuring the difference between the time taken to launch an instance
    # for the first time and the average of the time taken to launch
    # the rest of the instances
    average_time = total_launch_time / (number_of_instances - 1)
    print "First instance launched in", first_launch_time
    print "Avg time to launch rest of the instances is", average_time
    if average_time < first_launch_time:
        sys.exit(0)
    else:
        print ("Time taken for launching first instance was less than the "
               "average time taken for rest of the instances.")
        sys.exit(2)
