set -eux

yum -y update

cat > /etc/motd << EOF

   __?.o/  CentOS 7 KVM MonkeyBox
  (  )#    Built from https://github.com/rhtyd/monkeybox.git
 (___(_)   Happy CloudStack hacking!

EOF

# Essentials
yum install -y tmux vim htop wget jq

# Fix hostname to get from dhcp, otherwise use localhost
hostnamectl set-hostname localhost --static

# Setup public key access
mkdir -pm 700 /root/.ssh
curl https://api.github.com/users/rhtyd/keys | jq -r '.[].key' > /root/.ssh/authorized_keys
chmod -R go-rwsx /root/.ssh
