#! /bin/bash

GRUBCONF="/boot/grub2/grub.cfg"

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

    echo "Kernels:"
    echo "$KERNELS" | while read line
    do
        #echo "$line" |sed "s/{$//g"
        #最大限度匹配
        substr=${line%%--class*}
        echo "${substr}" | sed "s/menuentry //g" | sed "s/'//g"
    done

return 0
}

#删除当前系统有的内核
function delete()
{
    echo "delete"
    return 0
}

#为当前系统设置默认的内核
function set_default()
{
    echo "set default"
    return 0
}

function do_help()
{
    echo "Usage:"
    echo "  kernel_bash.sh show"
    echo "  kernel_bash.sh delete 4.17.8"
    echo "  kernel_bash.sh set \'Fedora (4.17.8) 28 (Server Edition)\'"
}

function main()
{
    if [ "$1" == "show" ]
    then
        show
    elif [ "$1" == "delete" ] && [ $# -eq 2 ]
    then
        delete "$2"
    elif [ "$1" == "set" ] && [ $# -eq 2 ]
    then
        set_default "$2"
    else
        do_help
    fi
}

main $1 $2
