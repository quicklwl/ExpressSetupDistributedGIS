#!/bin/bash

#获取本sh文件的绝对路径
readonly SHTDIR=$(readlink -m $(dirname $0))
PROGDIR=`echo $SHTDIR|awk -F/ '{for(i=(NF-2);i++<(NF-1);){for(j=0;j++<i;){printf j==i?$j"\n":$j"/"}}}'`

#加载配置文件
source $PROGDIR/conf/init.conf
source $PROGDIR/conf/hbase/init.conf
source $PROGDIR/conf/settings.conf


#如果非安装用户，退出安装
if [ $USER != $INSTALL_USER ]; then
echo "请用 $INSTALL_USER 用户安装！"
exit
fi

rm -rf $SOFT_INSTALL_DIR/hbase

#获取需要安装的软件
echo "您正在安装的软件为：hbase"
SOFT_FILE_ZIP=`ls $PROGDIR/soft | grep hbase | head -n 1`

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
SOFT_FILE_DIR=`ls $SOFT_INSTALL_DIR | grep hbase`

#重命名
echo "将安装文件$SOFT_INSTALL_DIR/$SOFT_FILE_DIR 重命名成$SOFT_INSTALL_DIR/hbase……"
mv $SOFT_INSTALL_DIR/$SOFT_FILE_DIR $SOFT_INSTALL_DIR/hbase

#配置环境变量
SOFT_HOME=$SOFT_INSTALL_DIR/hbase

mkdir -m 755 $SOFT_HOME/data
cp -f $PROGDIR/conf/hbase/* $SOFT_HOME/conf
cp -f $PROGDIR/lib/hbase/* $SOFT_HOME/lib

#hbase-env.sh
TEMPINSTALLDIR=${SOFT_INSTALL_DIR//\//\\/} 
sed -i "s/{installpath}/$TEMPINSTALLDIR/g" $SOFT_HOME/conf/hbase-env.sh
JAVAHOME=`awk -F"=" '{if($1=="export JAVA_HOME"){print $2}}' ~/.bash_profile`
TEMPJAVAHOME=${JAVAHOME//\//\\/} 
sed -i "s/{javahome}/$TEMPJAVAHOME/" $SOFT_HOME/conf/hbase-env.sh
sed -i "s/{HBASEHEAPSIZE}/$HBASEHEAPSIZE/" $SOFT_HOME/conf/hbase-env.sh


#hbase-site.xml
sed -i "s/{hdfs}/$HDFS/" $SOFT_HOME/conf/hbase-site.xml
sed -i "s/{zookeeper}/$ZOOKEEPER/" $SOFT_HOME/conf/hbase-site.xml
localhost=`/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:"`
array=( $localhost )
sed -i "s/{masterip}/${array[0]}/" $SOFT_HOME/conf/hbase-site.xml


#发送hadoop文件到其他节点
for slave in `cat $PROGDIR/conf/hbase/regionservers`
do
   echo "正在发送文件$SOFT_HOME到$INSTALL_USER@$slave……" 
   scp -r $SOFT_HOME $INSTALL_USER@$slave:$SOFT_INSTALL_DIR
done

sh $SOFT_HOME/bin/start-hbase.sh 


echo "echo \"start hbase************************\"" >> $SOFT_INSTALL_DIR/start_all.sh
echo "sh $SOFT_HOME/bin/start-hbase.sh" >> $SOFT_INSTALL_DIR/start_all.sh
MASTERNAME=`awk 'NR==1{print $2}' $PROGDIR/conf/host.conf`
echo "echo \"http://$MASTERNAME:60000\"" >> $SOFT_INSTALL_DIR/start_all.sh
echo "sleep 5" >> $SOFT_INSTALL_DIR/start_all.sh
echo " " >> $SOFT_INSTALL_DIR/start_all.sh

sed -i "2i\sleep 2" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\sh $SOFT_HOME/bin/stop-hbase.sh" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\echo \"stop hbase************************\"" $SOFT_INSTALL_DIR/stop_all.sh
sed -i "2i\ " $SOFT_INSTALL_DIR/stop_all.sh

