#!/bin/bash
SYNTAX="syntax is \#fcreate \$hostname"
ostab=/newpart/etc/fstab
mtab=/newpart/etc/mtab
set -x
create_dirs () {
        mkdir /newpart/dev
        mkdir /newpart/sys
        mkdir /newpart/proc 
        sleep 5
        create_binds
}

create_binds () {
        mount -o bind /dev /newpart/dev
        mount -o bind /sys /newpart/sys
        mount -t proc none /newpart/proc
        sleep 5
        do_fstab
}

do_fstab () {
        cp /newpart/etc/fstab /newpart/etc/fstab.orig
        cp /newpart/etc/mtab /newpart/etc/mtab.orig
        sed -i '/UUID.*/d' $ostab
        echo "/dev/sda1 /boot                   ext4    defaults        1 2" >> $ostab
        echo "#/dev/cciss/c0d0p1 /boot                   ext4    defaults        1 2" >> $ostab
        create_initrd
}


create_initrd () {
        mv /newpart/etc/modprobe.conf /newpart/etc/modprobe.orig
        cp /etc/modprobe.conf /newpart/etc/modprobe.conf
        image=$(chroot /newpart ls /lib/modules | head -1)
        chroot /newpart mkinitrd /tmp/initramfs-${host}-${image}.img ${image}
        echo "root:sasuser" | chroot /newpart chpasswd
        sleep 5
        copy_bootfiles
}

copy_bootfiles () {
        cp /newpart/tmp/initramfs-${host}-${image}.img /boot
        cp /newpart/boot/vmlinuz-${image} /boot/vmlinuz-${host}-${image}
        cp /newpart/boot/config-${image} /boot/config-${host}-${image}
        sleep 5
        append_grub
}

append_grub () {
	cp  /var/www/html/customer/blogs/clogs/grub.conf /var/www/html/customer/blogs/clogs/grub.conf.$(date|awk -F" " '{print $4}')
        cat << EOF >> /var/www/html/customer/blogs/clogs/grub.conf
title Centos ${host} (${image})
        root (hd0,0)
	kernel /vmlinuz-${host}-${image} ro root=/dev/mapper/vgroot-lvroot rd_NO_LUKS  KEYBOARDTYPE=pc KEYTABLE=uk LANG=en_US.UTF-8 rd_NO_MD SYSFONT=latarcyrheb-sun16 crashkernel=auto rd_LVM_LV=vgroot/lvroot rd_LVM_LV=vgroot/lvroot rd_NO_DM rhgb quiet
	initrd /initramfs-${host}-${image}.img
EOF
	sed -i s/default=0/default=1/g /boot/grub/grub.conf
	do_network
}


do_network () {
rsync -av /newpart/etc/sysconfig/network-scripts /newpart/etc/sysconfig/network-orig
for i in `ifconfig | grep eth | awk -F" " '{print $1}'`
	    do
            FILE=/etc/sysconfig/network-orig/ifcfg-
	    correctmac=$(ifconfig $i |grep -i hwadd| gawk -Fdr  '{print $2}'|sed 's/^[ ]//')
            wrongmac=$(grep -i hwaddr $FILE$i|gawk -F= '{print $2}')
            sed -i "s;$wrongmac;$correctmac;g" $FILE$i
            done
killall_agents_and_emailers
}


killall_agents_and_emailers(){
mv /newpart/etc/rc3.d/S95vvagent /newpart/etc/rc3.d/K95vvagent
mv /newpart/etc/rc3.d/S80sendmail /newpart/etc/rc3.d/K80sendmail
}


host=${1:?rerun but specify a hostname}
if (($# > 1)); then echo $SYNTAX 1>&2; exit; fi

create_dirs
