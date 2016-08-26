# Welcome!

OpenStack Installation script 

* **Version:** Liberty

* **Install mode:** All-in-One(only one box), Multi mode(controller+networks and compute node)

Add *Tacker module* to All-in-One mode.

### default tenant network *"vxlan"* and  *"securitygroup"* remove

```
vi /etc/neutron/plugins/ml2/ml2_conf.ini
...
tenant_network_types = flat,vxlan,gre,vlan

...
#enable_security_group = True
#enable_ipset = True
...
```


## External Resources:

OpenStack document:

http://docs.openstack.org/

Tacker git:

https://github.com/openstack/tacker






