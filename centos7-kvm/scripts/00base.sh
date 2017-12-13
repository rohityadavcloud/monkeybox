set -eux

yum -y update

cat > /etc/motd << EOF

   __?.o/  CentOS 7 KVM MonkeyBox
  (  )#    Built from https://github.com/rhtyd/monkeybox.git
 (___(_)   Happy hacking CloudStack!

EOF

# Essentials
yum install -y tmux vim htop wget

# Setup public key access
mkdir -pm 700 /root/.ssh
curl -o /root/.ssh/authorized_keys 'http://rohityadav.cloud/ssh.pub'
chmod -R go-rwsx /root/.ssh
