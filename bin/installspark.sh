#!/bin/bash

#获取本sh文件的绝对路径
readonly SHTDIR=$(readlink -m $(dirname $0))
PROGDIR=`echo $SHTDIR|awk -F/ '{for(i=(NF-2);i++<(NF-1);){for(j=0;j++<i;){printf j==i?$j"\n":$j"/"}}}'`

#加载配置文件
source $PROGDIR/conf/init.conf
source $PROGDIR/conf/settings.conf

#如果非安装用户，退出安装
if [ $USER != $INSTALL_USER ]; then
	echo "请用 $INSTALL_USER 用户安装！"
	exit
fi

rm -rf $SOFT_INSTALL_DIR/spark

#获取需要安装的软件
echo "您正在安装的软件为：spark"
SOFT_FILE_ZIP=`ls $PROGDIR/soft | grep spark | head -n 1`

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
SOFT_FILE_DIR=`ls $SOFT_INSTALL_DIR | grep spark`

#重命名
echo "将安装文件$SOFT_INSTALL_DIR/$SOFT_FILE_DIR 重命名成$SOFT_INSTALL_DIR/spark"
mv $SOFT_INSTALL_DIR/$SOFT_FILE_DIR $SOFT_INSTALL_DIR/spark

#配置环境变量
SOFT_HOME=$SOFT_INSTALL_DIR/spark

cp -f $PROGDIR/conf/spark/* $SOFT_HOME/conf


for node in `awk 'NR > 1{print $2}' $PROGDIR/conf/host.conf`
do
	echo "$node" >> $SOFT_HOME/conf/slaves
done

JAVAHOME=`awk -F"=" '{if($1=="export JAVA_HOME"){print $2}}' ~/.bash_profile`
TEMPJAVAHOME=${JAVAHOME//\//\\/} 
sed -i "s/{javahome}/$TEMPJAVAHOME/" $SOFT_HOME/conf/spark-env.sh

MASTERIP=`awk 'NR==1{print $1}' $PROGDIR/conf/host.conf`
sed -i "s/{masterip}/$MASTERIP/" $SOFT_HOME/conf/spark-env.sh

HADOOP_DIR=`ls $SOFT_INSTALL_DIR | grep hadoop`
HADOOP_DIRALL="$SOFT_INSTALL_DIR/$HADOOP_DIR"
TEMPHADOOP_DIRALL=${HADOOP_DIRALL//\//\\/} 
sed -i "s/{hadoophome}/$TEMPHADOOP_DIRALL/" $SOFT_HOME/conf/spark-env.sh

#memory setting
TOTALMEM=`cat /proc/meminfo | grep MemTotal`
MEMSIZE=`echo $TOTALMEM|awk '{print $2}'`
SPARKSIZE=$[$MEMSIZE/2/1024/512*512]
if [ "$SPARKSIZE" -lt "1" ]; then
	SPARKSIZE=256
fi

sed -i "s/{SPARKMEMORY}/$SPARKMEMORY/g" $SOFT_HOME/conf/spark-env.sh
sed -i "s/{SPARKCPU}/$SPARKCPU/" $SOFT_HOME/conf/spark-env.sh

#CPU
CPUCOUNT=`cat /proc/cpuinfo | grep 'cpu cores' | wc -l`
SPARKCPU=$[$CPUCOUNT/2]
if [ "$SPARKCPU" -lt "1" ]; then
	SPARKCPU=1
fi
sed -i "s/{cpu}/$SPARKCPU/" $SOFT_HOME/conf/spark-env.sh


for node in `awk '{print $1}' $SOFT_HOME/conf/slaves`
do
	echo "配置 $node 节点************************"
	scp -r $SOFT_HOME $INSTALL_USER@$node:$SOFT_INSTALL_DIR
done

sh $SOFT_HOME/sbin/start-all.sh



echo "echo \"start spark ************************\"" >> $SOFT_INSTALL_DIR/start_all.sh
echo "sh $SOFT_HOME/sbin/start-all.sh" >> $SOFT_INSTALL_DIR/start_all.sh
echo "echo \"http://$MASTERIP:8080\"" >> $SOFT_INSTALL_DIR/start_all.sh
echo "sleep 5" >> $SOFT_INSTALL_DIR/start_all.sh

sed -i "2i\sleep 2" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\sh $SOFT_HOME/sbin/stop-all.sh" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\echo \"stop spark************************\"" $SOFT_INSTALL_DIR/stop_all.sh


