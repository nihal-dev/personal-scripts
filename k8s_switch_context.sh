#!/bin/bash

podNamespace () {
    read -p "Please enter the pod name: " podName
    read -p "Please provide namespace name: " nsName
}

#check if context has to be updated in k8s
if [[ $1 == 'kswitchcontext' ]]
then
    read -p "Enter context name: " context_name
    kubectl config use-context ${context_name}

## Delete context from kubeconfig file
elif [[ $1 == 'kdeletecontext' ]]
then
    read -p "Enter context name: " context_name
    kubectl config delete-context ${context_name}

#check if namespace for a particular context has to be updated in k8s
elif [[ $1 == 'kns' ]]
then
    read -p "Enter namespace: " namespace
    kubectl config set-context --current --namespace=${namespace}

##Get access to nodes as pods.
elif [[ $1 == 'kdebug' ]]
then
    read -p "Enter the node name: " nodeName
    echo "Context = $(kubectl config current-context)"
    read -p "Is the context correct? [ yes || no ]: " contextOption

    ## Just to confirm if the context is correct
    ## before creating the debug pod. 
    if [[ ${contextOption} == "yes" ]]
    then
        winpty kubectl debug node/${nodeName} -it --image=mcr.microsoft.com/dotnet/runtime-deps:6.0
    else
        echo "Incorrect context, please run the script again"
    fi

### To access the ITK8s cluster
elif [[ $1 == 'kitk8s' ]]
then
    ssh -i /c/Users/niysha/itk8s-internal rocky@server.com

### To exec into a pod in particular cluster
elif [[ $1 == 'kexec' ]]
then
    podNamespace
    winpty kubectl exec -it -n ${nsName} ${podName} -- //bin/bash

### To describe a particular pod
elif [[ $1 == 'kdesc' ]]
then
    podNamespace
    kubectl describe pod ${podName} -n ${nsName}
fi
