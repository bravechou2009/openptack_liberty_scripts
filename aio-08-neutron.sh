#!/bin/bash
source aio-config.cfg
source ~/admin-openrc.sh

echo "########## INSTALL NEUTRON ##########"

CORE_PLUGIN="ml2"
MECHANISM_DRIVERS="openvswitch"

if [ "$IS_MLNX" -gt 0 ]; then
CORE_PLUGIN="neutron.plugins.ml2.plugin.Ml2Plugin"
MECHANISM_DRIVERS="sriovnicswitch,openvswitch"

apt-get -y install neutron-plugin-sriov-agent

## sr-iov bug fix:
## https://www.mirantis.com/blog/carrier-grade-mirantis-openstack-the-mirantis-nfv-initiative-part-1-single-root-io-virtualization-sr-iov/
wget -c https://launchpad.net/ubuntu/+archive/primary/+files/libnl-3-200_3.2.24-2_amd64.deb
wget -c https://launchpad.net/ubuntu/+archive/primary/+files/libnl-genl-3-200_3.2.24-2_amd64.deb
wget -c https://launchpad.net/ubuntu/+archive/primary/+files/libnl-route-3-200_3.2.24-2_amd64.deb

dpkg -i --force-overwrite libnl-3-200_3.2.24-2_amd64.deb
dpkg -i --force-overwrite libnl-genl-3-200_3.2.24-2_amd64.deb
dpkg -i --force-overwrite libnl-route-3-200_3.2.24-2_amd64.deb

service libvirt-bin restart

fi

apt-get -y install neutron-server neutron-plugin-ml2 neutron-plugin-openvswitch-agent \
neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent neutron-plugin-openvswitch

filename=/etc/neutron/neutron.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
## refer
## http://docs.openstack.org/liberty/config-reference/content/section_neutron.conf.html
[DEFAULT]
verbose = True 
rpc_backend = rabbit
auth_strategy = keystone

state_path = /var/lib/neutron
core_plugin = $CORE_PLUGIN
service_plugins = router
allow_overlapping_ips = True
max_fixed_ips_per_port = 30

notify_nova_on_port_status_changes = True
notify_nova_on_port_data_changes = True
nova_url = http://controller:8774/v2

[agent]
root_helper = sudo /usr/bin/neutron-rootwrap /etc/neutron/rootwrap.conf

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $DEFAULT_PASS

[database]
connection = mysql+pymysql://neutron:$DEFAULT_PASS@controller/neutron

[nova]
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
region_name = RegionOne
project_name = service
username = nova
password = $DEFAULT_PASS

[oslo_concurrency]
lock_path = \$state_path/lock

