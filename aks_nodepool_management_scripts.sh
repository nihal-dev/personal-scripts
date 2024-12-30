#!/bin/bash

### Set environment variables for git bash, Not required for other OS. ###
export MSYS_NO_PATHCONV=1

## Variables ##
read -p "Enter what you want to perform on node..?: [[ upgrade || add || delete || count ]]: " nodeAction
read -p "Enter the subscription id: " subscriptionId
read -p "Enter the resource group: " resourceGroup
read -p "Enter the cluster name: " clusterName
read -p "Enter the nodepool: " nodePool

### Functions ###
setSubscription () {
    echo "Configuring the subscription for AKS project"
    az account set --subscription ${subscriptionId}
}

setAksLogin () {
    echo "Configuring the AKS project"
    az aks get-credentials --subscription ${subscriptionId} --name ${clusterName} -g ${resourceGroup} --admin --overwrite
}

backupOldNodepool () {
    az aks nodepool show -g ${resourceGroup} --cluster-name ${clusterName} -n ${nodePool} -o json > ${currentPath}/${nodePool}.json
    cat ${currentPath}/${nodePool}.json
}

getValues () {
    read -p "Enter the node count: " nodeCount
    read -p "Enter Machine type for nodepool: " nodeVmSize
    read -p "Enter Node OS disk size: " nodeOsDiskSize
    read -p "Enter the mode [[ System || User ]]: " modeOption
    read -p "Enter max no of pods: " maxPods
    read -p "Enter the taints: " applyTaints
    read -p "Enter the labels: " applyLabels
    read -p "Enter the tags: " applyTags
    read -p "Enter the kubernetes version: " kubeVersion
    read -p "Enter the zone: " aZones
}

rerunScript () {
    ## We want to retry the script! ##
    echo "####################################"
    echo "Initiating the rerun of script.."
    echo "####################################"
    ## need to reset the variable ##
    retryScript=""
    ## call the functions to begin from start ##
    getValues
    createNodePool
}

abortScript () {
    ## Just abort the script, display the variables! ##
    echo "Aborting the script.."
    echo "Subscription : ${subscriptionId}"
    echo "Resource Group : ${resourceGroup}"
    echo "Clsuter Name : ${clusterName}"

    exit
}

createNodePool () {
        set +e ## disable immediate exit from failure!
        if [[ ${temp} == 'yes' ]]
        then
                ## temp node pool creation ##
                cmd="az aks nodepool add --resource-group ${resourceGroup} --cluster-name ${clusterName} --name ${nodePool}tmp \
                --node-count ${nodeCount} \
                --mode ${modeOption} \
                --node-osdisk-type Managed \
                --node-osdisk-size ${nodeOsDiskSize} \
                --node-vm-size ${nodeVmSize} \
                --node-taints ${applyTaints} \
                --labels ${applyLabels} \
                --tags ${applyTags} \
                --kubernetes-version ${kubeVersion} \
                --max-pods ${maxPods}"

                if [[ ! -z ${aZones} ]]
                then
                    cmd="$cmd --zones ${aZones}"
                    ${cmd}
                else
                    ${cmd}
                fi


                if [[ $? -ne 0 ]]
                then
                    echo "Nodepool creation failed.."

                    ## Check if the user wants to rerun the script! ##
                    read -p "Do you want to retry [ yes || no ]: " retryScript
                fi
        else
                ## Actual node creation ##
                cmd="az aks nodepool add --resource-group ${resourceGroup} --cluster-name ${clusterName} --name ${nodePool} \
                --node-count ${nodeCount} \
                --mode ${modeOption} \
                --node-osdisk-type Managed \
                --node-osdisk-size ${nodeOsDiskSize} \
                --node-vm-size ${nodeVmSize} \
                --node-taints ${applyTaints} \
                --labels ${applyLabels} \
                --tags ${applyTags} \
                --kubernetes-version ${kubeVersion} \
                --max-pods ${maxPods}"

                if [[ ! -z ${aZones} ]]
                then
                    cmd="$cmd --zones ${aZones}"
                    ${cmd}
                else
                    ${cmd}
                fi

                if [[ $? -ne 0 ]]
                then
                    echo "Nodepool creation failed. Exiting.."
                    ## Check if the user wants to rerun the script! ##
                    read -p "Do you want to retry [ yes || no ]: " retryScript
                fi
                
        fi

        ### If the script failed, check if they want to rerun or abort! ###
        if [[ ${retryScript} == "yes" ]]
        then
            ## call the retry script! ##
            rerunScript
        elif [[ ${retryScript} == "no" ]]
        then
            ## abort the script ##
            abortScript
        ### The script ran fine, Nodepool created ###
        else
            echo "##########################"
            echo "### Nodepool has been created! "
            echo "##########################"
        fi
        set -e
}

