#!/usr/bin/env bash

#Full clone VM vm_source_name to vm_dest_name with all snapshots

Source_VM_Name="vm_source_name"
Destination_VM_Name="vm_dest_name"
old_uuid=$(virsh domuuid $Source_VM_Name)
old_mac=$(virsh domiflist $Source_VM_Name | sed -e '1,2d' -e '/^$/d' | awk '{ print $ 5}')

virt-clone --original $Source_VM_Name --name $Destination_VM_Name --file /var/lib/libvirt/images/$Destination_VM_Name.qcow2 --print-xml > $Destination_VM_Name.xml

rsync -ah --progress /var/lib/libvirt/images/$Source_VM_Name.qcow2 /var/lib/libvirt/images/$Destination_VM_Name.qcow2

virt-sysprep -a /var/lib/libvirt/images/$Destination_VM_Name.qcow2

virsh define $Destination_VM_Name.xml
new_uuid=$(virsh domuuid $Destination_VM_Name)
new_mac=$(virsh domiflist $Destination_VM_Name | sed -e '1,2d' -e '/^$/d' | awk '{ print $ 5}')

virsh snapshot-list $Source_VM_Name |sed -e '1,2d' -e '/^$/d'|cut -d' ' -f2| while read -r line; do
  virsh snapshot-dumpxml $Source_VM_Name --snapshotname "${line}" --security-info > "${line}.xml"
  sed -i -E "s/(.*<uuid>)${old_uuid}(<\/uuid>)/\1${new_uuid}\2/" "${line}.xml"
  sed -i -E "s/(.*<mac address=')${old_mac}('\/>)/\1${new_mac}\2/" "${line}.xml"
  sed -i -E "s/(.*<name>)${Source_VM_Name}(<\/name>)/\1${Destination_VM_Name}\2/" "${line}.xml"
  sed -i -E "s/(.*<source file='\/var\/lib\/libvirt\/images\/)${Source_VM_Name}(\.qcow2'\/>)/\1${Destination_VM_Name}\2/" "${line}.xml"
  virsh snapshot-create $Destination_VM_Name "${line}.xml" --redefine
done
