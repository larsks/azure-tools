#!/bin/sh

while getopts p: ch; do
	case $ch in
	(p) OPT_PASSWORD="$OPTARG";;
	esac
done
shift $(( $OPTIND - 1 ))

echo "Adding Azure support to $1".

virt-customize -a "$1" \
	${OPT_PASSWORD:+--root-password password:"$OPT_PASSWORD"} \
	--install epel-release \
	--install WALinuxAgent \
	--upload cloud-init.rpm:/tmp/cloud-init.rpm \
	--run-command "yum -y install /tmp/cloud-init.rpm" \
	--upload cloud.cfg.d/azure.cfg:/etc/cloud/cloud.cfg.d/azure.cfg \
	--upload waagent.conf:/etc/waagent.conf \
	--upload waagent.service:/etc/systemd/system/waagent.service \
	--selinux-relabel

# Install alternate version of the Azure data source
#	--upload DataSourceAzure.py:/usr/lib/python2.7/site-packages/cloudinit/sources/DataSourceAzure.py \

# Use this to disable selinux
#	--run-command "sed -i '/^SELINUX=/ s/=.*/=permissive/' /etc/selinux/config" \
