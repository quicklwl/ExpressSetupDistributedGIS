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
allreadyExpect=`rpm -qa expect`
if [ -z "$allreadyExpect" ]; then

	#获取需要安装的软件
	echo "您正在安装的软件为：tcl"
	SOFT_FILE_ZIP_TCL=`ls $INITDIR/../soft | grep tcl | head -n 1`
	
	cd $INITDIR/../soft/
	rpm -ivh $SOFT_FILE_ZIP_TCL
	
	echo "您正在安装的软件为：expect"
	SOFT_FILE_ZIP_EXPECT=`ls $INITDIR/../soft | grep expect | head -n 1`
	rpm -ivh $SOFT_FILE_ZIP_EXPECT
fi




