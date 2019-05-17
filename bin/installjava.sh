#!/bin/bash
if [ $USER != "root" ]; then
	echo "请用root用户操作！"
	exit
fi

#获取当前sh文件的绝对路径
readonly INITDIR=$(readlink -m $(dirname $0))/../

#加载配置文件
source $INITDIR/conf/init.conf

SOFT_INSTALL_DIR=/home/$INSTALL_USER

#获取需要安装的软件
echo "您正在安装的软件为：java"
SOFT_FILE_ZIP=`ls $INITDIR/soft | grep jdk | head -n 1`

#将安装文件拷贝到需要安装的目录下
echo "正在拷贝安装包$INITDIR/soft/$SOFT_FILE_ZIP到安装目录$SOFT_INSTALL_DIR下……"
cp $INITDIR/soft/$SOFT_FILE_ZIP $SOFT_INSTALL_DIR

#进入安装目录
echo "进入安装目录$SOFT_INSTALL_DIR下……"
cd $SOFT_INSTALL_DIR

#解压
echo "正在解压$SOFT_INSTALL_DIR/$SOFT_FILE_ZIP……"
tar -zxvf $SOFT_INSTALL_DIR/$SOFT_FILE_ZIP >/dev/null 2>&1

#删除压缩文件
echo "删除安装包$SOFT_INSTALL_DIR/$SOFT_FILE_ZIP……"
rm -rf $SOFT_INSTALL_DIR/$SOFT_FILE_ZIP

#查找安装文件的名字
SOFT_FILE_DIR=`ls $SOFT_INSTALL_DIR | grep jdk`

if [ -z "`grep "CLASSPATH" /home/$INSTALL_USER/.bash_profile`" ]; then
	echo "export JAVA_HOME=$SOFT_INSTALL_DIR/$SOFT_FILE_DIR" >> /home/$INSTALL_USER/.bash_profile
	echo 'export PATH=$JAVA_HOME/bin:$PATH' >> /home/$INSTALL_USER/.bash_profile
	echo 'export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar' >> /home/$INSTALL_USER/.bash_profile
else
	echo "需要修改"
fi

