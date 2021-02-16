#!/bin/bash

source 00-configuration.sh

# Helper Function
execute-remote-cmd() {
	az vm run-command invoke \
	--name $1 \
	--resource-group ${OPENSHIFT_RG} \
	--command-id RunShellScript \
	--scripts "$2"
}

# Find Bastion Host Public IP
BASTION_IP=$(az vm show --name okd-bastion -g ${OPENSHIFT_RG} -d --query publicIps | sed -e 's/"//g')

# Install Prerequisites
execute-remote-cmd okd-bastion 'sudo yum -y install centos-release-openshift-origin311 epel-release docker git pyOpenSSL'

# Start and Enable Docker
execute-remote-cmd okd-bastion 'sudo systemctl start docker && sudo systemctl enable docker'

# Install Openshift Ansible Playbooks
execute-remote-cmd okd-bastion 'sudo yum -y install openshift-ansible'

# Downgrade to Ansible 2.6.5 because OKD 3.11 deployment with Ansible 2.7 is not supported and leads to errors
# https://github.com/openshift/openshift-ansible/issues/10691
execute-remote-cmd okd-bastion 'sudo yum -y downgrade ansible-2.6.5-1.el7'

# On Master Nodes
for i in `seq ${MASTER_INSTANCE_COUNT}`; do
	# Install Prerequisites
	execute-remote-cmd okd-master-${i} 'sudo yum -y install centos-release-openshift-origin311 epel-release docker git pyOpenSSL';
 	# Start and Enable Docker
	execute-remote-cmd okd-master-${i} 'sudo systemctl start docker && sudo systemctl enable docker';
done

# On Infrastructure Nodes
for i in `seq ${INFRASTRUCTURE_INSTANCE_COUNT}`; do
	# Install Prerequisites
	execute-remote-cmd okd-infrastructure-${i} 'sudo yum -y install centos-release-openshift-origin311 epel-release docker git pyOpenSSL';
 	# Start and Enable Docker
	execute-remote-cmd okd-infrastructure-${i} 'sudo systemctl start docker && sudo systemctl enable docker';
done

# On Application Nodes
for i in `seq ${APPLICATION_INSTANCE_COUNT}`; do
	# Install Prerequisites
	execute-remote-cmd okd-application-${i} 'sudo yum -y install centos-release-openshift-origin311 epel-release docker git pyOpenSSL';
 	# Start and Enable Docker
	execute-remote-cmd okd-application-${i} 'sudo systemctl start docker && sudo systemctl enable docker';
done

# Copy OKD Node configuration files via SCP to Bastion Host
# Configuring OKD for Azure requires the /etc/azure/azure.conf file, on each node host.
# https://docs.okd.io/3.11/install_config/configuring_azure.html
scp -i ~/.ssh/okd_rsa ./out/azure.master.conf ${USERNAME}@${BASTION_IP}:~/azure.master.conf
scp -i ~/.ssh/okd_rsa ./out/azure.infrastructure.conf ${USERNAME}@${BASTION_IP}:~/azure.infrastructure.conf
scp -i ~/.ssh/okd_rsa ./out/azure.application.conf ${USERNAME}@${BASTION_IP}:~/azure.application.conf

# Key Files
scp -i ~/.ssh/okd_rsa ~/.ssh/okd_rsa ${USERNAME}@${BASTION_IP}:~/.ssh/id_rsa
scp -i ~/.ssh/okd_rsa ~/.ssh/okd_rsa.pub ${USERNAME}@${BASTION_IP}:~/.ssh/id_rsa.pub

# Ansible Inventory File
scp -i ~/.ssh/okd_rsa ./out/inventory.ini ${USERNAME}@${BASTION_IP}:~/hosts
execute-remote-cmd okd-bastion 'sudo mv /home/clusteradmin/hosts /etc/ansible/hosts'

