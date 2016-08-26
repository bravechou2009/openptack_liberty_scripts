#!/bin/bash
source net-config.cfg
source ~/admin-openrc.sh

echo "########## INSTALL NOVA ################"
apt-get -y install nova-api nova-cert nova-conductor nova-consoleauth \
nova-novncproxy nova-scheduler python-novaclient sysfsutils

filename=/etc/nova/nova.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
verbose = True
rpc_backend = rabbit
auth_strategy = keystone

dhcpbridge_flagfile = /etc/nova/nova.conf
dhcpbridge = /usr/bin/nova-dhcpbridge
log_dir = /var/log/nova
state_path = /var/lib/nova
lock_path = /var/lock/nova
force_dhcp_release = True
ec2_private_dns_show_ip = True
api_paste_config = /etc/nova/api-paste.ini
enabled_apis = ec2,osapi_compute,metadata

my_ip = $NET_IP

network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver

enable_instance_password = True

resume_guests_state_on_host_boot = True
allow_resize_to_same_host = True

#novncproxy_host=$my_ip
#novncproxy_port=6080

[database]
connection = mysql+pymysql://nova:$DEFAULT_PASS@controller/nova

[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = $DEFAULT_PASS

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = nova
password = $DEFAULT_PASS

[vnc]
vncserver_listen = \$my_ip
vncserver_proxyclient_address = \$my_ip

[glance]
host = controller

[oslo_concurrency]
lock_path = /var/lib/nova/tmp

[neutron]
url = http://controller:9696
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
region_name = RegionOne
project_name = service
username = neutron
password = $DEFAULT_PASS

service_metadata_proxy = True
metadata_proxy_shared_secret = $DEFAULT_PASS
EOF

chown nova:nova $filename

rm -f /var/lib/nova/nova.sqlite

echo "##### DB SYNC #####"
nova-manage db sync

service nova-api restart
service nova-cert restart
service nova-consoleauth restart
service nova-scheduler restart
service nova-conductor restart
service nova-novncproxy restart

sleep 2
nova-manage service list

exit 0
