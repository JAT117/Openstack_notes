
Note: Before perform this exam, makesure you sourced the correct file. 
Overcloud_"name"rc file will be available under /home/stack in Director node. 
Since all the below tasks has to perform by any of the given project, so you have to source the file accordingly

Do not touch Undercloud (stackrc)

Tips: 
If using command line identify the project user, source its keystone file.
If using horizon, check if multiple projects for this user, make sure you tick correct before launching instance.

[student@workstation]$lab linux-interface setup // in lab env
[student@workstation]$ssh director
[stack@director]$source ~/overcloudrc && env | grep -i OS

====================================================================================
Need Keypairs:
	openstack keypair create <kp_name> <kp_name>.pem
	chmod 600 <kp_name>.pem 
	openstack keypair create kp1 > ~/kp1.pem && chmod 600 kp1.pem
	openstack keypair create kp2 > ~/kp2.pem && chmod 600 kp2.pem

	ssh -i ~/KEY_NAME.pem USER@SERVER_IP

Need Security Groups:
	openstack security group list
	openstack security group create sg_ssh1
	openstack security group rule create --proto icmp sg_ssh1
	openstack security group rule create --proto tcp --dst-port 80:80 sg_ssh1
	openstack security group rule create --proto tcp --dst-port 22:22 sg_ssh1

Need a user data script to install HTTP server:
	nano userdata.sh && chmod 755 userdata.sh
	
	#!/bin/bash
	yum install httpd -yum
	systemctl enable httpd --now
	echo "Hello from a server" >> /var/www/html/index.html

Need subnet:
	openstack subnet create --subnet -range 10.1.1.0/24 --network <int_net1> <subnet1>


=======================================================================================

Question 1: Create Instances
Create two instances with the given details in said project, marketing project
	a. Image is given
	b. Network name is given
	c. User data script is given
	d. Security group is given
	e. Flavour is given
	f. Create subnet pool

