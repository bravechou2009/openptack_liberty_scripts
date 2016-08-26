#!/bin/bash
source com-config.cfg
source ~/admin-openrc.sh

echo "########## INSTALL NEUTRON ##########"
apt-get -y install neutron-plugin-ml2 neutron-plugin-openvswitch-agent

filename=/etc/neutron/neutron.conf
test -f $filename.org || cp $filename $filename.org
rm -f $filename

cat << EOF > $filename
[DEFAULT]
verbose = True 
rpc_backend = rabbit
auth_strategy = keystone

core_plugin = ml2
service_plugins = router
allow_overlapping_ips = True

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
#connection = mysql+pymysql://neutron:$DEFAULT_PASS@controller/neutron

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

service nova-compute restart
service neutron-plugin-openvswitch-agent restart

exit 0