#!/bin/bash

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
plain='\033[0m'

version="v1.0.0"

# check root
[[ $EUID -ne 0 ]] && echo -e "${red}错误: ${plain} 必须使用root用户运行此脚本！\n" && exit 1

# check os
if [[ -f /etc/redhat-release ]]; then
    release="centos"
elif cat /etc/issue | grep -Eqi "debian"; then
    release="debian"
elif cat /etc/issue | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /etc/issue | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
elif cat /proc/version | grep -Eqi "debian"; then
    release="debian"
elif cat /proc/version | grep -Eqi "ubuntu"; then
    release="ubuntu"
elif cat /proc/version | grep -Eqi "centos|red hat|redhat"; then
    release="centos"
else
    echo -e "${red}未检测到系统版本，请联系脚本作者！${plain}\n" && exit 1
fi

os_version=""

# os version
if [[ -f /etc/os-release ]]; then
    os_version=$(awk -F'[= ."]' '/VERSION_ID/{print $3}' /etc/os-release)
fi
if [[ -z "$os_version" && -f /etc/lsb-release ]]; then
    os_version=$(awk -F'[= ."]+' '/DISTRIB_RELEASE/{print $2}' /etc/lsb-release)
fi

if [[ x"${release}" == x"centos" ]]; then
    if [[ ${os_version} -le 6 ]]; then
        echo -e "${red}请使用 CentOS 7 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"ubuntu" ]]; then
    if [[ ${os_version} -lt 16 ]]; then
        echo -e "${red}请使用 Ubuntu 16 或更高版本的系统！${plain}\n" && exit 1
    fi
elif [[ x"${release}" == x"debian" ]]; then
    if [[ ${os_version} -lt 8 ]]; then
        echo -e "${red}请使用 Debian 8 或更高版本的系统！${plain}\n" && exit 1
    fi
fi

pre_install(){
    echo -e "系统为:${release} ${os_version}"
    echo "同步计时器"
    if [[ $release = "centos" ]]; then
        yum install -y ntp
        systemctl enable ntpd
        ntpdate -q 0.rhel.pool.ntp.org
        systemctl restart ntpd
    else
        apt-get install -y ntp
        service ntp restart
    fi

    echo "关闭防火墙"
    systemctl start supervisord
    systemctl disable firewalld
    systemctl stop firewalld
}

install_docker(){
    echo "安装docker/docker-compose"
    docker -v
    if [[ $? != 0 ]]; then
    curl -fsSL https://get.docker.com | bash
    fi
    docker-compose -v
    if [[ $? != 0 ]]; then
    curl -L "https://github.com/docker/compose/releases/download/1.25.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod a+x /usr/local/bin/docker-compose
    fi
    systemctl start docker
    service docker start
    service docker restart
    systemctl enable docker.service
}

install(){
    pre_install && install_docker && start
}

install_bbr() {
    bash <(curl -L -s https://github.com/sprov065/blog/raw/master/bbr.sh)
    if [[ $? == 0 ]]; then
        echo ""
        echo -e "${green}安装 bbr 成功，请重启服务器${plain}"
    else
        echo ""
        echo -e "${red}下载 bbr 安装脚本失败，请检查本机能否连接 Github${plain}"
    fi
}

choose_mode(){
    clear
    echo -e "
  ${green}请选择 soga 对接方式${plain}
  ${green}0.${plain} 退出脚本
————————————————

  ${green}1.${plain} tcp
  ${green}2.${plain} ws
  ${green}3.${plain} ws+tls

————————————————
 "
    echo && read -p "请输入选择 [0-3]（默认 tcp）: " num
    if [ -z "${num}" ];then
        num=1
    fi
    case "${num}" in
        0) exit 0
        ;;
        1) soga_tcp
        ;;
        2) soga_ws
        ;;
        3) soga_wss
        ;;
        *) echo -e "${red}请输入正确的数字 [0-3]（默认 tcp）${plain}"
        ;;
    esac
}

soga_tcp(){
    mode=tcp
    get_basis
    show_message
    echo "写入docker-compose配置"
cat > docker-compose.yml << EOF
version: "3"

services:
  soga:
    image: sprov065/soga:latest
    environment:
      type: ${type}
      server_type: ${server_type}
      api: ${api}
      webapi_url: ${webapi_url}
      node_id: ${node_id}
      webapi_mukey: ${webapi_mukey}
      soga_key: ${soga_key}
      user_conn_limit: ${user_conn_limit}
      user_speed_limit: ${user_speed_limit}
      check_interval: ${check_interval}
      forbidden_bit_torrent: ${forbidden_bit_torrent}
    restart: always
    ports:
      - "${ports}:${ports}"
    logging:
      options:
        max-size: "10m"
        max-file: "3"
EOF
    install

}

get_type(){
    echo -e "
  ${green}请选择面板 type 类型${plain}
  ${green}0.${plain} 退出脚本
————————————————

  ${green}1.${plain} v2board
  ${green}2.${plain} sspanel-uim

————————————————
 "
    echo && read -p "请输入选择 [0-2]（默认 v2board）: " num
    if [ -z "${num}" ];then
        num=1
    fi
    case "${num}" in
        0) exit 0
        ;;
        1) type=v2board
        ;;
        2) type=ssp
        ;;
        *) echo -e "${red}请输入正确的数字 [0-2]（默认 v2board）${plain}"
        ;;
    esac
}

