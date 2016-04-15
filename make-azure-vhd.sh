#!/bin/sh

MB=$((1024 * 1024))

src="$1"
raw="${1%.qcow2}.img"
vhd="${1%.qcow2}.vhd"

trap "rm -f $raw" EXIT

echo "converting $src to raw image $raw"
qemu-img convert -f qcow2 -O raw "$1" "$raw"
size=$(qemu-img info -f raw --output json "$raw" |
	 jq '."virtual-size"')
rounded_size=$(( ($size/$MB + 1) * $MB))

echo "resizing $raw to $rounded_size bytes"
qemu-img resize -f raw "$raw" $rounded_size

echo "converting $raw to vhd image $vhd"
qemu-img convert -f raw -O vpc -o subformat=fixed,force_size \
	"$raw" "$vhd"
