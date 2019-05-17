#!/bin/bash

if [ $USER != "root" ]; then
	echo "请用root用户操作！"
	exit
fi

#获取当前sh文件的绝对路径
readonly INITDIR=$(readlink -m $(dirname $0))/../

#加载配置文件
source $INITDIR/conf/init.conf

#关闭防火墙
echo "开始关闭防火墙 >>>>>>>>>>>>>>>>>>>>>>"
systemctl stop firewalld.service
systemctl disable firewalld.service
systemctl status firewalld
echo "关闭防火墙 <<<<<<<<<<<<<<<<<<<<"


ulimit -n 655360


echo "开始关闭selinux >>>>>>>>>>>>>>>>>>>>>>"
setenforce 0
sed -i 's|SELINUX=enforcing|SELINUX=disabled|' /etc/selinux/config
B=`getenforce`
if [ $B == "Permissive" -o $B == "disabled" ]; then
	echo "selinux已经关闭！<<<<<<<<<<<<<<<<<<<<"
else
	echo "selinux关闭失败！退出shell！"
	exit
fi


echo "配置域名hosts >>>>>>>>>>>>>>>>>>>>>>"
cat $INITDIR/conf/host.conf |while  read node
do
     array=( $node )
	 sed -i "/${array[1]}$/d" /etc/hosts
	 sed -i "/^${array[0]}/d" /etc/hosts
done

cat $INITDIR/conf/host.conf |while  read node
do
     array=( $node )
	 echo "${array[0]} ${array[1]}" >> /etc/hosts
done
echo "配置域名成功 <<<<<<<<<<<<<<<<<<<<"

echo "开始创建用户 >>>>>>>>>>>>>>>>>>>>>>"
groupadd $INSTALL_GROUP
useradd -g $INSTALL_GROUP $INSTALL_USER
$INITDIR/expect/password.expect $INSTALL_USER $INSTALL_PASSWORD >/dev/null 2>&1
echo "配置 $INSTALL_USER 用户信息成功 <<<<<<<<<<<<<<<<<<<<"