# Prepare SSH for Ansible
# execute-remote-cmd okd-bastion 'mkdir -p ~/.ssh'
# execute-remote-cmd okd-bastion 'mv /home/clusteradmin/.ssh/id_rsa ~/.ssh/id_rsa'
# execute-remote-cmd okd-bastion 'mv /home/clusteradmin/.ssh/id_rsa.pub ~/.ssh/id_rsa.pub'
execute-remote-cmd okd-bastion 'for i in $(seq 1); do ssh-keyscan -H okd-master-${i} >> ~/.ssh/known_hosts; done'
execute-remote-cmd okd-bastion 'for i in $(seq 1); do ssh-keyscan -H okd-application-${i} >> ~/.ssh/known_hosts; done'
execute-remote-cmd okd-bastion 'for i in $(seq 1); do ssh-keyscan -H okd-infrastructure-${i} >> ~/.ssh/known_hosts; done'

# ------------------------------------------------------------------------------------------------------------------------------
# Uncomment the following lines if you want a fully automated deploy
# We recommend executing the ansible playbooks through a shell session to bastion host instead of the az CLI
# ------------------------------------------------------------------------------------------------------------------------------
#
# Execute Openshift Ansible Playbooks
# execute-remote-cmd okd-bastion 'ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/prerequisites.yml'
# execute-remote-cmd okd-bastion 'ansible-playbook /usr/share/ansible/openshift-ansible/playbooks/deploy_cluster.yml'

# PLAY RECAP ****************************************************************************************************
# localhost                  : ok=11   changed=0    unreachable=0    failed=0   
# okd-application-1          : ok=122  changed=48   unreachable=0    failed=0   
# okd-infrastructure-1       : ok=124  changed=50   unreachable=0    failed=0   
# okd-master-1               : ok=1217 changed=463  unreachable=0    failed=0   


# INSTALLER STATUS **********************************************************************************************
# Initialization               : Complete (0:00:28)
# Health Check                 : Complete (0:00:09)
# Node Bootstrap Preparation   : Complete (0:03:31)
# etcd Install                 : Complete (0:00:56)
# Master Install               : Complete (0:05:28)
# Master Additional Install    : Complete (0:00:40)
# Node Join                    : Complete (0:00:23)
# Hosted Install               : Complete (0:01:00)
# Cluster Monitoring Operator  : Complete (0:01:17)
# Web Console Install          : Complete (0:00:45)
# Console Install              : Complete (0:00:31)
# Metrics Install              : Complete (0:02:08)
# metrics-server Install       : Complete (0:00:45)
# Logging Install              : Complete (0:03:08)
# Service Catalog Install      : Complete (0:01:46)

# Verify Install
# execute-remote-cmd okd-master-1 'oc get nodes'
# execute-remote-cmd okd-master-1 'oc get nodes --show-labels=true'

# Post Install Fixes / Bugs

# Service Broker Failing with 404 to /osb/ path
# https://github.com/openshift/openshift-ansible/issues/9960
# https://github.com/openshift/origin/issues/18332#issuecomment-420099823
# https://hub.docker.com/r/ansibleplaybookbundle/origin-ansible-service-broker/tags?page=1
# ansible_service_broker_image -> docker.io/ansibleplaybookbundle/origin-ansible-service-broker:ansible-service-broker-1.2.17-1

# Cluster Console Redirect Loop
# http://blog.andyserver.com/2018/10/enabling-the-openshift-cluster-console-in-minishift/
# execute-remote-cmd okd-master-1 'oc delete pod -n openshift-console -l app=openshift-console'

# sudo htpasswd -c /etc/origin/master/htpasswd clusteradmin
# oc create user clusteradmin
# kubectl create clusterrolebinding permissive-binding --clusterrole=cluster-admin --user=clusteradmin --group=system:serviceaccounts
# oc adm policy add-cluster-role-to-user cluster-admin clusteradmin --rolebinding-name=cluster-admin

# cluster console not working while running the ansible playbook more than once
# https://access.redhat.com/solutions/3676071