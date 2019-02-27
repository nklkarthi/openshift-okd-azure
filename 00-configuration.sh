set -x

# ##############################################################################
# Configuration
#
# You are free to change these values to fit your purpose
# ##############################################################################

# Cluster Region
LOCATION=canadacentral

# Name of the cluster
CLUSTER_NAME=sandbox

# Top-Level Domain (public) the cluster will be hosted under
# Resources in the cluster will be available as:
#
# OpenShift Admin GUI
# https://master.${CLUSTER_NAME}-${LOCATION}.${DNS_DOMAIN}
#
# Applications
# https://<application>-<namespace>.${CLUSTER_NAME}-${LOCATION}.${DNS_DOMAIN}
DNS_DOMAIN=company.org

# Username for VM access, Ansible provisioning, and Console access
USERNAME=okd

# Run `openssl rand -hex 16` to obtain a random password
# Run `htpasswd -n ${USERNAME}` to obtain the hash
PASSWORD=hashed_password_from_httpasswd_tool

# Masters 1, 3, 5 or 7
MASTER_INSTANCE_COUNT=3

# Infrastructure nodes 1, 3, 5
INFRASTRUCTURE_INSTANCE_COUNT=3

# Application Nodes 1..500
APPLICATION_INSTANCE_COUNT=3

# Virtual Machine Size
# For alist of available VM Sizes
# az vm list-sizes -l ${LOCATION}
MASTER_INSTANCE_SIZE=Standard_D4s_v3
INFRASTRUCTURE_INSTANCE_SIZE=Standard_D4s_v3
APPLICATION_INSTANCE_SIZE=Standard_D4s_v3

# Subnet Ranges
DMZ_SUBNET_CIDR=10.0.0.0/24
PRIVATE_SUBNET_CIDR=10.0.1.0/24

# OS Images
# For a list of Red Hat Enterprise Linux Image SKUs
# az vm image list --publisher RedHat --all

# RHEL
# INFRASTRUCTURE_INSTANCE_IMAGE=RedHat:RHEL:7-RAW:7.6.2018103108
# MASTER_INSTANCE_IMAGE=RedHat:RHEL:7-RAW:7.6.2018103108
# APPLICATION_INSTANCE_IMAGE=RedHat:RHEL:7-RAW:7.6.2018103108

# CentOS 7.6
INFRASTRUCTURE_INSTANCE_IMAGE=OpenLogic:CentOS:7.6:latest
MASTER_INSTANCE_IMAGE=OpenLogic:CentOS:7.6:latest
APPLICATION_INSTANCE_IMAGE=OpenLogic:CentOS:7.6:latest

# Cluster Storage Type
# See https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
# https://docs.microsoft.com/en-us/azure/storage/common/storage-quickstart-create-account?tabs=azure-cli
STORAGE_KIND=StorageV2
STORAGE_SKU=Standard_LRS
STORAGE_ACCOUNT_NAME=okdstoragelrs01

# RedHat Registry
# Add values from your subscription
REDHAT_REGISTRY_USERNAME=username
REDHAT_REGISTRY_PASSWORD=password

# ##############################################################################
#
# Computed values - do not change
#
# ##############################################################################
OPENSHIFT_RG=okd-${CLUSTER_NAME}-${LOCATION}-rg
KEYVAULT_NAME=${CLUSTER_NAME}-${LOCATION}-kv
OPENSHIFT_SP=https://openshiftsp/${LOCATION}/${CLUSTER_NAME}
VNET_NAME=okd-${CLUSTER_NAME}-vnet
DMZ_NSG_NAME=okd-${CLUSTER_NAME}-dmz-nsg
DMZ_SUBNET_NAME=${VNET_NAME}-dmz-sub
PRIVATE_NSG_NAME=okd-${CLUSTER_NAME}-private-nsg
PRIVATE_SUBNET_NAME=${VNET_NAME}-private-sub
MASTER_AVAILABILITY_SET_NAME=okd-${CLUSTER_NAME}-master-as
INFRASTRUCTURE_AVAILABILITY_SET_NAME=okd-${CLUSTER_NAME}-infrastructure-as
APPLICATION_AVAILABILITY_SET_NAME=okd-${CLUSTER_NAME}-application-as
INTERNAL_DNS_ZONE=okd-${CLUSTER_NAME}-${LOCATION}.local
DNS_ROUTER_NAME=${CLUSTER_NAME}-${LOCATION}.${DNS_DOMAIN}
DNS_MASTER_NAME=master.${CLUSTER_NAME}-${LOCATION}.${DNS_DOMAIN}
