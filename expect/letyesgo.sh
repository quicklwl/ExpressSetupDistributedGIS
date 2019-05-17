#!/bin/bash
#获取本sh文件的绝对路径
readonly PROGDIR=$(readlink -m $(dirname $0))
#加载配置文件
source $PROGDIR/init.conf

for node in `awk '{print $2}' $PROGDIR/host.conf`
do
	echo "******************************************************"
	~/.ssh/letyesgo.expect $node $INSTALL_USER >/dev/null 2>&1
	echo `hostname` "与 $node 通信完毕……"
done

rm -rf ~/.ssh/letyesgo.sh
rm -rf ~/.ssh/letyesgo.expect
rm -rf ~/.ssh/init.conf
rm -rf ~/.ssh/host.conf