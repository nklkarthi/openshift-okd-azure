#!/bin/bash

source 00-configuration.sh

# Remove all generated files
rm -rf ./out/azure.master.conf
rm -rf ./out/azure.infrastructure.conf
rm -rf ./out/azure.application.conf
rm -rf ./out/inventory.ini

rm -rf ./ssh/okd_rsa
rm -rf ./ssh/okd_rsa.pub

# Remove Service Principal
az ad sp delete --id ${OPENSHIFT_SP}

# Delete resource groups
az group delete --name ${OPENSHIFT_RG}