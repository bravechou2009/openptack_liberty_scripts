#!/bin/bash
source aio-config.cfg

echo "########## INSTALL OPENSTACK PACKAGES(LIBERTY) ##########"
apt-get install software-properties-common -y
add-apt-repository cloud-archive:liberty -y


echo "########## UPDATE PACKAGE FOR LIBERTY ##########"
apt-get -y update && apt-get -y dist-upgrade
apt-get -y install openvswitch-switch

filename=/etc/network/interfaces
test -f $filename.org || cp "$filename" "$filename.org"
rm -f $filename

echo "auto lo" > $filename
echo "iface lo inet loopback" >> $filename

net_list=($NET_LIST)
br_list=($BR_LIST)
br_mode=($BR_MODE)
br_ip_list=($BR_IP_LIST)
br_gw_list=($BR_GW_LIST)
br_dns_list=($BR_DNS_LIST)

######### set interface for bridge ######### 
idx=0
for x in "${br_list[@]}"
do

echo "" >> $filename
if [ "${br_mode[$idx]}" != "0" ]; then
  echo "auto $x" >> $filename
  echo "iface $x inet ${br_mode[$idx]}" >> $filename

  if [ "${br_ip_list[$idx]}" != "0" ]; then
    echo "address ${br_ip_list[$idx]}" >> $filename
  fi

  if [ "${br_gw_list[$idx]}" != "0" ]; then
    echo "gateway ${br_gw_list[$idx]}" >> $filename
  fi

  if [ "${br_dns_list[$idx]}" != "0" ]; then
    echo "dns-nameservers ${br_dns_list[$idx]}" >> $filename
  fi
fi

idx=$idx+1

done

######### set interface for nic ######### 
for x in "${net_list[@]}"
do

echo "" >> $filename
echo "auto $x" >> $filename
echo "iface $x inet manual" >> $filename

ifconfig $x 0.0.0.0

done

######### set bridge ######### 
idx=0
for x in "${br_list[@]}"
do

#ovs-vsctl del-port $x ${net_list[$idx]}
#ovs-vsctl del-br $x

ovs-vsctl add-br $x

if [ "$x" == "br-tacker" ]; then
  ifdown $x; ifup $x;
else
  if [ ! -z "${net_list[$idx]}" ]; then
    ovs-vsctl add-port $x ${net_list[$idx]}; ifdown ${net_list[$idx]}; ifup ${net_list[$idx]};
  fi
fi

idx=$(($idx+1))
sleep 1

done

exit 0
