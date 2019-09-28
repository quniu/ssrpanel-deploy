#!/usr/bin/env bash

#
# System Required:  CentOS 6,7, Debian, Ubuntu
# Description: iptables transfer
#
# Reference URL:
# https://github.com/quniu
# Author: QuNiu
#

# PATH
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

# Current folder
cur_dir=`pwd`

# Color
red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

#Port type
portType=(
Single\ Port
Multiple\ Port
)



# Make sure only root can run our script
[[ $EUID -ne 0 ]] && echo -e "[${red}Error${plain}] This script must be run as root!" && exit 1

# Disable selinux
disable_selinux(){
    if [ -s /etc/selinux/config ] && grep 'SELINUX=enforcing' /etc/selinux/config; then
        sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
        setenforce 0
    fi
}

# Check system
check_sys(){
    local checkType=$1
    local value=$2

    local release=''
    local systemPackage=''

    if [[ -f /etc/redhat-release ]]; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /etc/issue; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /etc/issue; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /etc/issue; then
        release="centos"
        systemPackage="yum"
    elif grep -Eqi "debian|raspbian" /proc/version; then
        release="debian"
        systemPackage="apt"
    elif grep -Eqi "ubuntu" /proc/version; then
        release="ubuntu"
        systemPackage="apt"
    elif grep -Eqi "centos|red hat|redhat" /proc/version; then
        release="centos"
        systemPackage="yum"
    fi

    if [[ "${checkType}" == "sysRelease" ]]; then
        if [ "${value}" == "${release}" ]; then
            return 0
        else
            return 1
        fi
    elif [[ "${checkType}" == "packageManager" ]]; then
        if [ "${value}" == "${systemPackage}" ]; then
            return 0
        else
            return 1
        fi
    fi
}

# Get version
getversion(){
    if [[ -s /etc/redhat-release ]]; then
        grep -oE  "[0-9.]+" /etc/redhat-release
    else
        grep -oE  "[0-9.]+" /etc/issue
    fi
}

# CentOS version
centosversion(){
    if check_sys sysRelease centos; then
        local code=$1
        local version="$(getversion)"
        local main_ver=${version%%.*}
        if [ "$main_ver" == "$code" ]; then
            return 0
        else
            return 1
        fi
    else
        return 1
    fi
}

