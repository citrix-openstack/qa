#!/bin/bash
set -eux


sshpass -pubuntu ubuntu@copper.eng.hq.xensource.com << EOF
set -eux
cd /usr/share/nginx/www
/usr/bin/wget -m -np -nH -q "http://coltrane.eng.hq.xensource.com/release/XenServer-6.x/XS-6.1/RTM/xe-phase-1/"
/usr/bin/wget -m -np -nH -q "http://coltrane.eng.hq.xensource.com/release/XenServer-6.x/XS-6.2/RTM-70446/xe-phase-1/"
/usr/bin/wget -m -np -nH -q "http://coltrane.eng.hq.xensource.com/usr/groups/build/clearwater-lcm/xe-phase-3-latest/xe-phase-1/"
/usr/bin/wget -m -np -nH -q "http://www.uk.xensource.com/linux/distros/CentOS/6.4/os/x86_64/"
EOF
