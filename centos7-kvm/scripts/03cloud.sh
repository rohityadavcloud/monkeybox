set -exu

# KVM and CloudStack agent dependencies
yum install -y ntp java-1.8.0-openjdk-headless.x86_64 python-argparse python-netaddr net-tools bridge-utils ebtables ethtool iproute ipset iptables libvirt libvirt-python openssh-clients perl qemu-img qemu-kvm libuuid glibc nss-softokn-freebl

# Management server dependecies and services
yum install -y mariadb-server nfs-utils mysql-connector-java genisoimage
systemctl disable mariadb

# Install cloudmonkey
wget -O /bin/cmk https://github.com/apache/cloudstack-cloudmonkey/releases/download/6.0.0-testing-beta2/cmk.linux.amd64
chmod +x /bin/cmk

# Fix SELinux
setenforce 0
sed -i 's/SELINUX=.*/SELINUX=permissive/g' /etc/selinux/config

# Fix MySQL
sed -i "/\[mysqld\]/a innodb_rollback_on_timeout=1" /etc/my.cnf
sed -i "/\[mysqld\]/a innodb_lock_wait_timeout=600" /etc/my.cnf
sed -i "/\[mysqld\]/a max_connections=700" /etc/my.cnf
sed -i "/\[mysqld\]/a log-bin=mysql-bin" /etc/my.cnf
sed -i "/\[mysqld\]/a binlog-format = 'ROW'" /etc/my.cnf

# Marvin tests dependencies
yum install -y python-pip pyOpenSSL telnet tcpdump zlib-devel bzip2-devel openssl-devel xz-libs wget sqlite sqlite-devel python-paramiko python-setuptools python-devel mysql-devel openssl-devel ncurses-devel libxslt-devel libffi-devel openssh-askpass jq mariadb git screen sshpass at vim tmux mysql-connector-python gcc gcc-c++ make patch autoconf automake binutils
pip install pycrypto texttable

# Setup networking
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
TYPE=Ethernet
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=static
BRIDGE=cloudbr0
NM_CONTROLLED=no
EOF

cat > /etc/sysconfig/network-scripts/ifcfg-cloudbr0 <<EOF
TYPE=Bridge
DEVICE=cloudbr0
ONBOOT=yes
BOOTPROTO=dhcp
#IPADDR=172.20.1.10
#NETMASK=255.255.0.0
#GATEWAY=172.20.0.1
DNS1=1.1.1.1
DELAY=0
STP=yes
USERCTL=no
NM_CONTROLLED=no
EOF

# Setup iptables
iptables -I INPUT -p tcp -m tcp --dport 8080 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 8096 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 8787 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 22 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 1798 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 16509 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 16514 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 5900:6100 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 49152:49216 -j ACCEPT
iptables-save > /etc/sysconfig/iptables

# Setup libvirtd
cat > /etc/libvirt/libvirtd.conf <<EOF
listen_tls = 0
listen_tcp = 1
tcp_port = "16509"
auth_tcp = "none"
mdns_adv = 0
EOF
sed -i 's/#LIBVIRTD_ARGS="--listen"/LIBVIRTD_ARGS="--listen"/g' /etc/sysconfig/libvirtd
sed -i 's/#vnc_listen.*/vnc_listen = "0.0.0.0"/g' /etc/libvirt/qemu.conf

# Setup cloudStack-agent pkg
mkdir -p /etc/cloudstack/agent
mkdir -p /usr/share/cloudstack-agent/lib/
mkdir -p /usr/share/cloudstack-agent/plugins
mkdir -p /var/log/cloudstack/agent

# Setup cloudStack-common pkg
mkdir -p /usr/lib64/python2.7/site-packages/
mkdir -p /usr/share/cloudstack-common/scripts/
mkdir -p /usr/share/cloudstack-common/vms/
mkdir -p /usr/share/cloudstack-common/lib/
wget -O /usr/share/cloudstack-common/lib/jasypt-1.9.2.jar http://central.maven.org/maven2/org/jasypt/jasypt/1.9.2/jasypt-1.9.2.jar

cat > /etc/default/cloudstack-agent <<EOF
JAVA=/usr/bin/java
JAVA_HEAP_INITIAL=256m
JAVA_HEAP_MAX=2048m
JAVA_CLASS=com.cloud.agent.AgentShell
JAVA_TMPDIR=/usr/share/cloudstack-agent/tmp
EOF

cat > /usr/lib/systemd/system/cloudstack-agent.service <<EOF
[Unit]
Description=CloudStack Agent
Documentation=http://www.cloudstack.org/
Requires=libvirtd.service
After=libvirtd.service

[Service]
Type=simple
EnvironmentFile=-/etc/default/cloudstack-agent
ExecStart=/bin/sh -ec 'export ACP=\`ls /usr/share/cloudstack-agent/lib/*.jar /usr/share/cloudstack-agent/plugins/*.jar 2>/dev/null|tr "\\n" ":"\`; export CLASSPATH="\$ACP:/etc/cloudstack/agent:/usr/share/cloudstack-common/scripts"; mkdir -m 0755 -p \${JAVA_TMPDIR}; \${JAVA} -Djava.io.tmpdir="\${JAVA_TMPDIR}" -Xms\${JAVA_HEAP_INITIAL} -Xmx\${JAVA_HEAP_MAX} -cp "\$CLASSPATH" \$JAVA_CLASS'
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cloudstack-agent

cat > /etc/cloudstack/agent/agent.properties <<EOF
guid=
local.storage.uuid=
workers=5
host=172.20.0.1
port=8250
cluster=default
pod=default
zone=default
kvmclock.disable=true
domr.scripts.dir=scripts/network/domr/kvm
resource=com.cloud.hypervisor.kvm.resource.LibvirtComputingResource
hypervisor.type=kvm
guest.cpu.model=host-passthrough
public.network.device=cloudbr0
private.network.device=cloudbr0
guest.network.device=cloudbr0
host.reserved.mem.mb=0
EOF

cat > /etc/cloudstack/agent/environment.properties <<EOF
paths.pid=/var/run
paths.script=/usr/share/cloudstack-common
EOF

cat > /etc/profile.d/cloudstack-agent-profile.sh <<EOF
# need access to lsmod for adding host as non-root
PATH=$PATH:/sbin
EOF
