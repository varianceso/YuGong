#! /bin/bash

GRUBCONF="/boot/grub2/grub.cfg"
EXECNAME=${0##*/}
MATCHED=0

#查看当前系统有哪些内核
function show() 
{
    if [ "$(whoami)" == "root" ]
    then
        #echo "root";
        KERNELS=`cat "$GRUBCONF" | grep "^menuentry"`
    else
        KERNELS=`sudo cat "$GRUBCONF" | grep "^menuentry"`
    fi

    #echo "Kernels:"
    #echo "$KERNELS" | while read line
    #do
    #    #echo "$line" |sed "s/{$//g"
    #    #最大限度匹配
    #    substr=${line%%--class*}
    #    echo "${substr}" | sed "s/menuentry //g" | sed "s/'//g"
    #done

    OLD=`echo $IFS`
    IFS=$'\n'
    for line in `echo "$KERNELS"`
    do
         #echo "$line" |sed "s/{$//g"
         #最大限度匹配
         substr=${line%%--class*}
         echo "${substr}" | sed "s/menuentry //g" | sed "s/'//g" | sed "s/ $//g"
    done
    IFS=`echo $OLD`

return 0
}

function version_check()
{
    if [ $# != 1 ]
    then
        echo "too many versions to check: $# $@"
        return 1;
    fi

    #判断参数合法性，匹配模式为 4.17.8
    #或者匹配Fedora (4.17.8) 28 (Server Edition)
    if [[ ! "$@" =~ ^[0-9]+\.[0-9]+\.[0-9]+ ]] && [[ ! "$@" =~ [0-9]+\.[0-9]+\.[0-9]+ ]]
    then
        echo "Invalid Kernel Version: $@"
        return 1
    fi

    ALL_KERNELS=`show`
    #echo "$ALL_KERNELS" | while read line
    #do
    #    #if [[ "$line" =~ "($1)" ]]
    #    if [[ "$ALL_KERNELS" =~ "($1)" ]]
    #    then
    #        MATCHED=1
    #        echo "$line =~ ($1) | $MATCHED"
    #        break
    #    fi
    #done
    if [[ "$ALL_KERNELS" =~ "($@)" ]] || [[ "$ALL_KERNELS" =~ "$@" ]]
    then
        MATCHED=1
    fi

    echo -n "version check $@ "
    #echo $MATCHED
    if (( $MATCHED == 1 ))
    then
        echo "Matched"
        return 0
    else
        echo "Not Matched"
        return 1
    fi
}

#删除当前系统有的内核
function delete()
{
    if [ $# -lt 1 ]
    then
        echo "need at least 1 parameter"
        return 1;
    fi

    var=`echo ${@:$#}`
    kernel_version=""
    version_check "$var"
    ret=$?
    #echo $ret
    if [ $ret -ne 0 ]
    then
        echo "--------------------"
        echo "ALL Kernel Versions:"
        show
        echo "--------------------"
        echo -e "Delete Failed:kernel version "$1" not exists"
        return 1
    fi

    #如果是完整的内核版本名称：Fedora (4.17.5-200.fc28.x86_64) 28 (Server Edition)
    tmp=`echo $var|grep -Eo '\([0-9]+\.[0-9]+\.[0-9]+\-.*\) '`
    tmp=`echo "$tmp"|sed s/\(//g|sed s/\)//g`
    if [ "$tmp" != "" ]
    then
        kernel_version=`echo $tmp`
        #echo "tmp=$tmp"
    fi

    #如果不是完整的内核版本名称：4.17.5
    if [ "$tmp" == "" ]
    then
        echo "no complete kernel info"
        all=`show`
        sum=0
        line=""
        declare -a array
        OLD=`echo "$IFS"`
        IFS=$'\n'
        for line in `echo "$all"`
        do
            #echo "$line"
            ret=`echo "$line" |grep -E "$var"`
            if [ "$ret" != "" ]
            then 
                #echo "$line"
                #echo "May Matched Kernel $line"
                array[$sum]=`echo "$line"`
                ((sum=sum+1))
            fi
        done
        IFS=`echo "$OLD"`
        #echo "$var"
        if ((sum == 1))
        then
            var=`echo $array[0]`
            var=`echo "$var"|grep -Eo '\([0-9]+\.[0-9]+\.[0-9]+\-.*\) '`
            var=`echo "$var"|sed s/\(//g|sed s/\)//g`
            echo "Exactely Matched Kernel version $var"
            kernel_version=`echo $var`
        elif ((sum > 1))
        then
            echo "Too many possibly kernels may match:"
            for i in "${!array[@]}";
            do
                printf "\t%s\n" "${array[$i]}"
            done
            echo "Please Specify the kernel version"
            return 1
        fi
    fi

    #需要被删除的
    #   /boot/vmlinuz*KERNEL-VERSION*
    #   /boot/initramfs*KERNEL-VERSION*
    #   /boot/System-map*KERNEL-VERSION*
    #   /boot/config-KERNEL-VERSION
    #   /lib/modules
    vmlinuz_version="/boot/vmlinuz-$kernel_version"
    initramfs_version="/boot/initramfs-$kernel_version"
    systemmap_version="/boot/System.map-$kernel_version"
    config_version="/boot/config-$kernel_version"
    libmodules_version="/lib/modules/$kernel_version/"

    array[0]="$vmlinuz_version"
    array[1]="$initramfs_version"
    array[2]="$systemmap_version"
    array[3]="$config_version"
    array[4]="$libmodules_version"

    for var in ${array[@]}
    do 
        if [ -e "$var" ]
        then
            sudo rm -rf "$var"
            echo "delete $var"
        else
            echo "no \"$var\" detected!"
        fi
    done

    echo "--------------------"
    sudo grub2-mkconfig -o /boot/grub2/grub.cfg
    echo "--------------------"
    echo "Delete Success: delete kernel version $kernel_version finished"

return 0
}

#为当前系统设置默认的内核
function set_default()
{
    #echo "set default"
    if [ $# -lt 1 ]
    then
        echo "need at least 1 parameter"
        return 1;
    fi

    #将带有空格的多个参数合并为一个参数
    var=`echo ${@:$#}`
    version_check "$var"
    ret=$?
    #echo $ret
    if [ $ret -ne 0 ]
    then
        echo "--------------------"
        echo "ALL Kernel Versions:"
        show
        echo "--------------------"
        echo -e "Set Default Failed:kernel version "$var" not exists"
        return 1
    fi

    #echo $var
    OLD=`echo "$IFS"`
    IFS=$'\n'
    if [[ $var =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
    then
        all=`show`
        for line in `echo "$all"`
        do
            #echo "$line"
            ret=`echo "$line" |grep "$var"`
            if [ "$ret" != "" ]
            then 
                var=`echo $line`
                echo "Exactely Matched Kernel $var"
                break
            fi
        done
    fi
    IFS=`echo "$OLD"`
    #echo "$var"
    kernel_version=`echo $var`

    sudo grub2-set-default "$kernel_version"
    ret=`sudo grub2-editenv list`
    ret=`echo $ret|sed s/^saved_entry=//g|sed s/^[\s]+//g`
    if [ "$ret" == "$kernel_version" ]
    then
        echo "--------------------"
        echo "kernel version = $kernel_version"
        echo "Set Default Success:grub2 set default kernel $ret finished"
        echo "--------------------"
    else
        echo "--------------------"
        echo -e "Set Default Failed:set default kernel $kernel_version failed,current default kernel is $ret"
        echo "--------------------"
        return 1
    fi
    return 0
}

function do_help()
{
    echo "Usage:"
    echo "  $EXECNAME show"
    echo -e "  $EXECNAME delete:\n\t$EXECNAME delete '4.17.8'\n\t$EXECNAME delete 'Fedora (4.17.8) 28 (Server Edition)'"
    echo -e "  $EXECNAME set:\n\t$EXECNAME set '4.17.8'\n\t$EXECNAME set 'Fedora (4.17.8) 28 (Server Edition)'"
}

function main()
{
    if [ "$1" == "show" ] && [ $# -eq 1 ]
    then
        echo "All Kernel Versions:"
        show
    elif [ "$1" == "delete" ] && [ $# -gt 1 ]
    then
        var=`echo $* | sed s/^delete//g | sed s/^[\s]+//g`
        delete "$var"
    elif [ "$1" == "set" ] && [ $# -gt 1 ]
    then
        #首先去除参数行中的"set "
        #只保留真正需要设置的内核版本参数
        var=`echo $* | sed s/^set//g | sed s/^[\s]+//g`
        #echo $var
        set_default "$var"
    else
        do_help
    fi
}

main $1 $2
