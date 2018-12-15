set -ux

# Remove network rules
rm -f /etc/udev/rules.d/70-persistent*
rm -f /var/lib/dhclient/*

# Remove SSH host keys
rm -f /etc/ssh/ssh_host*

# Clean template
yum -y clean all
cat /dev/null > /var/log/audit/audit.log 2>/dev/null
cat /dev/null > /var/log/wtmp 2>/dev/null
logrotate -f /etc/logrotate.conf 2>/dev/null
rm -f /var/log/*-* /var/log/*.gz || true
