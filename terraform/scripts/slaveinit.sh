#!/bin/sh

# echo "This is a test script."

apt-get update -y 
sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg -y

curl -sL https://packages.microsoft.com/keys/microsoft.asc | 
    gpg --dearmor | 
    sudo tee /etc/apt/trusted.gpg.d/microsoft.asc.gpg > /dev/null

AZ_REPO=$(lsb_release -cs)
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | 
    sudo tee /etc/apt/sources.list.d/azure-cli.list

sudo apt-get update -y
sudo apt-get install azure-cli -y


apt-get remove docker docker-engine docker.io -y 
apt install docker.io cifs-utils -y  
systemctl start docker 
systemctl enable docker

resourceGroupName="${FILE_RG}"
storageAccountName="${STOACC_NAME}"
fileShareName="${FILESHARE_NAME}"

mntPath="/mnt/jmeter"

mkdir -p $mntPath

az login --identity

httpEndpoint=$(az storage account show \
    --resource-group $resourceGroupName \
    --name $storageAccountName \
    --query "primaryEndpoints.file" | tr -d '"')
smbPath=$(echo $httpEndpoint | cut -c7-$(expr length $httpEndpoint))$fileShareName

storageAccountKey=$(az storage account keys list \
    --resource-group $resourceGroupName \
    --account-name $storageAccountName \
    --query "[0].value" | tr -d '"')

mount -t cifs $smbPath $mntPath -o vers=3.0,username=$storageAccountName,password=$storageAccountKey,serverino


docker run -p 1099:1099 -d -v /mnt/jmeter:/jmeter --entrypoint '/bin/sh' justb4/jmeter:5.1.1 -c 'cp -r /jmeter/* .; /entrypoint.sh -s -J server.rmi.ssl.disable=true'