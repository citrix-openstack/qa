#!/usr/bin/env bash

set -o xtrace

export GUEST_PASSWORD=xenroot
export FILESYSTEM_SIZE=$((5 * 1024 * 1024))
OUTPUT=output.xva

TEMPDIRECTORY=temp
BAREDIRECTORY=$TEMPDIRECTORY/bare
TARGETDIRECTORY=$TEMPDIRECTORY/target
TEMPTARGETDIRECTORY=$TEMPDIRECTORY/temp-target
DEVSTACKDIRECTORY=$TEMPDIRECTORY/devstack
MOUNTPOINT=$TEMPDIRECTORY/mnt
STAGINGFS=$TEMPDIRECTORY/stagingsfs
INITIALPWD=`pwd`
SCRIPTDIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

mkdir -p $TEMPDIRECTORY

echo 'Acquire::http::Proxy "http://apt.eng.hq.xensource.com:3142";' > /etc/apt/apt.conf.d/02proxy
DEBIAN_FRONTEND=noninteractive apt-get install git curl -y

if [ ! -d $BAREDIRECTORY ];
then
   # in theory we could prefetch the dependencies - in practice this didn't
   # work as well as letting devstack do it
   #DEVSTACKDEPENDENCIES=$(echo $(cat $DEVSTACKDIRECTORY/files/apts/* | cut -d\# -f1 | grep -v -e qpid -e nodejs-legacy -e python-wsgiref -e python-argparse -e libxslt-devtgt) | sed -e "s/ /,/g")

   # Option 1: Use debootstrap
   #debootstrap --variant=minbase --arch amd64 precise $BAREDIRECTORY

   # Option 2: Use Ubuntu-core
   if [ ! -f $TEMPDIRECTORY/ubuntu-core-12.04.2-core-amd64.tar.gz ];
   then
       curl -o $TEMPDIRECTORY/ubuntu-core-12.04.2-core-amd64.tar.gz http://cdimage.ubuntu.com/ubuntu-core/releases/12.04/release/ubuntu-core-12.04.2-core-amd64.tar.gz
   fi
   mkdir -p $BAREDIRECTORY
   tar zxf $TEMPDIRECTORY/ubuntu-core-12.04.2-core-amd64.tar.gz -C $BAREDIRECTORY
fi

#rm -rf $TARGETDIRECTORY
if [ ! -d $TARGETDIRECTORY ];
then
   cp -r $BAREDIRECTORY $TARGETDIRECTORY
   
   mount -t proc proc $TARGETDIRECTORY/proc/
   mount -t sysfs sys $TARGETDIRECTORY/sys/
   mount -o bind /dev $TARGETDIRECTORY/dev/
   
   cp /etc/resolv.conf $TARGETDIRECTORY/etc/resolv.conf
   cp /etc/mtab $TARGETDIRECTORY/etc/mtab
   #echo 'Acquire::http::Proxy "http://apt.eng.hq.xensource.com:3142";' > $TARGETDIRECTORY/etc/apt/apt.conf.d/02proxy
   cp /etc/apt/sources.list $TARGETDIRECTORY/etc/apt/sources.list
   chmod 1777 $TARGETDIRECTORY/tmp
   echo "127.0.0.1 " `hostname` " #temporary" >> $TARGETDIRECTORY/etc/hosts
   if [ ! -f xe-guest-utilities_6.1.0-1033_amd64.deb ];
   then
       curl -o $TEMPDIRECTORY/xe-guest-utilities_6.1.0-1033_amd64.deb -L https://github.com/downloads/citrix-openstack/warehouse/xe-guest-utilities_6.1.0-1033_amd64.deb
   fi
   cp $TEMPDIRECTORY/xe-guest-utilities_6.1.0-1033_amd64.deb $TARGETDIRECTORY/tmp/
   
   if [ ! -d $DEVSTACKDIRECTORY ];
   then
      git clone https://github.com/openstack-dev/devstack.git $DEVSTACKDIRECTORY
   fi
   
   cd $DEVSTACKDIRECTORY/tools/xen/
   cp build_xva.sh build_xva.sh.bak
   sed -i".bak" '/^STAGING_DIR/d' build_xva.sh
   sed -i".bak" '/^add_on_exit/d' build_xva.sh
   export COPYENV=0
   export STAGING_DIR=$INITIALPWD/$TARGETDIRECTORY
   chmod 755 ./build_xva.sh
   ./build_xva.sh
   mv build_xva.sh.bak build_xva.sh
   cd $INITIALPWD 
   
   cp -f $SCRIPTDIRECTORY/build-inside-chroot.sh $TARGETDIRECTORY/tmp/
   chroot $TARGETDIRECTORY/ /tmp/build-inside-chroot.sh
   rm -f $TARGETDIRECTORY/tmp/build-inside-chroot.sh
   
   rm -f $TARGETDIRECTORY/etc/resolv.conf
   rm -f $TARGETDIRECTORY/etc/mtab
   #rm -f $TARGETDIRECTORY/etc/apt/apt.conf.d/02proxy
   sed -i '/#temporary/d' $TARGETDIRECTORY/etc/hosts
   
   umount $TARGETDIRECTORY/proc/
   umount -l $TARGETDIRECTORY/proc/
   umount $TARGETDIRECTORY/sys/
   umount -l $TARGETDIRECTORY/sys/
   umount $TARGETDIRECTORY/dev/
   umount -l $TARGETDIRECTORY/dev/
   rm -rf $TARGETDIRECTORY/dev/*
fi

rm -f $OUTPUT
if [ ! -f $OUTPUT ];
then
   dd if=/dev/zero of=$STAGINGFS bs=1k count=0 seek=$FILESYSTEM_SIZE
   /sbin/mkfs.ext3 -F $STAGINGFS

   mkdir -p $MOUNTPOINT
   mount -o loop $STAGINGFS $MOUNTPOINT
   cp -r $TARGETDIRECTORY $MOUNTPOINT
   umount $MOUNTPOINT
   rmdir $MOUNTPOINT

   ./mkxva.py --output_path $OUTPUT --ova_xml_path ova.xml --disk_path $STAGINGFS --disk_reference "Ref:84"

   rm -f $STAGINGFS
fi
exit 0
