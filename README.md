# openstack deploy with rdo and configure with ansible

this is openstack(ocata) deployment with rdo packstack and ansible on centos7 nodes.

<a href="https://raw.githubusercontent.com/wiki/kodamap/rdo_multi_nodes/images/rdo_multi_nodes_example.png">
<img src="https://raw.githubusercontent.com/wiki/kodamap/rdo_multi_nodes/images/rdo_multi_nodes_example.png" alt="rdo_multi_nodes_example.png" style="width:75%;height:auto;" ></a>

## prerequisites

### configure ansible_hosts

- ansible_hosts.production    # for production
- ansible_hosts.staging    # for staging

### configure parameters

- vars/production.yml      # for production
- vars/staging.yml         # for staging

most of parameters are set to the packstack answerfile

- roles/rdo/tasks/configure.yml

```
- name: packstack generate answer file
  command: >
    packstack
      --gen-answer-file=/root/answerfile.txt
      --os-neutron-metadata-pw={{ metadata_pass }}
      --mariadb-pw={{ database_pass }}
      --os-heat-install=y
      --provision-demo=n
      --nagios-install=n
      --keystone-admin-passwd={{ admin_pass }}
      --os-compute-hosts={{ compute1_ip }},{{ compute2_ip }}
      --os-swift-install=y
      --os-cinder-install=n
      --os-ceilometer-install=y
      --os-neutron-lbaas-install=y
      --os-magnum-install=y
      --os-neutron-ovs-bridge-mappings=extnet:br-ex
      --os-neutron-ovs-bridge-interfaces=br-ex:{{ external_if }}
      --os-neutron-ovs-tunnel-if={{ tunnel_if }}
      --os-swift-storage-size={{ swift_size }}
      --os-horizon-ssl=y
```


- configure hosts file that will be copy to the openstack nodes

roles/common/files/hosts.produciton
roles/common/files/hosts.staging

## deploy (staging)

### prepare for rdo and exec packstack

- on ansible host

```
cd ~/playbooks
ansible-playbook -i ansible_hosts.staging 01_opstack.yml -k -u root
```

### configure openstack

```
ansible-playbook -i ansible_hosts.staging 02_opstack.yml -k -u root
```

### enable lbaas and configure dvr

```
ansible-playbook -i ansible_hosts.staging 03_opstack.yml -k -u root
```

