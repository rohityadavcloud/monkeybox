set -eux

# Get eth0 eth1 as default nics
sed -i 's/quiet.*/quiet net.ifnames=0"/g' /etc/default/grub
grub2-mkconfig -o /boot/grub2/grub.cfg

exit 0