# Get public IP address
get_ip(){
    local IP=$( ip addr | egrep -o '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | egrep -v "^192\.168|^172\.1[6-9]\.|^172\.2[0-9]\.|^172\.3[0-2]\.|^10\.|^127\.|^255\.|^0\." | head -n 1 )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipv4.icanhazip.com )
    [ -z ${IP} ] && IP=$( wget -qO- -t1 -T2 ipinfo.io/ip )
    [ ! -z ${IP} ] && echo ${IP} || echo
}

get_char(){
    SAVEDSTTY=`stty -g`
    stty -echo
    stty cbreak
    dd if=/dev/tty bs=1 count=1 2> /dev/null
    stty -raw
    stty echo
    stty $SAVEDSTTY
}

# Modify time zone
modify_time(){
    # set time zone
    if check_sys packageManager yum; then
       ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    elif check_sys packageManager apt; then
       ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    fi
    # status info
    if [ $? -eq 0 ]; then
        echo -e "[${green}Info${plain}] Modify the time zone success!"
    else
        echo -e "[${yellow}Warning${plain}] Modify the time zone failure!"
    fi
}

# Auto Reboot System
auto_reboot_system(){
    cd ${cur_dir}

    # Modify time zone
    modify_time

    #hour
    echo -e "Please enter the hour now(0-23):"
    read -p "(Default hour: 5):" auto_hour
    [ -z "${auto_hour}" ] && auto_hour="5"
    expr ${auto_hour} + 1 &>/dev/null

    #minute
    echo -e "Please enter the minute now(0-59):"
    read -p "(Default hour: 10):" auto_minute
    [ -z "${auto_minute}" ] && auto_minute="10"
    expr ${auto_minute} + 1 &>/dev/null

    echo -e "[${green}Info${plain}] The time has been set, then install crontab!"

    # Install crontabs
    if check_sys packageManager yum; then
        yum install -y vixie-cron cronie
    elif check_sys packageManager apt; then
        apt-get -y update 
        apt-get -y install cron
    fi

    echo "$auto_minute $auto_hour * * * root /sbin/reboot" >> /etc/crontab

    # start crontabs
    if check_sys packageManager yum; then
        chkconfig crond on
        service crond restart
    elif check_sys packageManager apt; then
        /etc/init.d/cron restart
    fi

    if [ $? -eq 0 ]; then
        echo -e "[${green}Info${plain}] crontab start success!"
    else
        echo -e "[${yellow}Warning${plain}] crontab start failed!"
        exit 1
    fi

    echo -e "[${green}Info${plain}] Has been installed successfully!"
    echo -e "-----------------------------------------------------"
    echo -e "The time for automatic restart has been set! "
    echo -e "-----------------------------------------------------"
    echo -e "hour       : ${auto_hour}                   "
    echo -e "minute     : ${auto_minute}                 "
    echo -e "Restart the system at ${auto_hour}:${auto_minute} every day"
    echo -e "-----------------------------------------------------"
}


# Iptables set
iptables_set_centos(){
    echo -e "[${green}Info${plain}] Iptables set start..."
    if centosversion 6; then
        service iptables status > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "[${yellow}Warning${plain}] iptables looks like shutdown or not installed!"
            echo -e "[${green}Info${plain}] start to install iptables now"
            yum install -y iptables > /dev/null 2>&1
            config_iptables
        fi

        chkconfig --level 2345 iptables on
        set_transfer_rule

    elif centosversion 7; then
        systemctl status firewalld > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            systemctl stop firewalld > /dev/null 2>&1
            systemctl disable firewalld > /dev/null 2>&1
            echo -e "[${green}Info${plain}] disable firewalld success!"
        fi

        # 查看是否安装了iptables
        systemctl status iptables  > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            echo -e "[${yellow}Warning${plain}] iptables looks like shutdown or not installed!"
            echo -e "[${green}Info${plain}] start to install iptables now"
            yum install -y iptables iptables-services > /dev/null 2>&1
        fi

        systemctl enable iptables
        set_transfer_rule

    fi
    echo -e "[${green}Info${plain}] Transfer Port Set Completed!"
}


# set transfer rule
set_transfer_rule(){
    echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
    sysctl -p

    # ${ip_this_server}            // 中转服务器ip
    # ${ip_transfer_server}        // 被中转服务器ip

    # ${ip_single_port}            // 中转服务器的端口（单端口）
    # ${ip_single_turned_port}     // 被中转服务器的端口（单端口）

    # ${ip_start_port}             // 中转服务器的开始端口（多端口）
    # ${ip_start_turned_port}      // 被中转服务器的开始端口（多端口）
    # ${ip_end_port}               // 中转服务器的结束端口（多端口）
    # ${ip_end_turned_port}        // 被中转服务器的结束端口（多端口）

    # eth0:公网IP
    # eth1:内网IP

    service iptables stop
    iptables -L -n > /dev/null 2>&1

    if [ "${port_type_select}" == 1 ]; then
        # 单端口
        
        # 防火墙端口开发
        iptables -P OUTPUT ACCEPT
        iptables -A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport ${ip_single_port} -j ACCEPT

        # 端口段
        if [ "${ip_single_port}" == "${ip_single_turned_port}" ]; then
            echo -e "[${green}Info${plain}] Same port!"

            iptables -t nat -I PREROUTING -p tcp --dport ${ip_single_port} -j DNAT --to ${ip_transfer_server}
            iptables -t nat -I POSTROUTING -p tcp --dport ${ip_single_port} -j MASQUERADE
            iptables -t nat -I PREROUTING -p udp --dport ${ip_single_port} -j DNAT --to ${ip_transfer_server}
            iptables -t nat -I POSTROUTING -p udp --dport ${ip_single_port} -j MASQUERADE
        else
            echo -e "[${green}Info${plain}] Not the same port!"

            iptables -t nat -A PREROUTING -p tcp -i eth0 --dport ${ip_single_port} -j DNAT --to-destination ${ip_transfer_server}:${ip_single_turned_port}
            iptables -t nat -A PREROUTING -p udp -i eth0 --dport ${ip_single_port} -j DNAT --to-destination ${ip_transfer_server}:${ip_single_turned_port}
            iptables -t nat -A POSTROUTING -j MASQUERADE
        fi
    else
        # 多端口

        # 防火墙端口开发
        iptables -P OUTPUT ACCEPT
        iptables -A RH-Firewall-1-INPUT -m state --state NEW -m tcp -p tcp --dport ${ip_start_turned_port}:${ip_end_turned_port} -j ACCEPT

        echo -e "[${green}Info${plain}] Multiport!"

        # 端口段
        iptables -t nat -I PREROUTING -p tcp --dport ${ip_start_turned_port}:${ip_end_turned_port} -j DNAT --to ${ip_transfer_server}
        iptables -t nat -I POSTROUTING -p tcp --dport ${ip_start_turned_port}:${ip_end_turned_port} -j MASQUERADE
        iptables -t nat -I PREROUTING -p udp --dport ${ip_start_turned_port}:${ip_end_turned_port} -j DNAT --to ${ip_transfer_server}
        iptables -t nat -I POSTROUTING -p udp --dport ${ip_start_turned_port}:${ip_end_turned_port} -j MASQUERADE
    fi

    service iptables save
    service iptables restart
    service iptables status > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "[${green}Info${plain}] iptables restart success!"
    else
        echo -e "[${yellow}Warning${plain}] iptables restart fail!"
    fi
}


# Config iptables
config_iptables(){
    cat > /etc/sysconfig/iptables<<-EOF
EOF
}


# Set iptables transfer
set_iptables_transfer(){
    while true
    do
    echo -e "Please select the Port Type:"
    for ((i=1;i<=${#portType[@]};i++ )); do
        hint="${portType[$i-1]}"
        echo -e "${green}${i} => ${plain} ${hint}"
    done

    read -p "Which port type you'd select(Default: ${portType[1]}):" port_type_select
    [ -z "$port_type_select" ] && port_type_select=2
    expr ${port_type_select} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[${red}Error${plain}] Input error, please input a number"
        continue
    fi
    if [[ "$port_type_select" -lt 1 || "$port_type_select" -gt ${#portType[@]} ]]; then
        echo -e "[${red}Error${plain}] Input error, please input a number between 1 and ${#portType[@]}"
        continue
    fi
    ip_port_type=${portType[$port_type_select-1]}

    break
    done

    echo -e "Please enter the This Serve IP:"
    read -p "(Default IP: 0.0.0.0):" ip_this_server
    [ -z "${ip_this_server}" ] && ip_this_server="0.0.0.0"
    expr ${ip_this_server} + 1 &>/dev/null

    echo -e "Please enter the Transfer Serve IP:"
    read -p "(Default IP: 127.0.0.1):" ip_transfer_server
    [ -z "${ip_transfer_server}" ] && ip_transfer_server="127.0.0.1"
    expr ${ip_transfer_server} + 1 &>/dev/null


    if [ "${port_type_select}" == 1 ]; then
        #Single 
        #ip start port
        echo -e "Please enter the Single Port:"
        read -p "(Default Port: 10000):" ip_single_port
        [ -z "${ip_single_port}" ] && ip_single_port="10000"
        expr ${ip_single_port} + 1 &>/dev/null

        #ip start turned port
        echo -e "Please enter the Single Turned Port:"
        read -p "(Default Port: ${ip_single_port}):" ip_single_turned_port
        [ -z "${ip_single_turned_port}" ] && ip_single_turned_port=${ip_single_port}
        expr ${ip_single_turned_port} + 1 &>/dev/null

        echo
        echo -e "-----------------------------------------------------"
        echo -e "The IP Port Configuration has been completed! "
        echo -e "-----------------------------------------------------"
        echo -e "Your Port Type        : Single                       "
        echo -e "Your Server IP        : ${ip_this_server}            "
        echo -e "Your Transfer IP      : ${ip_transfer_server}        "
        echo -e "Your Single Port      : ${ip_single_port}            "
        echo -e "Your Turned Port      : ${ip_single_turned_port}     "
        echo -e "-----------------------------------------------------"

    else
        # Multiple
        #ip start port
        echo -e "Please enter the Start Port:"
        read -p "(Default Port: 10000):" ip_start_port
        [ -z "${ip_start_port}" ] && ip_start_port="10000"
        expr ${ip_start_port} + 1 &>/dev/null

        #ip start port
        echo -e "Please enter the Start Turned Port:"
        read -p "(Default Port: ${ip_start_port}):" ip_start_turned_port
        [ -z "${ip_start_turned_port}" ] && ip_start_turned_port=${ip_start_port}
        expr ${ip_start_turned_port} + 1 &>/dev/null


        #ip end port
        echo -e "Please enter the End Port:"
        read -p "(Default Port: 65535):" ip_end_port
        [ -z "${ip_end_port}" ] && ip_end_port="65535"
        expr ${ip_end_port} + 1 &>/dev/null

        #ip end port
        echo -e "Please enter the End Turned Port:"
        read -p "(Default Port: ${ip_end_port}):" ip_end_turned_port
        [ -z "${ip_end_turned_port}" ] && ip_end_turned_port=${ip_end_port}
        expr ${ip_end_turned_port} + 1 &>/dev/null

        echo
        echo -e "-----------------------------------------------------"
        echo -e "The IP Port Configuration has been completed! "
        echo -e "-----------------------------------------------------"
        echo -e "Your Port Type           : Multiple                  "
        echo -e "Your Server IP           : ${ip_this_server}         "
        echo -e "Your Transfer IP         : ${ip_transfer_server}     "
        echo -e "Your Start Port          : ${ip_start_port}          "
        echo -e "Your Start Turned Port   : ${ip_start_turned_port}   "
        echo -e "Your End Port            : ${ip_end_port}            "
        echo -e "Your End Turned Port     : ${ip_end_turned_port}     "
        echo -e "-----------------------------------------------------"
    fi

    echo "Press any key to start or Press Ctrl+C to cancel. Please continue!"
    char=`get_char`
    cd ${cur_dir}

    if check_sys packageManager yum; then
        echo -e "[${green}Info${plain}] OK! packageManager yum"
        iptables_set_centos
    elif check_sys packageManager apt; then
        echo -e "[${green}Info${plain}] OK! packageManager apt"
    fi
}

# Initialization step
commands=(
Set\ Iptables\ Transfer
Auto\ Reboot\ System
Modify\ Time\ Zone
)


# Choose command
choose_command(){

    while true
    do
    echo 
    echo -e "Welcome! Please select command to start:"
    echo -e "-------------------------------------------"
    for ((i=1;i<=${#commands[@]};i++ )); do
        hint="${commands[$i-1]}"
        echo -e "${green}${i} => ${plain} ${hint}"
    done
    echo -e "-------------------------------------------"
    read -p "Which command you'd select(Default: ${commands[0]}):" order_num
    [ -z "$order_num" ] && order_num=1
    expr ${order_num} + 1 &>/dev/null
    if [ $? -ne 0 ]; then
        echo 
        echo -e "[${red}Error${plain}] Please enter a number"
        continue
    fi
    if [[ "$order_num" -lt 1 || "$order_num" -gt ${#commands[@]} ]]; then
        echo 
        echo -e "[${red}Error${plain}] Please enter a number between 1 and ${#commands[@]}"
        continue
    fi
    break
    done

    case $order_num in
        1)
        set_iptables_transfer
        ;;
        2)
        auto_reboot_system
        ;;
        3)
        modify_time
        ;;
        *)
        exit 1
        ;;
    esac
}
# start
cd ${cur_dir}

choose_command
