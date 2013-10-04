#!/bin/bash
set -eu

sed \
    -e 's,http://gold.eng.hq.xensource.com/git/internal/builds,https://github.com/citrix-openstack-build,g' \
    -e 's,git://gold.eng.hq.xensource.com/git/internal/builds,https://github.com/citrix-openstack-build,g'
