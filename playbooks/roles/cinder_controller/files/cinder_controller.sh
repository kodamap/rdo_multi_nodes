#!/bin/sh -e

export LANG=en_US.utf8

if [[ -z $1 ]]; then
    echo "** Usage: $0 <controller node IP>"
    exit 0
fi

controller=$1

# Modify the paramters manually.
RABBIT_PASS={RABBIT_PASS}
DATABASE_PASS={DATABASE_PASS}
CINDER_PASS={CINDER_PASS}
CINDER_DBPASS={CINDER_DBPASS}

prerequisites() {

  # Create the cinder database and Grant proper access to the cinder database:
  echo
  echo "** Creating cinder database and cinder user..."
  echo

  #mysql -u root -p${DATABASE_PASS} < /root/cinder.sql

  # Source the admin credentials to gain access to admin-only CLI commands:
  source ~/admin-openrc

  # Create a cinder user:
  echo
  echo "** openstack user create --password <password> cinder"
  echo

  openstack user show cinder ||  openstack user create --domain default --password ${CINDER_PASS} cinder

  # Add the admin role to the cinder user:
  echo
  echo "** openstack role add --project service --user cinder admin"
  echo

  #openstack role add --project service --user cinder admin
  ## for rdo
   openstack role list --project services --user cinder |grep admin ||  openstack role add --project services --user cinder admin

  # Create the cinder service entities:
  #
  # Note : The Block Storage service requires both the volume and volumev2 services.
  # However, both services use the same API endpoint that references the Block Storage
  # version 2 API.

  echo
  echo "** openstack service create --name cinder for volume"
  echo

  openstack service show volume || openstack service create --name cinder \
    --description "OpenStack Block Storage" volume

  echo
  echo "** openstack service create --name cinder for volumev2"
  echo

  openstack service show volumev2 || openstack service create --name cinderv2 \
    --description "OpenStack Block Storage" volumev2


  # Create the Block Storage service API endpoints:
  echo
  echo "** openstack endpoint create for volume"
  echo

  if openstack endpoint list |grep  volume > /dev/null; then

    continue

  else

  openstack endpoint create --region RegionOne \
    volume public http://controller:8776/v1/%\(tenant_id\)s

  openstack endpoint create --region RegionOne \
    volume internal http://controller:8776/v1/%\(tenant_id\)s

  openstack endpoint create --region RegionOne \
    volume admin http://controller:8776/v1/%\(tenant_id\)s
    
  openstack endpoint create --region RegionOne \
    volumev2 public http://controller:8776/v2/%\(tenant_id\)s
    
  openstack endpoint create --region RegionOne \
    volumev2 internal http://controller:8776/v2/%\(tenant_id\)s

  openstack endpoint create --region RegionOne \
    volumev2 admin http://controller:8776/v2/%\(tenant_id\)s

  fi 

}

install_and_configure_components () {

  # To install and configure Block Storage controller components
  # Install the packages:
  echo
  echo "** Installing the packages..."
  echo

  yum -y install openstack-cinder openstack-utils

  # Edit the /etc/cinder/cinder.conf file and complete the following actions:
  CONF=/etc/cinder/cinder.conf
  echo
  echo "** Editing the ${CONF}..."
  echo

  # Copy the /usr/share/cinder/cinder-dist.conf file to ${CONF}.
  # cp /usr/share/cinder/cinder-dist.conf ${CONF}
  # chown -R cinder:cinder ${CONF}

  test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org

  # In the [database] section, configure database access:
  openstack-config --set ${CONF} database connection mysql+pymysql://cinder:${CINDER_DBPASS}@controller/cinder

  # In the [DEFAULT] ,configure RabbitMQ message queue access:
  #openstack-config --set ${CONF} DEFAULT transport_url rabbit://openstack:${RABBIT_PASS}@controller
  ## for rdo
  openstack-config --set ${CONF} DEFAULT transport_url rabbit://guest:guest@controller

  # In the [DEFAULT] and [keystone_authtoken] sections, configure Identity service access:
  # Note : Comment out or remove any other options in the [keystone_authtoken] section.
  openstack-config --set ${CONF} DEFAULT auth_strategy keystone
  openstack-config --set ${CONF} keystone_authtoken auth_uri http://controller:5000
  openstack-config --set ${CONF} keystone_authtoken auth_url http://controller:35357
  openstack-config --set ${CONF} keystone_authtoken memcached_servers controller:11211
  openstack-config --set ${CONF} keystone_authtoken auth_type password
  openstack-config --set ${CONF} keystone_authtoken project_domain_name default
  openstack-config --set ${CONF} keystone_authtoken user_domain_name default
  #openstack-config --set ${CONF} keystone_authtoken project_name service
  ## for rdo
  openstack-config --set ${CONF} keystone_authtoken project_name services
  openstack-config --set ${CONF} keystone_authtoken username cinder
  openstack-config --set ${CONF} keystone_authtoken password ${CINDER_PASS}

  # In the [DEFAULT] section, configure the my_ip option to use the management interface
  openstack-config --set ${CONF} DEFAULT my_ip controller

  # In the [oslo_concurrency] section, configure the lock path:
  openstack-config --set ${CONF} oslo_concurrency lock_path /var/lib/cinder/tmp

  # (Optional) To assist with troubleshooting, enable verbose logging in the [DEFAULT] section:
  ### openstack-config --set ${CONF} DEFAULT verbose  True

  # Populate the Block Storage database:
  echo
  echo "cinder-manage db sync"
  echo

  su -s /bin/sh -c "cinder-manage db sync" cinder
  
  # Edit the /etc/nova/nova.conf file and add the following to it:
  CONF=//etc/nova/nova.conf
  echo
  echo "** Editing the ${CONF}..."
  echo

  test ! -f ${CONF}.org && cp -p ${CONF} ${CONF}.org

  openstack-config --set ${CONF} cinder os_region_name RegionOne


}

finalize_installation() {

  # To finalize installation
  # Start the Block Storage services and configure them to start when the system boots:
  echo
  echo "** Starting cinder services..."
  echo

  systemctl restart openstack-nova-api.service
  systemctl enable openstack-cinder-api.service openstack-cinder-scheduler.service
  systemctl start openstack-cinder-api.service openstack-cinder-scheduler.service

  systemctl status openstack-nova-api.service
  systemctl status openstack-cinder-api.service openstack-cinder-scheduler.service


  # List loaded extensions to verify successful launch of the cinder-server process:
  echo
  echo "** openstack volume service list"
  echo

  sleep 5;

  openstack volume service list
}

## main
prerequisites
install_and_configure_components
finalize_installation

echo
echo "Done."