checkNodePoolReady () {
        sleep 10
        ## Checking if the nodepool is up or not ##
        echo "### Waiting for the node to be ready state ###"
        if [[ ${temp} == "yes" ]]
        then
                ## check if node is up ##
                while [[ $(kubectl get nodes | grep "${nodePool}tmp" | wc -l) -le 0 ]]
                do
                        echo "### NodePool is not up yet.. Checking in 10 seconds..###"
                        sleep 10
                done
                echo "### Node is now Up! Checking if the node is in Ready state! ###"
                ## Check if node is ready! ##
                nodeReady=$(kubectl get nodes | grep "${nodePool}tmp" | awk '{ print $2 }')
                while [[ ${nodeReady} != "Ready" ]]
                do
                        nodeReady=$(kubectl get nodes | grep "${nodePool}tmp" | awk '{ print $2 }')
                        echo "### Node is up, but not Ready yet! Checking in 10 seconds ###"
                        sleep 10
                done
        ## checking for actual node creation and ready state!
        else
                while [[ $(kubectl get nodes | grep "${nodePool}" | wc -l) -le 0 ]]
                do
                        echo "### NodePool is not up yet.. Checking in 10 seconds.. ###"
                        sleep 10
                done
                echo "### Node is now Up! Checking if the node is in Ready state! ###"
                ## Check if node is ready! ##
                nodeReady=$(kubectl get nodes | grep "${nodePool}" | grep -v tmp | awk '{ print $2 }')
                while [[ ${nodeReady} != "Ready" ]]
                do
                        nodeReady=$(kubectl get nodes | grep "${nodePool}" | grep -v tmp | awk '{ print $2 }')
                        echo "### Node is up, but not Ready yet! Checking in 10 seconds ###"
                        sleep 10
                done
        fi

        echo ""
        echo "######################################"
        echo "### Node is now UP and in READY State ###"
        echo "######################################"
        echo ""

}

checkIfNodeDisabled () {
        echo ""
        confirmUser=no
        while [[ ${confirmUser} == "no" ]]
        do
                echo "### kubectl get nodes output! ###"
                kubectl get nodes | grep ${nodeName}
                read -p "Is the required node Scheduled Disabled..? [[ yes || no ]] " confirmUser
        done
}

drainCordonNode () {
        echo "### Draining the Node! ###"
        echo ""
        kubectl get nodes | grep ${nodePool}
        echo ""
        ### Check if there are more than 1 node in the nodepool ###
        read -p "Please enter the number of nodes to drain: " nodeNo
        for i in $(seq 1 $nodeNo);
        do
            kubectl get nodes | grep ${nodePool}
            read -p "Please enter the node name to drain from above: " nodeName
            kubectl drain ${nodeName} --ignore-daemonsets --delete-emptydir-data
            checkIfNodeDisabled
        done
}

