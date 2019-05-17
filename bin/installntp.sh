#!/bin/bash

#判断用户是否是root
if [ $USER != "root" ]; then
	echo "请用root用户操作！"
	exit
fi
#获取当前sh文件的绝对路径的上一层目录
readonly INITDIR=$(readlink -m $(dirname $0))

#加载配置文件
source $INITDIR/../conf/init.conf


#检查是否安装了expect
allreadyNTP=`rpm -qa ntp`
if [ -z "$allreadyNTP" ]; then

	#获取需要安装的软件
	echo "您正在安装的软件为：autogen"
	SOFT_FILE_ZIP_AUTOGEN=`ls $INITDIR/../soft | grep autogen | head -n 1`
	
	cd $INITDIR/../soft/
	rpm -ivh $SOFT_FILE_ZIP_AUTOGEN
	
	echo "您正在安装的软件为：ntpdate"
	SOFT_FILE_ZIP_NTPDATE=`ls $INITDIR/../soft | grep ntpdate | head -n 1`
	rpm -ivh $SOFT_FILE_ZIP_NTPDATE
	
	echo "您正在安装的软件为：ntp"
	SOFT_FILE_ZIP_NTP=`ls $INITDIR/../soft | grep ntp- | head -n 1`
	rpm -ivh $SOFT_FILE_ZIP_NTP
fi


LOCALNAME=`hostname`
MASTERNAME=`awk 'NR==1{print $2}' $INITDIR/../conf/host.conf`
MASTERIP=`awk 'NR==1{print $1}' $INITDIR/../conf/host.conf`
if [[ "$LOCALNAME" ==  "$MASTERNAME" ]]; then
	cp -f $INITDIR/../conf/ntp/master/ntp.conf /etc/ntp.conf
	
	a1=`echo $MASTERIP|cut -d "." -f1`
	a2=`echo $MASTERIP|cut -d "." -f2`
	a3=`echo $MASTERIP|cut -d "." -f3`
	MASTERPREIP=`echo $a1.$a2.$a3.0`
	sed -i "s/{masterip}/$MASTERPREIP/" /etc/ntp.conf
	service ntpd start
	systemctl enable ntpd.service
else
	cp -f $INITDIR/../conf/ntp/slaves/ntp.conf /etc/ntp.conf
	sed -i "s/{masterip}/$MASTERIP/g" /etc/ntp.conf
	ntpdate -u "$MASTERIP"
	service ntpd start
	systemctl enable ntpd.service
fi




