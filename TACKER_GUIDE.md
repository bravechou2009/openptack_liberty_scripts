# TACKER test Guide

## tacker service

```
service tacker-server restart
```

## Configuration file

```
ls /usr/local/etc/tacker/tacker.conf
...
```

## tacker log

```
cd /var/log/tacker
tail -f tacker.log
or
tail -f /var/log/tacker/tacker.log
```

## Tacker file location

```
ls /usr/local/lib/python2.7/dist-packages/tacker
...
```

## Test

* Connect OpenStack (admin/1234) : http://192.168.56.101/horizon/
* Create VNF : NFV => VNFManagement => VNF Manager => Deploy VNF
* View Instance : Admin => Instances => ta-???-??

### Test Networks 

* net_mgmt is flat (only flat) 
* net0 or net1 is gre or vxlan...(All available network)

```
neutron net-create net_mgmt --provider:network_type flat --provider:physical_network ext_br-tacker
neutron net-create net0
neutron net-create net1

neutron subnet-create --name net_mgmt_sub \
--gateway 192.168.120.1 \
--dns-nameserver 8.8.8.8 \
net_mgmt 192.168.120.0/24
neutron subnet-create --name net0_sub \
--gateway 10.10.11.1 \
--dns-nameserver 8.8.8.8 \
net0 10.10.11.0/24
neutron subnet-create --name net1_sub \
--gateway 10.10.12.1 \
--dns-nameserver 8.8.8.8 \
net1 10.10.12.0/24
```