[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = $DEFAULT_PASS
EOF
chown root:neutron $filename

######### set interface for bridge ######### 
br_list=($BR_LIST)
vlan_br_list=($VLAN_BR_LIST)
br_mapping_list=($BR_MAPPING_LIST)

flat_networks=
network_vlan_ranges=
bridge_mappings=
ranges=$VLAN_START

for x in "${br_list[@]}"
do
	if [ "$flat_networks" == "" ]; then
		flat_networks="ext_$x"
	else
		flat_networks="$flat_networks,ext_$x"
	fi
done

for x in "${vlan_br_list[@]}"
do
	if [ "$network_vlan_ranges" == "" ]; then
		network_vlan_ranges="ext_$x:$ranges:$(($ranges+99))"
	else
		network_vlan_ranges="$network_vlan_ranges,ext_$x:$ranges:$(($ranges+99))"
	fi
	ranges=$(($ranges+99+1))
done

for x in "${br_mapping_list[@]}"
do
	if [ "$bridge_mappings" == "" ]; then
		bridge_mappings="ext_$x:$x"
	else
		bridge_mappings="$bridge_mappings,ext_$x:$x"
	fi
done
######### set interface for bridge ######### 

filename=/etc/neutron/plugins/ml2/ml2_conf.ini
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[ml2]
extension_drivers = port_security
type_drivers = local,flat,vlan,gre,vxlan
tenant_network_types = vxlan,gre,vlan
mechanism_drivers = $MECHANISM_DRIVERS

[ml2_type_flat]
flat_networks = $flat_networks

[ml2_type_vlan]
network_vlan_ranges = $network_vlan_ranges

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[ml2_type_vxlan]
vni_ranges = 10:10000

[securitygroup]
enable_security_group = True
enable_ipset = True
#firewall_driver=neutron.agent.firewall.NoopFirewallDriver
firewall_driver = neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver

[ovs]
local_ip = $LOCAL_IP
enable_tunneling = True
integration_bridge = br-int
bridge_mappings = $bridge_mappings

[agent]
tunnel_types = gre,vxlan
polling_interval = 2
arp_responder = False
prevent_arp_spoofing = True

[ml2_sriov]
agent_required = True
supported_pci_vendor_devs = $PCI_VENDOR_DEVS
EOF
chown root:neutron $filename
ln -sf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

echo "dhcp-option-force=26,1500" > /etc/neutron/dnsmasq-neutron.conf
killall dnsmasq | awk '{print $1}' 1>&2

filename=/etc/neutron/metadata_agent.ini
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
## refer
## http://docs.openstack.org/liberty/config-reference/content/section_neutron-metadata_agent.ini.html
[DEFAULT]
verbose = True 
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_region = RegionOne
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = neutron
password = $DEFAULT_PASS
nova_metadata_ip = $MGMT
metadata_proxy_shared_secret = $DEFAULT_PASS
EOF
chown root:neutron $filename

filename=/etc/neutron/dhcp_agent.ini 
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
## refer
## http://docs.openstack.org/liberty/config-reference/content/section_neutron-dhcp_agent.ini.html
[DEFAULT]
verbose = True 
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
dnsmasq_config_file = /etc/neutron/dnsmasq-neutron.conf
dhcp_broadcast_reply = True
enable_isolated_metadata = True
EOF
chown root:neutron $filename

filename=/etc/neutron/l3_agent.ini
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
## refer
## http://docs.openstack.org/liberty/config-reference/content/section_neutron-l3_agent.ini.conf.html
[DEFAULT]
verbose = True
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
handle_internal_only_routers = True
external_network_bridge = 
#when their are multiple external bridge
gateway_external_network_id =
EOF
chown root:neutron $filename

if [ "$IS_MLNX" -gt 0 ]; then
## Edit the following file: sriov_agent.ini
filename=/etc/neutron/plugins/ml2/sriov_agent.ini
test -f $filename.org || cp $filename $filename.org
rm $filename

cat << EOF > $filename
[sriov_nic]
physical_device_mappings = $PHYSICAL_NETWORK:$DEVNAME

[securitygroup]
enable_security_group = False
firewall_driver=neutron.agent.firewall.NoopFirewallDriver
EOF
fi

echo "##### DB SYNC #####"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

service neutron-server restart
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
service neutron-plugin-openvswitch-agent restart

if [ "$IS_MLNX" -gt 0 ]; then
service neutron-plugin-sriov-agent restart
fi

service nova-compute restart

sleep 3

neutron agent-list

exit 0

export $(dbus-launch)

neutron net-delete sriov_254.x
neutron net-create --provider:physical_network=ext_br-sriov --provider:network_type=vlan sriov_254.x
neutron subnet-create sriov_254.x --name sriov_sub_254.x 192.168.254.0/24

nova delete test-sriov
neutron port-delete $(neutron port-list | grep "\ sriov_port\ " | awk '{ print $2 }')
net_id=`neutron net-show sriov_254.x | grep "\ id\ " | awk '{ print $4 }'`
port_id=`neutron port-create $net_id --name sriov_port --binding:vnic-type direct --device_owner network:dhcp | grep "\ id\ " | awk '{ print $4 }'`
nova boot --flavor m1.small --image ubuntu-mlnx-dhcp --nic port-id=$port_id test-sriov
