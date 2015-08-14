#!/usr/bin/env python

import httplib
import traceback
import sys
import os
import XenAPI
import time

def import_raw_vdi(host, session, filename):
	if not os.path.exists(filename):
		return ['%s not found' % filename]

	import_task = None

	try:
		pool = session.xenapi.pool.get_all()[0]
		default_sr = session.xenapi.pool.get_default_SR(pool)
		sr = session.xenapi.SR.get_record(default_sr)

		vdi_spec = {
			'name_label': os.path.basename(filename),
			'name_description': 'Nova API plugin ISO',
			'SR': default_sr,
			'virtual_size': str(os.stat(filename).st_size),
			'type': 'user',
			'sharable': False,
			'read_only': False,
			'other_config': dict(),
		}
		vdi = session.xenapi.VDI.create(vdi_spec) 

		task_name = 'import ' + session.xenapi.VDI.get_uuid(vdi)
		import_task = session.xenapi.task.create(task_name, '')

		put_url = '/import_raw_vdi?session_id=%s&vdi=%s&task_id=%s' % \
			(session._session, vdi, import_task)

		with open(filename, 'rb') as f:
			content = f.read()
		conn = httplib.HTTPSConnection(host)
		conn.request('PUT', put_url, content)
		response = conn.getresponse()

		import_status = session.xenapi.task.get_status(import_task)
		timeout = 30
		while import_status == 'pending':
			print import_status, timeout
			"""TODO: loop 'pending', suspiciously a bug of XenServer that 
			could be fixed by installing SP1"""
			time.sleep(1)
			import_status = session.xenapi.task.get_status(import_task)
			timeout -= 1
			if timeout < 0:
				session.xenapi.task.cancel(import_task)
				break

		if import_status != 'success':
			error_info = session.xenapi.task.get_error_info(import_task)
			return error_info

	except Exception, e:
		traceback.print_exc()
		return e
	finally:
		if import_task is not None:
			session.xenapi.task.destroy(import_task)


if __name__ == '__main__':
	(host, username, password, filename,) = sys.argv[1:]
	
	session = XenAPI.Session('https://' + host) 
	session.xenapi.login_with_password(username, password)
	error_info = import_raw_vdi(host, session, filename)
	if error_info is not None:
		print ' '.join(error_info)
	else:
		print 'success'
	session.xenapi.logout()

