#!/bin/sh

cp $HOME/lib/libvirt-images/centos-7-cloud.qcow2 centos-azure.qcow2
sh azurify.sh -p changeme centos-azure.qcow2
sh make-azure-vhd.sh centos-azure.qcow2
