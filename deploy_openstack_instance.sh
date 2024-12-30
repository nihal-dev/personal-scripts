#!/bin/bash

read -p "Enter your username: " userName 
read -s -p "Enter your password: " passWord 
echo " "
read -p "Enter project name: " projectName

# Create the openstack rc file to authenticate to openstack
cat <<EOF > ${projectName}-admin_rc
export OS_USER_DOMAIN_NAME=default
export OS_PROJECT_DOMAIN_NAME=default
export OS_USERNAME=${userName}
export OS_PROJECT_NAME=${projectName}
export OS_IDENTITY_API_VERSION=3
export OS_PASSWORD=${passWord}
export OS_AUTH_URL=<your openstack url>
export DB_PASSWD=<your password>

EOF

source ${projectName}-admin_rc

echo "Checking if the credentials are correct.."
openstack project show ${projectName}

# if the creds are incorrect, then exit..
if [[ $? != 0 ]]
then
	echo "Please provide correct credentials"
	exit
fi

read -p "Enter the image you want to use [ rocky-9.4 | rhel-9.2 ] : " imageName
openstack image list | grep ${imageName}

read -p "Please provide the image ID to use: " imageId
read -p "Please provide instance name: " instanceName

echo "Creating the instance in ${projectName} project.."
sleep 5

openstack server create --image ${imageId} --flavor <flavor-id> --nic <nic-id> --security-group <security-group> --key-name <key-name> ${instanceName}
