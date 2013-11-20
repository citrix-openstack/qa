#!/bin/bash +x

# Set up a Fedora cloud image to serve video files

echo proxy=http://10.0.0.3:3128/ >> /etc/yum.conf

yum install nginx
chkconfig nginx on
service nginx start

chkconfig iptables off
service iptables stop

sed -i 's/^PasswordAuthentication no/PasswordAuthentication yes/g' /etc/ssh/sshd_config
service sshd restart

export http_proxy=http://10.0.0.3:3128
curl -o /usr/share/nginx/html/the-xen-movie-android.mp4 http://copper.eng.hq.xensource.com/havana-demo/the-xen-movie-android.mp4
curl -o /usr/share/nginx/html/the-xen-movie-iphone.mp4 http://copper.eng.hq.xensource.com/havana-demo/the-xen-movie-iphone.mp4
curl -o /usr/share/nginx/html/the-xen-movie-ipod.mp4 http://copper.eng.hq.xensource.com/havana-demo/the-xen-movie-ipod.mp4

useradd -G wheel citrix
echo citrix | passwd citrix --stdin

