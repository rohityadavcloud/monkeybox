# MonkeyKey

Create a NAT based virtual network in 172.20.0.0/16, your gateway would be
172.20.0.1.

Your base platform (laptop) will have the gateway IP `172.20.0.1`.

Run your favourite IDE/text-editors, your management server, MySQL server, NFS
server (secondary and primary storages) from 172.20.0.1.

### Default IPs

MonkeyBox CentOS7 KVM: 172.20.1.10
MonkeyBox XenServer 6.5: 172.20.1.15

### Copying agent scripts and code

Put the following in your `~/.bashrc` or `~/.zshrc`:

```
agentscp() {
  ROOT=$PWD
  echo "[acs agent] Syncing changes to agent: $1"

  echo "[acs agent] Copied systemvm.iso"
  scp $ROOT/systemvm/dist/systemvm.iso  root@$1:/usr/share/cloudstack-common/vms/

  echo "[acs agent] Syncing python lib changes to agent: $1"
  scp -r $ROOT/python/lib/* root@$1:/usr/lib64/python2.6/site-packages/ 2>/dev/null || true
  scp -r $ROOT/python/lib/* root@$1:/usr/lib64/python2.7/site-packages/ 2>/dev/null || true

  echo "[acs agent] Syncing scripts"
  scp -r $ROOT/scripts/* root@$1:/usr/share/cloudstack-common/scripts/

  echo "[acs agent] Syncing kvm hypervisor jars"
  ssh root@$1 "rm -f /usr/share/cloudstack-agent/lib/*"
  scp -r $ROOT/plugins/hypervisors/kvm/target/*jar root@$1:/usr/share/cloudstack-agent/lib/
  scp -r $ROOT/plugins/hypervisors/kvm/target/dependencies/*jar root@$1:/usr/share/cloudstack-agent/lib/

  echo "[acs agent] Syncing cloudstack-agent config and scripts"
  scp $ROOT/agent/target/transformed/log4j-cloud.xml root@$1:/etc/cloudstack/agent/
  ssh root@$1 "sed -i 's/INFO/DEBUG/g' /etc/cloudstack/agent/log4j-cloud.xml"
  ssh root@$1 "sed -i 's/logs\/agent.log/\/var\/log\/cloudstack\/agent\/agent.log/g' /etc/cloudstack/agent/log4j-cloud.xml"
  scp $ROOT/agent/target/transformed/libvirtqemuhook root@$1:/usr/share/cloudstack-agent/lib/

  scp $ROOT/agent/target/transformed/cloud-setup-agent root@$1:/usr/bin/cloudstack-setup-agent
  ssh root@$1 "sed -i 's/@AGENTSYSCONFDIR@/\/etc\/cloudstack\/agent/g' /usr/bin/cloudstack-setup-agent"
  scp $ROOT/agent/target/transformed/cloud-ssh root@$1:/usr/bin/cloudstack-ssh
  scp $ROOT/agent/target/transformed/cloudstack-agent-upgrade root@$1:/usr/bin/cloudstack-agent-upgrade
  ssh root@$1 "chmod +x /usr/bin/cloudstack*"

  echo "[acs agent] Copied all files, start hacking!"
}

Build CloudStack code, cd to the git repository's root directory and run the
following to transfer new jars, files, configs etc:

    agentscp YOUR-MONKEYBOX-IP

If needed, manually restart the agent using:

    systemctl restart cloudstack-agent


```


