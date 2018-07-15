#! /usr/bin/bash

DEFAULT_BPMEM=2048
HUGE_PATH="/mnt/huge"
DEFINE_HUGE_PATH="/sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages"
CURR_HUGE=`cat "$DEFINE_HUGE_PATH"`

#系统环境信息获取
#numa_info=`numactl --hardware |grep "available" |cut -f2 -d:|sort|uniq`
numa_info=`numactl --hardware|sed '1,$s/^/    /g'`
cpu_type=`cat /proc/cpuinfo | grep name |cut -f2 -d:|sort | uniq|sed 's/^[ \t]*//g' `
cpu_socket=`cat /proc/cpuinfo | grep "physical id" |cut -f2 -d:|sort|uniq|wc -l |sed 's/^[ \t]*//g'`
each_socket_phy_core=`cat /proc/cpuinfo | grep "cpu cores"| cut -f2 -d:|sort|uniq |sed 's/^[ \t]*//g'`
all_logic_core=`more /proc/cpuinfo | grep "processor"| uniq|wc -l |sed 's/^[ \t]*//g'`
cpu_other_info=`lscpu|sed 's/^[ \t]*//g'|sed '1,$s/^/    /g'`

echo "NUMA Info:"; echo "$numa_info";

echo "CPU Type: $cpu_type";
echo "CPU Sockets: $cpu_socket";
echo "Physical Core in Socket: $each_socket_phy_core";
echo "Total Logical Cores: $all_logic_core";
#echo "CPU Other Info:"; echo "$cpu_other_info";

#DPDK环境设置
#大页内存，单位为MB
echo "Current Huge Page Mem Number = $CURR_HUGE"
if [ "$CURR_HUGE" != "$DEFAULT_BPMEM" ]
then
    echo "$DEFAULT_BPMEM" > "$DEFINE_HUGE_PATH"
    echo "Reset Huge Page Mem Number = `cat $DEFINE_HUGE_PATH`"
fi

if [[ ! -e ${HUGE_PATH} ]];
then
    mkdir /mnt/huge
    echo "/mnt/huge created!"
fi

mount -t hugetlbfs nodev /mnt/huge
export RTE_SDK=/home/bowenerchen/Kernel-FC28-4.17.5/dpdk-stable-17.11.3
export DESTDIR=/home/bowenerchen/Kernel-FC28-4.17.5/dpdk-stable-17.11.3
if [ "$RTE_TARGET" != "x86_64-native-linuxapp-gcc" ]
then
    echo "Please setup export RTE_TARGET=\"x86_64-native-linuxapp-gcc\""
    exit -1
fi

#sudo yum install numactl-devel.x86_64 kernel-devel-4.17.5-200.fc28.x86_64 elfutils-libelf-devel;