deleteConfirmation () {
        echo ""
        nodeDeleted=no
        while [[ ${nodeDeleted} == "no" ]]
        do
            echo ""
            echo "### kubectl get nodes output! ###"
            kubectl get nodes | grep ${nodePool}
            read -p "Is the required nodePool deleted..? [[ yes || no ]]: " nodeDeleted
        done

        echo ""
        echo "#########################"
        echo "### Node pool has been deleted successfully ###"
        echo "#########################"
}

deleteNodePool () {
        if [[ ${temp} == "yes" ]]
        then
            echo ""
            echo "##############################"
            echo "### Deleting existing node pool! ###"
            echo "##############################"
            az aks nodepool delete --resource-group ${resourceGroup} --cluster-name ${clusterName} -n ${nodePool}

        else
            echo ""
            echo "############################"
            echo "### Deleting Temporary Node Pool ###"
            echo "############################"
            az aks nodepool delete --resource-group ${resourceGroup} --cluster-name ${clusterName} -n ${nodePool}tmp
        fi

        ## check if node is deleted ##
        deleteConfirmation
}

confSubscription () {
    setSubscription
    setAksLogin
}

commonFuncs () {
        getValues
        createNodePool
        checkNodePoolReady
        drainCordonNode
        deleteNodePool
}

addNodepool () {
    ## Configure the subscription ##
    confSubscription

    ## Because easier to call my script as it creates the original node when temp is set to no ##
    temp=no

    echo "##############################################"
    echo "### Creating New Nodepool as per request.. ###"
    echo "##############################################"
    getValues
    echo "az aks nodepool add --resource-group ${resourceGroup} --cluster-name ${clusterName} --name ${nodePool} --node-count ${nodeCount} --mode ${modeOption} --node-osdisk-type Managed --node-osdisk-size ${nodeOsDiskSize} --node-vm-size ${nodeVmSize} --node-taints ${applyTaints} --labels ${applyLabels} --tags ${applyTags} --max-pods ${maxPods}"
    createNodePool
    checkNodePoolReady
}

deleteNode () {
    ## Configure the subscription ##
    confSubscription

    ## Because easier to call my script as it creates the original node when temp is set to no ##
    temp=yes

    echo "##############################################"
    echo "Nodepool that will be deleted.. "
    kubectl get nodes | grep ${nodePool}
    echo "##############################################"

    echo "Command used to delete the Nodepool.."
    echo "az aks nodepool delete --resource-group ${resourceGroup} --cluster-name ${clusterName} -n ${nodePool}"

    deleteNodePool

}

nodeCount () {
    confSubscription
    read -p "Enter the new node count: " nodeCountNumber
    az aks nodepool scale --resource-group ${resourceGroup} --cluster-name ${clusterName} --name ${nodePool} --node-count ${nodeCountNumber}
}

main () {

        ## Set current path ##
        currentPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

        ## Configure the subscription ##
        confSubscription
        
        backupOldNodepool
        temp=yes
        echo "##################################################################"
        echo "Creating Temporary Node pool, please enter the values accordingly!"
        echo "##################################################################"
        commonFuncs
        temp=no
        echo "##################################################################"
        echo "Creating New Nodepool with new configuration"
        echo "##################################################################"
        sleep 10
        cat ${currentPath}/${nodePool}.json
        commonFuncs
}

if [[ ! -z ${subscriptionId} && ! -z ${resourceGroup} && ! -z ${clusterName} && ! -z ${nodePool} ]]
then
    if [[ ${nodeAction} == "upgrade" ]]
    then
        ##call the main function##
        main
    elif [[ ${nodeAction} == "add" ]]
    then
        ## function to add new nodepool ##
        addNodepool
    elif [[ ${nodeAction} == "delete" ]]
    then
        ## function to delete the nodepool ##
        deleteNode
    elif [[ ${nodeAction} == "count" ]]
    then
        nodeCount
    else
        ## Action to perform missing ##
        echo "Wrong choice provided.. Exiting from script.."
        exit
    fi
else
    ## Cluster related informaiton missing ##
    echo "Please provide values for requested variables.."
    exit
fi
