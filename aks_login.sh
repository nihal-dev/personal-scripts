#!/bin/bash

read -p "Do you want to authenticate to azure [ yes || no ]: " auth_option 
read -p "Provide the subscription ID: " sub_id
read -p "Provide project name: " project_name

authenticate_azure () {
    az login --use-device-code
}

set_subscription () {
    echo "Configuring the subscription for AKS project"
    az account set --subscription ${sub_id} 
}

set_aks_project () {
    echo "Configuring the AKS project"
    az aks get-credentials --subscription ${sub_id} --name ${project_name} -g ${project_name} --admin --overwrite
}

if [[ ${auth_option} == "yes" ]]
then
    authenticate_azure
    set_subscription
    set_aks_project
else
    set_subscription
    set_aks_project
fi