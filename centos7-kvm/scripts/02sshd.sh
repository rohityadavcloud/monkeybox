set -eux

sed -i 's/^GSS/\#GSS/g' /etc/ssh/sshd_config
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "UseDNS no" >> /etc/ssh/sshd_config

