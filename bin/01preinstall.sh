#!/bin/bash

if [ $USER != "root" ]; then
	echo "请用root用户操作！"
	exit
fi

#获取当前sh文件的绝对路径的上一层目录
readonly INITDIR=$(readlink -m $(dirname $0))
PROGDIR=`echo $INITDIR|awk -F/ '{for(i=(NF-2);i++<(NF-1);){for(j=0;j++<i;){printf j==i?$j"\n":$j"/"}}}'`

#加载配置文件
source $PROGDIR/conf/init.conf

echo "检查安装 expect"
sh $INITDIR/installexpect.sh

echo "检查安装 ntp"
sh $INITDIR/installntp.sh

echo "修改系统配置，关闭防火墙，创建用户"
sh $INITDIR/systemsettings.sh

echo "安装java"
sh $INITDIR/installjava.sh

echo "其他节点配置"
for node in `awk 'NR > 1{print $1","$3}' $PROGDIR/conf/host.conf`   
do
	array=(${node//,/ })  
	echo "开始配置  $node **************************************************"	
	echo "Copying Script"
	$PROGDIR/expect/otherInit.expect "mkdir -p $PROGDIR" ${array[0]} $USER ${array[1]}
	$PROGDIR/expect/scp.expect $PROGDIR/bin ${array[0]} $USER ${array[1]} $PROGDIR
	$PROGDIR/expect/scp.expect $PROGDIR/conf ${array[0]} $USER ${array[1]} $PROGDIR
	$PROGDIR/expect/scp.expect $PROGDIR/expect ${array[0]} $USER ${array[1]} $PROGDIR
	
	$PROGDIR/expect/otherInit.expect "mkdir -p $PROGDIR/soft" ${array[0]} $USER ${array[1]}
	echo "Java installation package"
	$PROGDIR/expect/scp.expect $PROGDIR/soft/jdk* ${array[0]} $USER ${array[1]} $PROGDIR/soft
	echo "expect installation packages"
	$PROGDIR/expect/scp.expect $PROGDIR/soft/tcl* ${array[0]} $USER ${array[1]} $PROGDIR/soft
	$PROGDIR/expect/scp.expect $PROGDIR/soft/expect* ${array[0]} $USER ${array[1]} $PROGDIR/soft
	echo "ntp installation packages"
	$PROGDIR/expect/scp.expect $PROGDIR/soft/autogen* ${array[0]} $USER ${array[1]} $PROGDIR/soft
	$PROGDIR/expect/scp.expect $PROGDIR/soft/ntpdate* ${array[0]} $USER ${array[1]} $PROGDIR/soft
	$PROGDIR/expect/scp.expect $PROGDIR/soft/ntp-* ${array[0]} $USER ${array[1]} $PROGDIR/soft
	$PROGDIR/expect/otherInit.expect $PROGDIR/bin/installexpect.sh ${array[0]} $USER ${array[1]}
	$PROGDIR/expect/otherInit.expect $PROGDIR/bin/installntp.sh ${array[0]} $USER ${array[1]}
	$PROGDIR/expect/otherInit.expect $PROGDIR/bin/systemsettings.sh ${array[0]} $USER ${array[1]}
	$PROGDIR/expect/otherInit.expect $PROGDIR/bin/installjava.sh ${array[0]} $USER ${array[1]}
	$PROGDIR/expect/otherInit.expect "rm -rf $PROGDIR" ${array[0]} $USER ${array[1]}
	echo "配置完毕  $node **************************************************"
done


echo "计算内存**************************************************"
#memory setting
TOTALMEM=`cat /proc/meminfo | grep MemTotal`
MEMSIZE=`echo $TOTALMEM|awk '{print $2}'`
ONETENTH=$[$MEMSIZE/1024]
HADOOPRATIO=2
HBASERATIO=3
SPARKRATIO=3
if [ "$ONETENTH" -gt "65536" ]; then
	HADOOPRATIO=1
	HBASERATIO=3
	SPARKRATIO=5
elif [ "$ONETENTH" -gt "4096" ]; then
	HADOOPRATIO=2
	HBASERATIO=3
	SPARKRATIO=4
fi


HADOOPHEAPSIZE=$[$ONETENTH*$HADOOPRATIO/10]
HBASEHEAPSIZE=$[$ONETENTH*$HBASERATIO/10]
SPARKMEMORY=$[$ONETENTH*$SPARKRATIO/10]
#CPU
CPUCOUNT=`cat /proc/cpuinfo | grep 'cpu cores' | wc -l`
SPARKCPU=$[$CPUCOUNT]
if [ "$SPARKCPU" -lt "1" ]; then
	SPARKCPU=1
fi

echo "各个软件的内存分配，用户可以在../conf/settings.conf文件中修改"
rm -f $PROGDIR/conf/settings.conf
echo "HADOOPHEAPSIZE=$HADOOPHEAPSIZE"
echo "HADOOPHEAPSIZE=$HADOOPHEAPSIZE" >> $PROGDIR/conf/settings.conf
echo "HBASEHEAPSIZE=$HBASEHEAPSIZE"
echo "HBASEHEAPSIZE=$HBASEHEAPSIZE" >> $PROGDIR/conf/settings.conf
echo "SPARKMEMORY=$SPARKMEMORY""M"
echo "SPARKMEMORY=$SPARKMEMORY""M" >> $PROGDIR/conf/settings.conf
echo "SPARKCPU=$SPARKCPU"
echo "SPARKCPU=$SPARKCPU" >> $PROGDIR/conf/settings.conf
echo "计算内存完毕**************************************************"


echo "初始化 hadoop"
sed -i '1,$d'  $PROGDIR/conf/hadoop/slaves
sed -i 1d  $PROGDIR/conf/hadoop/masters

MASTERNAME=`awk 'NR==1{print $2}' $PROGDIR/conf/host.conf`
echo "$MASTERNAME" >> $PROGDIR/conf/hadoop/masters

for node in `awk 'NR > 1{print $2}' $PROGDIR/conf/host.conf`
do
	echo "$node" >> $PROGDIR/conf/hadoop/slaves	
done


echo "初始化 zookeeper"
sed -i '1,$d'  $PROGDIR/conf/zookeeper/slaves

for node in `awk 'NR > 1{print $2}' $PROGDIR/conf/host.conf`
do
	echo "$node" >> $PROGDIR/conf/zookeeper/slaves
done


echo "初始化 hbase"
sed -i '1,$d'  $PROGDIR/conf/hbase/regionservers
for node in `awk 'NR > 1{print $1}' $PROGDIR/conf/host.conf`   
do
	echo "$node" >> $PROGDIR/conf/hbase/regionservers
done

sed -i '1,$d' $PROGDIR/conf/hbase/init.conf
echo "ZOOKEEPER=" >> $PROGDIR/conf/hbase/init.conf

for node in `awk 'NR <4{print $1}' $PROGDIR/conf/host.conf`
do
	sed -i "s/$/,$node:2181/" $PROGDIR/conf/hbase/init.conf
done
sed -i "s/,//" $PROGDIR/conf/hbase/init.conf

MASTERIP=`awk 'NR==1{print $1}' $PROGDIR/conf/host.conf`
echo "HDFS=$MASTERIP:9000" >> $PROGDIR/conf/hbase/init.conf

echo "初始化完毕！！！"

