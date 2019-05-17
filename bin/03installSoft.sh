#!/bin/bash

#获取本sh文件的绝对路径
readonly INITDIR=$(readlink -m $(dirname $0))
PROGDIR=`echo $INITDIR|awk -F/ '{for(i=(NF-2);i++<(NF-1);){for(j=0;j++<i;){printf j==i?$j"\n":$j"/"}}}'`

#加载配置文件
source $PROGDIR/conf/init.conf

#如果非安装用户，退出安装
if [ $USER != $INSTALL_USER ]; then
	echo "请用 $INSTALL_USER 用户安装！"
	exit
fi


mkdir -p $SOFT_INSTALL_DIR
for node in `awk 'NR > 1{print $1}' $PROGDIR/conf/host.conf`   
do
	ssh -q $USER@$node "mkdir -p $SOFT_INSTALL_DIR"
done


rm -f $SOFT_INSTALL_DIR/start_all.sh
rm -f $SOFT_INSTALL_DIR/stop_all.sh

echo "#!/bin/bash" >> $SOFT_INSTALL_DIR/start_all.sh
echo "#!/bin/bash" >> $SOFT_INSTALL_DIR/stop_all.sh
echo "" >> $SOFT_INSTALL_DIR/stop_all.sh

for node in $INSTALL_SOFT ; do
    sh $PROGDIR/bin/install$node.sh
	sleep 2
done

