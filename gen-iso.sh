#!/bin/bash

set -x 


KICKSTART=$PWD/$1
ISO_IMAGE=$2

OPWD=$PWD
[ -z $ISO_IMAGE ] && ISO_IMAGE=CentOS-6.7-x86_64-minimal.iso
[ ! -f $KICKSTART ] && exit

yum -y install rsync yum-utils createrepo genisoimage isomd5sum

cd /tmp/
build=`mktemp -d`

if [ -d image ]
then
    umount /tmp/image
    rm -rf image/*
else
    mkdir image
fi

if [ ! -f $ISO_IMAGE ]
then
    wget http://centos.usonyx.net/main/6.7/isos/x86_64/$ISO_IMAGE
fi

mount -t iso9660 -o ro,loop $ISO_IMAGE image/
rsync --exclude=.discinfo -av image/ $build/

cp image/.discinfo $build/isolinux/
cp $KICKSTART $build/isolinux/ks.cfg

cd $build/

# build a new repository
mv repodata/*minimal-x86_64.xml comps.xml && rm -f repodata/*
mv comps.xml repodata/

discinfo=$(head -1 isolinux/.discinfo)
createrepo -u "media://$discinfo" -g repodata/comps.xml $build || exit 1

sed -i -e '
s,append initrd=initrd.img$,append initrd=initrd.img ks=cdrom:/ks.cfg,' $build/isolinux/isolinux.cfg

# build the ISO image
mkisofs -o customized_centos6.iso -b isolinux.bin -c boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -R -J -v -T isolinux/ .

mv customized_centos6.iso $OPWD/
#rm -rf $build
cd $OPWD

echo "ISO Preparation Ready"


