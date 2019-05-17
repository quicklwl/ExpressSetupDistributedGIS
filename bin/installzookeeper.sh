#!/bin/bash

#获取本sh文件的绝对路径
readonly SHTDIR=$(readlink -m $(dirname $0))
PROGDIR=`echo $SHTDIR|awk -F/ '{for(i=(NF-2);i++<(NF-1);){for(j=0;j++<i;){printf j==i?$j"\n":$j"/"}}}'`

#加载配置文件
source $PROGDIR/conf/init.conf

#如果非安装用户，退出安装
if [ $USER != $INSTALL_USER ]; then
	echo "请用 $INSTALL_USER 用户安装！"
	exit
fi

rm -rf $SOFT_INSTALL_DIR/zookeeper

#获取需要安装的软件
echo "您正在安装的软件为：zookeeper"
SOFT_FILE_ZIP=`ls $PROGDIR/soft | grep zookeeper | head -n 1`

#将安装文件拷贝到需要安装的目录下
echo "正在拷贝安装包$PROGDIR/soft/$SOFT_FILE_ZIP到安装目录$SOFT_INSTALL_DIR下……"
cp $PROGDIR/soft/$SOFT_FILE_ZIP $SOFT_INSTALL_DIR

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
SOFT_FILE_DIR=`ls $SOFT_INSTALL_DIR | grep zookeeper`

#重命名
echo "将安装文件$SOFT_INSTALL_DIR/$SOFT_FILE_DIR 重命名成$SOFT_INSTALL_DIR/zookeeper……"
mv $SOFT_INSTALL_DIR/$SOFT_FILE_DIR $SOFT_INSTALL_DIR/zookeeper

#配置环境变量
SOFT_HOME=$SOFT_INSTALL_DIR/zookeeper

mkdir -m 755 $SOFT_HOME/data
cp -f $PROGDIR/conf/zookeeper/zoo.cfg $SOFT_HOME/conf

TEMPINSTALLPATH=${SOFT_INSTALL_DIR//\//\\/} 
sed -i "s/{installpath}/$TEMPINSTALLPATH/g" $SOFT_HOME/conf/zoo.cfg
sed -i '/^server*/d' $SOFT_HOME/conf/zoo.cfg

myidNum=1
cat $PROGDIR/conf/host.conf |while  read node
do
	array=( $node )
	if [[ "$myidNum" -lt "4" ]]; then
		echo "server.$myidNum=${array[1]}:2888:3888" >> $SOFT_HOME/conf/zoo.cfg
	fi
    myidNum=`expr $myidNum + 1`
done

#发送hadoop文件到其他节点
for slave in `cat $PROGDIR/conf/zookeeper/slaves`
do
   echo "正在发送文件$SOFT_HOME到$INSTALL_USER@$slave……" 
   scp -r $SOFT_HOME $INSTALL_USER@$slave:$SOFT_INSTALL_DIR
done

sed -i '/^export ZOOKEEPER_HOME*/d' /home/$INSTALL_USER/.bash_profile
echo "export ZOOKEEPER_HOME=$SOFT_HOME" >> /home/$INSTALL_USER/.bash_profile
export ZOOKEEPER_HOME=$SOFT_HOME

myidNum=1
echo 1 > $SOFT_HOME/data/myid
cd $SOFT_HOME/bin/
sh zkServer.sh start

sleep 1
for node in `cat $PROGDIR/conf/zookeeper/slaves`
do
    myidNum=`expr $myidNum + 1`
	ssh -q $INSTALL_USER@$node "echo $myidNum > $SOFT_HOME/data/myid"
	ssh -q $INSTALL_USER@$node "sed -i '/^export ZOOKEEPER_HOME*/d' /home/$INSTALL_USER/.bash_profile"
	ssh -q $INSTALL_USER@$node "echo \"export ZOOKEEPER_HOME=$SOFT_HOME\" >> /home/$INSTALL_USER/.bash_profile"
	ssh -q $INSTALL_USER@$node "source /home/$INSTALL_USER/.bash_profile && cd $SOFT_HOME/bin/ && sh zkServer.sh start"
	sleep 1
done


echo "config zookeeper"
echo "echo \"start zookeeper************************\"" >> $SOFT_INSTALL_DIR/start_all.sh
echo "cd $SOFT_HOME/bin/ && sh zkServer.sh start" >> $SOFT_INSTALL_DIR/start_all.sh

sed -i "2i\sleep 6" $SOFT_INSTALL_DIR/stop_all.sh

for node in `cat $PROGDIR/conf/zookeeper/slaves`
do
	echo "ssh -q $INSTALL_USER@$node \"cd $SOFT_HOME/bin/ && sh zkServer.sh start\"" >> $SOFT_INSTALL_DIR/start_all.sh
	sed -i "2i ssh -q $INSTALL_USER@$node \"cd $SOFT_HOME/bin/ && sh zkServer.sh stop\"" $SOFT_INSTALL_DIR/stop_all.sh
done

echo "sleep 2" >> $SOFT_INSTALL_DIR/start_all.sh
echo "" >> $SOFT_INSTALL_DIR/start_all.sh

sed -i "2i\cd $SOFT_HOME/bin/ && sh zkServer.sh stop" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\echo \"stop zookeeper************************\"" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\ " $SOFT_INSTALL_DIR/stop_all.sh




