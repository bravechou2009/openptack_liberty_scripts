#!/bin/bash
source net-config.cfg

export OS_TOKEN="$DEFAULT_PASS"
export OS_URL=http://$MGMT_IP:35357/v2.0

# Project
openstack project create --description "Admin Project" admin
openstack project create --description "Service Project" service

# Users
openstack user create --password "$DEFAULT_PASS" --email yangun@dcn.ssu.ac.kr admin
openstack user create --password "$DEFAULT_PASS" --email yangun@dcn.ssu.ac.kr glance
openstack user create --password "$DEFAULT_PASS" --email yangun@dcn.ssu.ac.kr nova
openstack user create --password "$DEFAULT_PASS" --email yangun@dcn.ssu.ac.kr neutron
openstack user create --password "$DEFAULT_PASS" --email yangun@dcn.ssu.ac.kr cinder
#openstack user create --password "$DEFAULT_PASS" --email yangun@dcn.ssu.ac.kr swift

# Roles
openstack role create admin
openstack role create user
openstack role create _member_
openstack role add --project admin --user admin admin
openstack role add --project service --user glance admin
openstack role add --project service --user nova admin
openstack role add --project service --user neutron admin
openstack role add --project service --user cinder admin
#openstack role add --project service --user swift admin

#Service
openstack service create --name keystone --description "OpenStack Identity" identity
openstack service create --name glance --description "OpenStack Image service" image
openstack service create --name nova --description "OpenStack Compute" compute
openstack service create --name neutron --description "OpenStack Networking" network
openstack service create --name cinder --description "OpenStack Block Storage" volume
openstack service create --name cinderv2 --description "OpenStack Block Storage" volumev2
#openstack service create --name swift --description "OpenStack Object Storage" object-store

#Endpoint
openstack endpoint create \
  --publicurl http://controller:5000/v2.0 \
  --internalurl http://controller:5000/v2.0 \
  --adminurl http://controller:35357/v2.0 \
  --region RegionOne identity

openstack endpoint create \
  --publicurl http://controller:9292 \
  --internalurl http://controller:9292 \
  --adminurl http://controller:9292 \
  --region RegionOne image

openstack endpoint create \
  --publicurl http://controller:8774/v2/%\(tenant_id\)s \
  --internalurl http://controller:8774/v2/%\(tenant_id\)s \
  --adminurl http://controller:8774/v2/%\(tenant_id\)s \
  --region RegionOne compute

openstack endpoint create \
  --publicurl http://controller:9696 \
  --adminurl http://controller:9696 \
  --internalurl http://controller:9696 \
  --region RegionOne network

openstack endpoint create \
  --publicurl http://controller:8776/v1/%\(tenant_id\)s \
  --internalurl http://controller:8776/v1/%\(tenant_id\)s \
  --adminurl http://controller:8776/v1/%\(tenant_id\)s \
  --region RegionOne volume

openstack endpoint create \
  --publicurl http://controller:8776/v2/%\(tenant_id\)s \
  --internalurl http://controller:8776/v2/%\(tenant_id\)s \
  --adminurl http://controller:8776/v2/%\(tenant_id\)s \
  --region RegionOne volumev2

##openstack endpoint create \
##  --publicurl 'http://controller:8080/v1/AUTH_%(tenant_id)s' \
##  --internalurl 'http://controller:8080/v1/AUTH_%(tenant_id)s' \
##  --adminurl http://controller:8080 \
##  --region RegionOne object-store

echo "export OS_PROJECT_DOMAIN_ID=default" > ~/admin-openrc.sh
echo "export OS_USER_DOMAIN_ID=default" >> ~/admin-openrc.sh
echo "export OS_PROJECT_NAME=admin" >> ~/admin-openrc.sh
echo "export OS_TENANT_NAME=admin" >> ~/admin-openrc.sh
echo "export OS_USERNAME=admin" >> ~/admin-openrc.sh
echo "export OS_PASSWORD=$DEFAULT_PASS" >> ~/admin-openrc.sh
echo "export OS_AUTH_URL=http://controller:35357/v3" >> ~/admin-openrc.sh
echo "export OS_IMAGE_API_VERSION=2" >> ~/admin-openrc.sh

unset OS_TOKEN OS_URL

chmod +x ~/admin-openrc.sh

exit 0
