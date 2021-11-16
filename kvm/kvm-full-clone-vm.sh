#!/usr/bin/env bash

#Full clone VM vm_source_name to vm_dest_name with all snapshots

src_vm_name="vm_source_name"
dst_vm_name="vm_dest_name"
old_uuid=$(virsh domuuid $src_vm_name)
old_mac=$(virsh domiflist $src_vm_name | sed -e '1,2d' -e '/^$/d' | awk '{ print $ 5}')

virt-clone --original $src_vm_name --name $dst_vm_name --file /var/lib/libvirt/images/$dst_vm_name.qcow2 --print-xml > $dst_vm_name.xml

rsync -ah --progress /var/lib/libvirt/images/$src_vm_name.qcow2 /var/lib/libvirt/images/$dst_vm_name.qcow2

virt-sysprep -a /var/lib/libvirt/images/$dst_vm_name.qcow2

virsh define $dst_vm_name.xml
new_uuid=$(virsh domuuid $dst_vm_name)
new_mac=$(virsh domiflist $dst_vm_name | sed -e '1,2d' -e '/^$/d' | awk '{ print $ 5}')

virsh snapshot-list win7_1_def --tree | sed -E "s/ *.{1,2} +//" | sed -E "s/\|//" | sed -E "/^$/d" |sed -e '1,2d' -e '/^$/d'|cut -d' ' -f2| while read -r line; do
  new_snpsh_name=$(echo "${line}" | sed "s/${src_vm_name}/${dst_vm_name}/")
  virsh snapshot-dumpxml $src_vm_name --snapshotname "${line}" --security-info > "${line}.xml"
  sed -i -E "s/(.*<uuid>)${old_uuid}(<\/uuid>)/\1${new_uuid}\2/" "${line}.xml"
  sed -i -E "s/(.*<mac address=')${old_mac}('\/>)/\1${new_mac}\2/" "${line}.xml"
  sed -i -E "s/(.*<name>)${src_vm_name}(<\/name>)/\1${dst_vm_name}\2/" "${line}.xml"
  sed -i -E "s/(.*<name>)${line}(<\/name>)/\1${new_snpsh_name}\2/" "${line}.xml"
  sed -i -E "s/(.*<source file='\/var\/lib\/libvirt\/images\/)${src_vm_name}(\.qcow2'\/>)/\1${dst_vm_name}\2/" "${line}.xml"
  virsh snapshot-create $dst_vm_name "${line}.xml" --redefine
done