[stack@director]openstack server create \
	[--flavor <flavor>] \
	[--image <image_name>] \
	[--nic net-id=<internal_network_name>] \ 
	[--security-group <sec group>] \
	[--key-name <kp_name>] \
	[
	<SERVER NAME>

//Create subnet pool
[stack@director]openstack subnet pool create
    [--default-prefix-length <default-prefix-length> /24] \
    [--min-prefix-length <min-prefix-length>] \
    [--max-prefix-length <max-prefix-length>]
    [--description <description>]
    [--project <project> [--project-domain <project-domain>]]
    [--address-scope <address-scope>]
    [--default | --no-default]
    [--share | --no-share]
    [--default-quota <num-ip-addresses>]
    [--tag <tag> | --no-tag]
    --pool-prefix <pool-prefix> [...]
    <name>
	
openstack subnet pool create --pool-prefix <IP/Mask> --default-prefix-length 28 <subnet_pool_name>

Question-2 & 3: 
HTTPD load balancer (not database)

Create a Loadbalancer named finance-lb1 subnet finance-subnet1 using developer1-rc.
Create a listener with name of finance-listener1 attached to finance-lb1, port 80, protocol is HTTP
create a loadbalancer pool with finance-pool1 using round_robin algorithm

Add finance-server1 & 2 into finance-pool
create a healthmonitor named finance-health1 for finance-pool1 ( Delay 5, timeout 2, max-retries 3)
Associate floating ip to the loadbalancer


Ans:

neutron lbaas-loadbalancer-create --name <load_balancer> <subnet>
neutron lbaas-listener-create --loadbalancer <load_balancer> --protocol HTTP --protocol-port 80 --name <listener1>
neutron lbaas-pool-create --lb-algorithm ROUND_ROBIN --listener <listener1> --protocol HTTP --name <lb_pool>
neutron lbaas-member-create --protocol-port 80 --subnet <subnet1> --address <server1_internal_address> <lb_pool>
neutron lbaas-member-create --protocol-port 80 --subnet <subnet1> --address <server2_internal_address> <lb_pool>
neutron lbaas-healthmonitor-create --delay 5 --timeout 2 --max-retries 3 --type http --pool <lb_pool> --name <lb_health_monitor>
neutron lbaas-loadbalancer-show <load_balancer> //get LB_ID

openstack floating ip list //get FIP_ID
neutron floatingip-associate <FLOATING_IP_ID> <VIP_LB_ID>
neutron lbaas-loadbalancer-list
neutron lbaas-member-list <lb_pool>
neutron lbaas-member-delete <server_id> <lb_pool>


	# neutron lbaas-loadbalancer-create --name finance-lb1 finance-subnet1
	# neutron lbaas-listener-create --loadbalancer finance-lb1 --protocol HTTP --protocol-port 80 --name finance-listener1
	# neutron lbaas-pool-create --lb-algorithm ROUND_ROBIN --listener finance-listener1 --protocol HTTP --name finance-pool1
	# openstack server list  ## Find IP Address of the server.
	# neutron lbaas-member-create --protocol-port 80 --subnet finance-subnet1 --address <IP172> finance-pool1
	# neutron lbaas-healthmonitor-create --delay 5 --timeout 2 --max-retries 3 --type HTTP --pool finance-pool1 --name finance-health1
	# neutron lbaas-loadbalancer-show finance-lb1
	# neutron floatingip-associate <Floating_IP_ID> <VIP_PORT_ID>

//test the load balancer by using curl on the same floating ip address repeatly 

Qus.4 : 
Create a vxlan for the given network & associate a subnet from the subnetpool. 
Create a router and attach this router to external gateway.
Associate floating ip for the server

	# openstack subnet create --subnet-range 10.1.1.0/24 --network internal_subnet new_subnet
	# openstack network create --provider-network-type vxlan <Network_NAME>
	# openstack router create vxlan_router
	# neutron router-gateway-set vxlan_router external_network
	# openstack server add floating IP <new_server> <floating IP>

Qus.5: Create a ipv6 Network with the given subnet details, it suppose to work with both the networks IP4 as well IPV6.
Create a instance and launch it with this network. Check the IPV6 IP is associate with this instance.

	#openstack network create dual-stack
	#openstack subnet create --network dual-stack --ip-version 4 --subnet-range 10.1.3.0./24  --dns-nameserver <some IP> --network network ipv4-subnet
	#openstack subnet create --network dual-stack --ip-version 6 --ipv6-ra-mode slaac --ipv6-address-mode slaac --use-default-subnet-pool ipv6-subnet
	#openstack floating ip create provider-datacentre
	#openstack router create dualstackrouter1
	#openstack router add subnet dualstackrouter1 ipv4-subnet
	#openstack router add subnet dualstackrouter1 ipv6-subnet
	#neutron router-gateway-set dualstackrouter1 provider-datacentre
	#openstack port list --device-owner network:router_interface
	#openstack server create --image rhel7 --flavor default --nic net-id=dual-stack --security-group sg1 --user-data ~/server6.sh --key-name kp6 s6
	#openstack server add floating ip s6 <floating-ip>


Q6: Troubleshoot instance,Instance should access to ssh. Attach available floating ip to instance.

Server server1 (10.0.0.11) >
Network - private1
Router -router1
Subnet- private-subnet (10.0.0.0)
Sec group - ssh
Keypair - ~/key1.pem
External - public

Add interface(subnet)
	1. Check subnet is correctly attached to the rourter which is connected to this server network.
		#openstack router show <router1>
		#openstack router add <router1> <private-subnet>
	2. Check the security group is attached , if not attach the correct security group.
		#openstack server show <server1>
		#openstack security group show <ssh>
		#openstack security group rule list <ssh>
		#openstack server add security group <server1> <ssh>
	3. Assign floating ip & check you can do ssh to that server.
		#openstack floating ip list
		#openstack floating ip create <public>
		#openstack server add floating ip <server1> <floating ip>
	4. Reboot this machine and check it again
		#openstack server reboot <server1>
		#ping -c 4 <floating ip>
		#ssh -i <~/key1.pem> cloud-user@<floating ip>

	openstack port list --device owner network:router_interface --router research-router1 

Q7: Create a QOS policy
    #neutron qos-policy-create 'policy-name' 
    #neutron qos-bandwidth-limit-rule-create --max-burst-kbps 6000 --max-kbps 8000 'policy_name'

    //Check the port for the server whcih is associate for the fixed IP. 
    # openstack server show "VM_NAME" //get the fixed ip of the vm
    # openstack port list | grep -i "FIXED_IP_OF_VM" //this command will get port.no
    # neutron port-update 'port.no' --qos-policy 'policy_name' //this is where I fucked up "--qos-policy"

    Check the policy is updated correctly on the VM network port: (didnt need this in the actual test)
    # ssh <compute node>
    # virsh domiflist "VM_NAME" //should be something like "instance-000000R"

    You can get the interface name of tap device. The same name will be used for OVS with suffix changed to qvo

    # ovs-vsctl list interface 'qvo**'   //replace "tap" with qvo
    # // look for ingress
    # openstack port list --device-owner network:router_interface --router "routername"

    To remove QOS
    # neutron port-update 'port.no' --qos-policy --no-qos-policy

https://docs.openstack.org/mitaka/networking-guide/config-qos.html

=====================================================================================

Workstation: (not director, that comes later via SSH)

login: student
password: student
[student@workstation]lab linux-interfaces setup (complete once)
[student@workstation]$ssh director
[stack@director]source ~/overcloudrc

env | grep -i OS

openstack catalog list
openstack service list
openstack network list

openstack network create <network_name>
openstack network show <network_name>

openstack subnet pool create --pool-prefix <IP/Mask> --default-prefix-length 28 <subnet_pool_name>

openstack subnet create --subnet-pool <subnet_pool_name> --network <external_network> --subnet-range <IP/Mask> <subnet_name>

openstack subnet create --network <network_name> --subnet-range 192.168.56.0/24 <subnet_name>
openstack subnet create --network internal_network --subnet-range 192.168.56.0/24 int-subnet
openstack subnet show <subnet_ID>

openstack floating ip create <external_network>
openstack floating ip create provider-datacentre


openstack router list
openstack router create <router_name>
neutron router-gateway-set <router_name> <external_network>
openstack router set --external-gateway <external_network> <router>
openstack router show router
openstack floating ip list
openstack add floating ip lb1 172.25.250.107


openstack router add subnet <router_name> <subnet_name> 
openstack router add subnet router1 int-subnet
openstack router show <router>

openstack floating ip create <external network>
openstack floating ip list
ping <floating_IP>

openstack server add floating ip <server name> <Floating IP address>
openstack server list
openstack floating ip list
openstack network show <network_name>

==================================================================================
CL110 notes
source admin-openrc
env | grep -i os

openstack catalog list

openstack domain create nokia
openstack domain list

openstack project create --domain <domain-name> <project-name>
openstack project create --domain nokia project-cloud
openstack project create --domain nokia dev-cloud

openstack project list --domain nokia

openstact user create --domain <domain> --project <project> --password-prompt <user>
openstack user create --domain nokia --project project-cloud john
openstack user set --password password john

openstack user create --domain nokia --project dev-cloud kamal
openstack user set --password password kamal

openstack role list

openstack role assignment list
openstack role assignment list --name <name>

openstack role add --user-domain nokia --project project-cloud --user john admin
openstack role add --user-domain nokia --project dev-cloud --user kamal user

sudo wget http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
	or alternatively
sudo wget http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img


//create image, then flavor

openstack image create --file /root/cirros-0..0-x86_64-disk.img \
--disk-format qcow2 \
--private cirros

openstack image list
openstack image show <image_id>
openstack image delete <image_id>

openstack flavor create
    [--id <id>]
    [--ram <size-mb>]
    [--disk <size-gb>]
    [--ephemeral-disk <size-gb>]
    [--swap <size-mb>]
    [--vcpus <num-cpu>]
    [--rxtx-factor <factor>]
    [--public | --private]
    [--property <key=value> [...] ]
    [--project <project>]
    [--project-domain <project-domain>]
    <flavor-name>
	
openstack flavor create --ram 100 --vcpu 1 small
openstack flavor list
openstack flavor set --private small
openstack flavor delete small
openstack flavor create --private --ram 100 --vcpu 1 small
openstack flavor show small

openstack network create <network_name>
openstack network create internal
openstack subnet create --network <network_name> --subnet-range 10.168.193.25/24 <subnet_name>

openstack subnet create --network internal --subnet-range <controller_IP>/24 int-subnet
openstack subnet create --network public --subnet-range <controller_IP>/24 ext-subnet

openstack subnet show <subnet_ID>

openstack floating ip create <external_network>
openstack floating ip create provider-datacenter

openstack router list
openstack router create <router_name>
neutron router-gateway-set <router_name> <external_network>

openstack router set --external-gateway <external_network> <router>

openstack router add subnet <router_name> <subnet_name> 
openstack router add subnet router int-subnet

openstack router show <router>

openstack floating ip list
openstack add floating ip lb1 172.25.250.107
openstack server list
openstack floating ip list

openstack network show
chmod 755 userdata.sh

openstack security group list
openstack security group create ssh1
openstack security group rule create --proto tcp --dst-port 80:80 ssh1
openstack security group rule create --proto tcp --dst-port 22:22 ssh1
openstack security group rule create --proto icmp ssh1


# openstack server create --image "IMAGE" --flavor "FLAVOR" --nic net-id="NETWORK" --user-data "PATH_NAME" --security-group "SECURITY_GROUP_NAME" --key-name "keyname" "SERVER_NAME"

openstack server create --image cirros --flavor m1.nano --nic net-id=test_internal --security-group sg1 Server_1 
openstack router create external-router1
neutron router-gateway-set external-router1 provider-datacentre
openstack router subnet add external-router1 subnet1
neutron router-port-list external-router1

-------------------------   
ensure controller host is same as binding address

systemctl list-units --type service --state running,failed
ls -larth /var/lib/rabbitmq/mnesia/
nmcli connection show
nmcli device
systemctl status rabbitmq-server
systemctl status memcached.service
source admin-openrc 
env | grep -i OS
yum repolist
openstack-status
openstack project list
openstack service list
openstack catalog list

openstack domain create nokia
openstack project create --domain nokia project-cloud
openstack project create --domain nokia development-cloud
openstack project list --domain nokia

rabbitmqctl help
rabbitmqctl list_users
rabbitmqctl status
rabbitmqctl node_health_check

openstack user create --domain nokia --project project-cloud j
openstack user set --password password j

openstack role list
openstack role add --user-domain nokia --project project-cloud --user j admin


openstack user set --password password k
openstack user list

openstack role assignment list 
openstack role assignment list --user j

openstack image list

openstack flavor create --ram 100 --vcpu 1 small
openstack flavor list
openstack flavor show small
openstack flavor delete small
openstack flavor create --private --ram 100 --vcpu 1 small
openstack flavor list
openstack flavor show small
openstack flavor show m1.nano

openstack flavor create --disk 2 --public --ram 10 -vcpus -1 --swap 50 <flavor_name>

openstack network create test_internal
openstack subnet create --network test_internal --subnet-range 192.168.56.0/24 test_subnet_1
openstack subnet show test_subnet_1

openstack network create test_external
openstack floating ip create test_external
openstack router list
openstack router create router1

<+++++++++++++++++++++++++++++>
openstack router create external-router1
neutron router-gateway-set external-router1 test_external
openstack router add subnet external-router1 test_subnet_1
neutron router-port-list external-router1

neutron router-gateway-set router1 test_external
neutron router-interface-add router1 test_subnet_1

create domain>
create project>
create user>
create role>
create>
create>

ip netns exec <> ip a
ip netns exec qdhcp-acb6ff19-56aa-4ce0-b841-a3e8a9d49994 bash

assign physical network to namespace

https://docs.openstack.org/glance/queens/admin/troubleshooting.html
https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/10/html/networking_guide/sec-connect-instance
