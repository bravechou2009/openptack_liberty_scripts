#!/bin/bash
source com-config.cfg
source ~/admin-openrc.sh

echo "########## INSTALL NOVA ################"
apt-get -y install nova-compute sysfsutils

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

my_ip = $COM_IP

network_api_class = nova.network.neutronv2.api.API
security_group_api = neutron
linuxnet_interface_driver = nova.network.linux_net.LinuxOVSInterfaceDriver
firewall_driver = nova.virt.firewall.NoopFirewallDriver

enable_instance_password = True

resume_guests_state_on_host_boot = True
allow_resize_to_same_host = True

vif_plugging_is_fatal = True
vif_plugging_timeout = 300
compute_driver = libvirt.LibvirtDriver
linuxnet_ovs_integration_bridge = br-int

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
enabled = True
vncserver_listen = 0.0.0.0
vncserver_proxyclient_address = \$my_ip
novncproxy_base_url = http://$MGMT_IP:6080/vnc_auto.html

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

[libvirt]
#inject_key : Inject the ssh public key at boot time
#inject_partition : The partition to inject to : -2 => disable,
# -1 => inspect(libguestfs only),
#  0 => not partitioned,
# >0 => partition number
#inject_password : Inject the admin password at boot time, without an agent.
inject_key = False
inject_partition = -2
inject_password = False

[cinder]
os_region_name = RegionOne
EOF

chown nova:nova $filename

rm -f /var/lib/nova/nova.sqlite

echo "##### HARDWARE ACCELERATION #####"
cpu_count=$(egrep -c '(vmx|svm)' /proc/cpuinfo)

# virtual server : virt_type=kvm to virt_type=qemu
filename=/etc/nova/nova-compute.conf
if [ "$cpu_count" -eq 0 ]; then
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
compute_driver=libvirt.LibvirtDriver
[libvirt]
virt_type=qemu
EOF
fi

service nova-compute restart

exit 0
