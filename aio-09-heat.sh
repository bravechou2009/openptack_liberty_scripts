#!/bin/bash
source aio-config.cfg
source ~/admin-openrc.sh

echo "########## INSTALL HEAT  ##########"
apt-get -y install heat-api heat-api-cfn heat-engine python-heatclient

filename=/etc/heat/heat.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
## refer
## http://docs.openstack.org/liberty/install-guide-ubuntu/heat-install.html
[DEFAULT]
verbose = True
rpc_backend = rabbit
heat_metadata_server_url = http://controller:8000
heat_waitcondition_server_url = http://controller:8000/v1/waitcondition
stack_domain_admin = heat_domain_admin
stack_domain_admin_password = $DEFAULT_PASS
stack_user_domain_name = heat
enable_stack_abandon = True
enable_stack_adopt = True

[database]
connection = mysql+pymysql://heat:$DEFAULT_PASS@controller/heat

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = heat
password = $DEFAULT_PASS

[trustee]
auth_plugin = password
auth_url = http://controller:35357
username = heat
password = $DEFAULT_PASS
user_domain_id = default

[clients_keystone]
auth_uri = http://controller:5000

[ec2authtoken]
auth_uri = http://controller:5000

[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = $DEFAULT_PASS
EOF

chown heat:heat $filename

rm -f /var/lib/heat/heat.sqlite

echo "##### DB SYNC #####"
heat-manage db_sync

sleep 2

service heat-api restart
service heat-api-cfn restart
service heat-engine restart

sleep 2
heat service-list