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

rm -rf $SOFT_INSTALL_DIR/hadoop

#获取需要安装的软件
echo "您正在安装的软件为：hadoop"
SOFT_FILE_ZIP=`ls $PROGDIR/soft | grep hadoop | head -n 1`


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
SOFT_FILE_DIR=`ls $SOFT_INSTALL_DIR | grep hadoop`

#重命名
echo "将安装文件$SOFT_INSTALL_DIR/$SOFT_FILE_DIR 重命名成$SOFT_INSTALL_DIR/hadoop……"
mv $SOFT_INSTALL_DIR/$SOFT_FILE_DIR $SOFT_INSTALL_DIR/hadoop

#配置环境变量
SOFT_HOME=$SOFT_INSTALL_DIR/hadoop

#修改配置文件,如果是hadoop，特殊点
cd $SOFT_HOME
NAME_DIR=namedir
DATA_DIR=datadir
TMP=tmp
JN_DIR=jndir
HADOOP_MRSYS=hadoopmrsys
HADOOP_MRLOCAL=hadoopmrlocal
NODEMANAGER_LOCAL=nodemanagerlocal
NODEMANAGER_LOG=nodemanagerlogs
mkdir -m 755 $SOFT_HOME/$NAME_DIR
mkdir -m 755 $SOFT_HOME/$DATA_DIR
mkdir -m 755 $SOFT_HOME/$TMP
mkdir -m 755 $SOFT_HOME/$JN_DIR
mkdir -m 755 $SOFT_HOME/$HADOOP_MRSYS
mkdir -m 755 $SOFT_HOME/$HADOOP_MRLOCAL
mkdir -m 755 $SOFT_HOME/$NODEMANAGER_LOCAL
mkdir -m 755 $SOFT_HOME/$NODEMANAGER_LOG
cp -f $PROGDIR/conf/hadoop/* $SOFT_HOME/etc/hadoop

# core-site.xml
for master in `cat $PROGDIR/conf/hadoop/masters` 
do
	sed -i "s/{master}/$master/" $SOFT_HOME/etc/hadoop/core-site.xml
done
TEMPSOFT_HOME=${SOFT_HOME//\//\\/} 
sed -i "s/{hadoopPath}/$TEMPSOFT_HOME/" $SOFT_HOME/etc/hadoop/core-site.xml

#hadoop-env.sh
JAVAHOME=`awk -F"=" '{if($1=="export JAVA_HOME"){print $2}}' ~/.bash_profile`
TEMPJAVAHOME=${JAVAHOME//\//\\/} 
sed -i "s/{javahome}/$TEMPJAVAHOME/" $SOFT_HOME/etc/hadoop/hadoop-env.sh
sed -i "s/{HADOOPHEAPSIZE}/$HADOOPHEAPSIZE/" $SOFT_HOME/etc/hadoop/hadoop-env.sh

#hdfs-site.xml
sed -i "s/{master}/$master/g" $SOFT_HOME/etc/hadoop/hdfs-site.xml
sed -i "s/{hadoopPath}/$TEMPSOFT_HOME/g" $SOFT_HOME/etc/hadoop/hdfs-site.xml

#mapred-site.xml
sed -i "s/{master}/$master/g" $SOFT_HOME/etc/hadoop/mapred-site.xml

#yarn-site.xml
sed -i "s/{master}/$master/g" $SOFT_HOME/etc/hadoop/yarn-site.xml

#发送hadoop文件到其他节点
for slave in `cat $PROGDIR/conf/hadoop/slaves`
do
   echo "正在发送文件$SOFT_HOME到$INSTALL_USER@$slave……" 
   ssh -q $INSTALL_USER@$slave "rm -rf $SOFT_INSTALL_DIR/hadoop"
   scp -r $SOFT_HOME $INSTALL_USER@$slave:$SOFT_INSTALL_DIR
done

#格式化集群
sh $SOFT_HOME/bin/hdfs namenode -format
sh $SOFT_HOME/sbin/start-all.sh


echo "echo \"start hadoop************************\"" >> $SOFT_INSTALL_DIR/start_all.sh
echo "sh $SOFT_HOME/sbin/start-all.sh" >> $SOFT_INSTALL_DIR/start_all.sh
MASTERNAME=`awk 'NR==1{print $1}' $PROGDIR/conf/hadoop/masters`
echo "echo \"http://$MASTERNAME:50070\"" >> $SOFT_INSTALL_DIR/start_all.sh
echo "sleep 2" >> $SOFT_INSTALL_DIR/start_all.sh
echo "" >> $SOFT_INSTALL_DIR/start_all.sh

sed -i "2i\sleep 2" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\sh $SOFT_HOME/sbin/stop-all.sh" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\echo \"stop hadoop************************\"" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\ " $SOFT_INSTALL_DIR/stop_all.sh