get_server_type(){
    echo -e "
  ${green}请选择服务端 server_type 类型${plain}
  ${green}0.${plain} 退出脚本
————————————————

  ${green}1.${plain} v2ray
  ${green}2.${plain} trojan

————————————————
 "
    echo && read -p "请输入选择 [0-2]（默认 v2ray）: " num
    if [ -z "${num}" ];then
        num=1
    fi
    case "${num}" in
        0) exit 0
        ;;
        1) server_type=v2ray
        ;;
        2) server_type=trojan
        ;;
        *) echo -e "${red}请输入正确的数字 [0-2]（默认 v2ray）${plain}"
        ;;
    esac
}

get_node_id(){
    echo -n -e "${green}请输入 node_id:${plain}" ;read node_id
    if [ -z "${node_id}" ];then
        echo -e "${red} node_id 不能为空！${plain}" && exit 1
    fi
}

get_ports(){
    defaule_ports=`shuf -i 10000-65535 -n 1`
    echo -n -e "${green}请输入 ports（默认 ${defaule_ports}）:${plain}" ;read ports
    if [ -z "${ports}" ];then
        ports=${defaule_ports}
    fi
}


get_api(){
    echo -e "
  ${green}请选择对接类型${plain}
  ${green}0.${plain} 退出脚本
————————————————

  ${green}1.${plain} webapi

————————————————
 "
    echo && read -p "请输入选择 [0-1]（默认 webapi）: " num
    if [ -z "${num}" ];then
        num=1
    fi
    case "${num}" in
        0) exit 0
        ;;
        1) api=webapi && get_webapi_url
        ;;
        *) echo -e "${red}请输入正确的数字 [0-1]（默认 webapi）${plain}"
        ;;
    esac
}

get_webapi_url(){
    webapi_url=""
    while [[ -z ${webapi_url} ]]; do
        echo -n -e "${green}请输入 webapi_url（一般就是主页地址）:${plain}" ;read webapi_url
    done
}

get_webapi_mukey(){
    webapi_mukey=""
    while [[ -z ${webapi_mukey} ]]; do
        echo -n -e "${green}请输入 webapi_mukey（前后端通信密钥）:${plain}" ;read webapi_mukey
    done
}

get_soga_key(){
    echo -n -e "${green}请输入授权码 soga_key（社区版不用填写）:${plain}" ;read soga_key
}

get_user_conn_limit(){
    echo -n -e "${green}限制单个用户连接数 user_conn_limit（默认0表示无限制）:${plain}" ;read user_conn_limit
    if [ -z "${user_conn_limit}" ];then
        user_conn_limit=0
    fi
}

get_user_speed_limit(){
    echo -n -e "${green}限制单个用户速度 user_speed_limit（默认0表示无限制，单位Mbps）:${plain}" ;read user_speed_limit
    if [ -z "${user_speed_limit}" ];then
        user_speed_limit=0
    fi
}

get_check_interval(){
    echo -n -e "${green}后端上报、检查间隔时间 check_interval（默认100，单位s）:${plain}" ;read check_interval
    if [ -z "${check_interval}" ];then
        check_interval=100
    fi
}

get_forbidden_bit_torrent(){
    echo -e "
  ${green}是否禁用BT下载（默认为 否）${plain}
————————————————

  ${green}0.${plain} 否
  ${green}1.${plain} 是

————————————————
 "
    echo && read -p "是否禁用BT下载（默认为 否）: " flag
    if [ -z "${flag}" ];then
        flag=0
    fi
    case "${num}" in
        0) forbidden_bit_torrent=false
        ;;
        1) forbidden_bit_torrent=true
        ;;
        *) echo -e "${red}请输入正确的数字 [0-1]（默认 否）${plain}"
        ;;
    esac
}

get_basis(){
    get_type
    get_server_type
    get_api
    get_webapi_mukey
    get_node_id
    get_ports
    get_soga_key
    get_user_conn_limit
    get_user_speed_limit
    get_check_interval
    get_forbidden_bit_torrent
}

show_message(){
    clear
    echo -e "
  ${green}soga-${mode} 配置${plain}
————————————————

  ${green}type=${type}${plain}
  ${green}server_type=${server_type}${plain}
  ${green}api=${api}${plain}
  ${green}webapi_url=${webapi_url}${plain}
  ${green}webapi_mukey=${webapi_mukey}${plain}
  ${green}node_id=${node_id}${plain}
  ${green}ports=${ports}${plain}
  ${green}soga_key=${soga_key}${plain}
  ${green}user_conn_limit=${user_conn_limit}${plain}
  ${green}user_speed_limit=${user_speed_limit}${plain}
  ${green}check_interval=${check_interval}${plain}
  ${green}forbidden_bit_torrent=${forbidden_bit_torrent}${plain}

————————————————
    "


    echo "按任意键继续 或者 CTRL+C 取消执行"; read
}

start(){
    echo "启动程序"
    docker-compose -p $ports up -d
    if [[ $? != 0 ]]; then
    echo "程序启动失败" && exit 1
    fi
    echo "启动日志"
    docker logs $(docker ps | grep soga | awk '{print $1}')

    if [[ `lsmod | grep bbr | awk '{print $1}'` != "tcp_bbr" ]]; then
        echo -n "检查到未开启 bbr,是否开启 bbr (yes/no 默认yes)"; read bbr_ornot
        if [ -z "${bbr_ornot}" ];then
            bbr_ornot=yes
        fi

        if [ ${bbr_ornot} = "yes" ];then
            install_bbr
        fi
    fi
}

choose_mode