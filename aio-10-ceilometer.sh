#!/bin/bash
source aio-config.cfg
source ~/admin-openrc.sh

## ceilometer
if [ "$IS_TELEMETRY" -eq 0 ]; then
exit 0
fi

# Install and configure MongoDB

apt-get install -y mongodb-server mongodb-clients python-pymongo

filename=/etc/mongodb.conf
test -f $filename.org || cp $filename $filename.org

sed -i "s/bind\_ip\ =\ 127\.0\.0\.1/bind_ip = $MGMT_IP/g" /etc/mongodb.conf
sed -i '2 i\smallfiles\ =\ true' /etc/mongodb.conf

service mongodb stop
rm /var/lib/mongodb/journal/prealloc.*
sleep 2

service mongodb start

# MongDB Connection
# mongo --host [ipaddress] ex)10.0.0.166
sleep 3

mongo --host controller --eval "
  db = db.getSiblingDB(\"ceilometer\");
  db.addUser({user: \"ceilometer\",
  pwd: \"$DEFAULT_PASS\",
  roles: [ \"readWrite\", \"dbAdmin\" ]})"

# Install and configure Ceilometer Components

apt-get install -y ceilometer-api ceilometer-collector \
  ceilometer-agent-central ceilometer-agent-notification \
  ceilometer-alarm-evaluator ceilometer-alarm-notifier \
  python-ceilometerclient

filename=/etc/ceilometer/ceilometer.conf 
test -f $filename.org || cp $filename $filename.org

cat << EOF > $filename
## refer
## http://docs.openstack.org/liberty/install-guide-ubuntu/ceilometer-install.html
[DEFAULT]
verbose = True
rpc_backend = rabbit
auth_strategy = keystone


[database]
connection = mongodb://ceilometer:$DEFAULT_PASS@controller:27017/ceilometer

[keystone_authtoken]
auth_uri = http://controller:5000
auth_url = http://controller:35357
auth_plugin = password
project_domain_id = default
user_domain_id = default
project_name = service
username = ceilometer
password = $DEFAULT_PASS

[matchmaker_redis]

[matchmaker_ring]

[oslo_concurrency]

[oslo_messaging_amqp]

[oslo_messaging_qpid]

[oslo_messaging_rabbit]
rabbit_host = controller
rabbit_userid = openstack
rabbit_password = $DEFAULT_PASS

[oslo_policy]

[service_credentials]
os_auth_url = http://controller:5000/v2.0
os_username = ceilometer
os_tenant_name = service
os_password = $DEFAULT_PASS
os_endpoint_type = internalURL
os_region_name = RegionOne
EOF

##### Restart the Telemetry services ####

service ceilometer-agent-central restart
service ceilometer-agent-notification restart
service ceilometer-api restart
service ceilometer-collector restart
service ceilometer-alarm-evaluator restart
service ceilometer-alarm-notifier restart

exit 0

sleep 2

IMAGE_ID=$(glance image-list | grep 'cirros' | awk '{ print $2 }')
glance image-download $IMAGE_ID > /tmp/cirros.img

ceilometer meter-list
ceilometer statistics -m image.download -p 60
rm /tmp/cirros.img
