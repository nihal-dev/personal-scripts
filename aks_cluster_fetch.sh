#!/bin/bash

### get the account details ###
azure_account () {
    az account list --all | /c/Users/niysha/jq.exe . | grep -E '"id":' | awk -F ' ' '{ print $2 }' | tr -d '",' > /c/Users/niysha/account_list.txt
}

### Get the AKS cluster ###
aks_cluster_list () {
    for subs in `cat /c/Users/niysha/account_list.txt`
    do
        az aks list --subscription ${subs} --query "[].{Name:name, ResourceGroup:resourceGroup}" --output tsv >> output.txt
    done
}

anf_account_list () {
    for subs in `cat /c/Users/niysha/account_list.txt`
    do
        az netappfiles account list --subscription ${subs} --query "[].{name:name, resourceGroup:resourceGroup}" -o tsv >> netapp_output.txt
    done
}

#azure_account
#aks_cluster_list
anf_account_list
