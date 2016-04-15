#!/bin/sh

virt-customize -a "$1" \
	--install epel-release \
	--install WALinuxAgent \
	--upload cloud-init-0.7.7-2gita12ffde.el7.centos.x86_64.rpm:/tmp/cloud-init.rpm \
	--run-command "yum -y install /tmp/cloud-init.rpm" \
	--upload cloud.cfg.d/azure.cfg:/etc/cloud/cloud.cfg.d/azure.cfg \
	--upload waagent.conf:/etc/waagent.conf \
	--run-command "systemctl enable waagent"
