#!/bin/bash
# MeowCI - MonkeyBox based CI
# Requires: cmk, jq, ssh-client, sshpass
set +e

# Configurables
name=$1
hyp=kvm
repo="http://packages.shapeblue.com/cloudstack/upstream/centos7/4.11"
version=cs411 #FIXME
storageip=192.168.1.10
kvmtemplateid="ff36e0fc-d45b-4763-95f0-4a582292ca2e"
zoneid="14468d06-ac99-4967-8d6f-bbab8b6274fb"
svcoffid="18f46c83-9985-49b6-99c8-e80a1563edfc"

# Methods
function setup_mgmt() {
    publicip=$1
    repo=$2
    sshpass -p 'password' ssh -o StrictHostKeyChecking=no root@$publicip "hostnamectl;
cat << EOF > /etc/yum.repos.d/cloudstack.repo
[cloudstack]
name=cloudstack
baseurl=$repo
enabled=1
gpgcheck=0
EOF
iptables -F; iptables -X;
yum install -y cloudstack-management cloudstack-usage cloudstack-marvin cloudstack-integration-tests mariadb-server;
systemctl enable mariadb;
systemctl start mariadb;
cloudstack-setup-databases cloud:cloud@localhost --deploy-as=root: ;
cloudstack-setup-management;
systemctl enable cloudstack-management"

}

function setup_kvm() {
    publicip=$1
    kvmip=$2
    repo=$3

    sshpass -p 'password' ssh -o StrictHostKeyChecking=no root@$publicip "sshpass -p 'password' ssh -o StrictHostKeyChecking=no root@$kvmip 'hostnamectl;
cat << EOF > /etc/yum.repos.d/cloudstack.repo
[cloudstack]
name=cloudstack
baseurl=$repo
enabled=1
gpgcheck=0
EOF
iptables -F; iptables -X;
yum install -y cloudstack-agent;
systemctl enable cloudstack-agent'"

}

function setup_storage() {
    name=$1
    version=$2
    mkdir -p /export/testing/$name/primary
    mkdir -p /export/testing/$name/primary1
    mkdir -p /export/testing/$name/primary2
    mkdir -p /export/testing/$name/secondary
    cp -r /export/goldmaster/$version/* /export/testing/$name/secondary/
}

function setup_marvin() {
    name=$1
    publicip=$2
    storageip=$3

    while ! nc -vzw 5 $publicip 8080 2>&1 > /dev/null; do sleep 5; done
    sshpass -p 'password' scp -o StrictHostKeyChecking=no adv-kvm.cfg root@$publicip:/marvin/

    sshpass -p 'password' ssh -o StrictHostKeyChecking=no root@$publicip "
cmk update configuration name=integration.api.port value=8096;
systemctl restart cloudstack-management;
mkdir -p /marvin/tests;
cp -r /usr/share/cloudstack-integration-tests/* /marvin/tests;
ln -s /usr/lib/python2.7/site-packages/marvin/config/test_data.py /marvin/;
sed -i 's/dl.openvm.eu/$storageip\/openvm/g' test_data.py;
sed -i 's/nfs.*primary/nfs:\/\/$storageip\/export\/testing\/$name\/primary/g' /marvin/adv-kvm.cfg;
sed -i 's/nfs.*secondary/nfs:\/\/$storageip\/export\/testing\/$name\/secondary/g' /marvin/adv-kvm.cfg;

while ! nc -vzw 5 $publicip 8080 2>&1 > /dev/null; do sleep 5; done
python -m marvin.deployDataCenter -i adv-kvm.cfg"

# cmk list hosts type=SecondaryStorageVM | jq -r '.host[0].state' # check ssvm is up
}

function runtests() {
    publicip=$1
    # Cp runner and run test runners
}

cmk set asyncblock true
cmk set output json

# Create CI Project
projectid=$(cmk create project name=$name displaytext=$name | jq -r '.project.id')

## Create Monkey Network
netoffid=$(cmk list networkofferings zoneid=$zoneid guestiptype=Isolated supportedservices=SourceNat state=Enabled | jq -r '.networkoffering[0].id')
networkid=$(cmk create network projectid=$projectid zoneid=$zoneid name=net-$name displaytext=net-$name networkofferingid=$netoffid gateway="172.20.0.1" netmask="255.255.0.0" | jq -r '.network.id')
cmk create egressfirewallrule projectid=$projectid networkid=$networkid cidrlist="0.0.0.0/0" destcidrlist="0.0.0.0/0" protocol=all > /dev/null

## Deploy MonkeyBoxes
msid=$(cmk deploy virtualmachine name="$name"-mgmt1 displayname="$name"-mgmt1 projectid=$projectid zoneid=$zoneid templateid=$kvmtemplateid hypervisor=KVM serviceofferingid=$svcoffid iptonetworklist[0].networkid=$networkid iptonetworklist[0].ip="172.20.1.5" | jq -r '.virtualmachine.id')
hyp1id=$(cmk deploy virtualmachine name="$name"-"$hyp"1 displayname="$name"-"$hyp"1 projectid=$projectid zoneid=$zoneid templateid=$kvmtemplateid hypervisor=KVM serviceofferingid=$svcoffid iptonetworklist[0].networkid=$networkid iptonetworklist[0].ip="172.20.1.10" | jq -r '.virtualmachine.id')
hyp2id=$(cmk deploy virtualmachine name="$name"-"$hyp"2 displayname="$name"-"$hyp"2 projectid=$projectid zoneid=$zoneid templateid=$kvmtemplateid hypervisor=KVM serviceofferingid=$svcoffid iptonetworklist[0].networkid=$networkid iptonetworklist[0].ip="172.20.1.11"| jq -r '.virtualmachine.id')

## Enabled PF rules
publicipid=$(cmk list publicipaddresses projectid=$projectid associatednetworkid=$networkid forvirtualnetwork=true | jq -r '.publicipaddress[0].id')
publicip=$(cmk list publicipaddresses projectid=$projectid associatednetworkid=$networkid forvirtualnetwork=true | jq -r '.publicipaddress[0].ipaddress')
cmk create portforwardingrule ipaddressid=$publicipid privateport=22 privateendport=8080 publicport=22 publicendport=8080 protocol=tcp virtualmachineid=$msid openfirewall=true > /dev/null

# Setup management + mysql server
setup_mgmt $publicip $repo

# Setup KVM hosts
setup_kvm $publicip 172.20.1.10 $repo
setup_kvm $publicip 172.20.1.11 $repo

# Setup Storage
setup_storage $name $version

# Setup Marvin and Deploy DC
setup_marvin $name $publicip $storageip

# Kick tests
runtests $publicip
