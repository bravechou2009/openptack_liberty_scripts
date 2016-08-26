#!/bin/bash
source net-config.cfg
source ~/admin-openrc.sh

echo "########## INSTALL CINDER ##########"
apt-get -y install cinder-api cinder-scheduler python-cinderclient

filename=/etc/cinder/cinder.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
rootwrap_config = /etc/cinder/rootwrap.conf
api_paste_confg = /etc/cinder/api-paste.ini

rpc_backend = rabbit
auth_strategy = keystone
my_ip = $MGMT_IP
glance_host = controller
verbose = True
lock_path = /var/lock/cinder

[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = $DEFAULT_PASS
 
[database]
connection = mysql+pymysql://cinder:$DEFAULT_PASS@controller/cinder
 
[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = cinder
password = $DEFAULT_PASS
EOF

chown cinder:cinder $filename

echo "##### DB SYNC #####"
cinder-manage db sync

rm -f /var/lib/cinder/cinder.sqlite

service cinder-scheduler restart
service cinder-api restart

exit 0