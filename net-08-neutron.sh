#!/bin/bash
source net-config.cfg
source ~/admin-openrc.sh

echo "########## INSTALL NEUTRON ##########"
apt-get -y install neutron-server python-neutronclient neutron-plugin-ml2 neutron-plugin-openvswitch-agent \
neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent neutron-plugin-openvswitch conntrack
#neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent neutron-plugin-openvswitch neutron-common conntrack

filename=/etc/neutron/neutron.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
verbose = True 
rpc_backend = rabbit
auth_strategy = keystone

state_path = /var/lib/neutron
core_plugin = ml2
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
type_drivers = local,flat,vlan,gre,vxlan
tenant_network_types = flat,gre,vxlan,vlan
mechanism_drivers = openvswitch,l2population

[ml2_type_flat]
flat_networks = $flat_networks

[ml2_type_vlan]
network_vlan_ranges = $network_vlan_ranges

[ml2_type_gre]
tunnel_id_ranges = 1:1000

[ml2_type_vxlan]
vni_ranges = 10:10000
vxlan_group =

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
l2_population = True
polling_interval = 2
arp_responder = False
prevent_arp_spoofing = True
EOF


echo "dhcp-option-force=26,1500" > /etc/neutron/dnsmasq-neutron.conf
killall dnsmasq | awk '{print $1}' 1>&2

filename=/etc/neutron/metadata_agent.ini
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
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
nova_metadata_ip = controller
metadata_proxy_shared_secret = $DEFAULT_PASS
EOF

filename=/etc/neutron/dhcp_agent.ini 
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
verbose = True 
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
dhcp_driver = neutron.agent.linux.dhcp.Dnsmasq
dnsmasq_config_file = /etc/neutron/dnsmasq-neutron.conf
dhcp_broadcast_reply = True
enable_isolated_metadata = True
use_namespaces = True
dhcp_delete_namespaces = True
EOF

filename=/etc/neutron/l3_agent.ini
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
verbose = True
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver
handle_internal_only_routers = True
use_namespaces = True
router_delete_namespaces = True
external_network_bridge =
#when their are multiple external bridge
gateway_external_network_id =
EOF

chown root:neutron /etc/neutron/*
chown root:neutron $filename

echo "##### DB SYNC #####"
su -s /bin/sh -c "neutron-db-manage --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini upgrade head" neutron

service nova-api restart
service nova-scheduler restart
service nova-conductor restart

service neutron-server restart
service neutron-l3-agent restart
service neutron-dhcp-agent restart
service neutron-metadata-agent restart
service neutron-plugin-openvswitch-agent restart

sleep 3

neutron agent-list

exit 0