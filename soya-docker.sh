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

install(){
    uninstall
    install_docker
    start_docker
    install_docker_compose
}

install_docker() {
    echo -e "${green}即将安装 docker${plain}"
    yum remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
    curl -fsSL https://get.docker.com | bash
    if [[ $? == 0 ]]; then
        echo -e "${green}docker 安装成功${plain}"
    else
        echo -e "${red}docker 安装失败${plain}" && exit 1
    fi
}

install_docker_compose() {
    echo -e "${green}即将安装 docker${plain}"
    curl -L "https://github.com/docker/compose/releases/download/1.25.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    if [[ $? == 0 ]]; then
        echo -e "${green}docker-compose 安装成功${plain}"
    else
        echo -e "${red}docker-compose 安装失败${plain}" && exit 1
    fi
    chmod a+x /usr/local/bin/docker-compose
    if [[ $? == 0 ]]; then
        echo -e "${green}docker-compose 赋予权限成功${plain}"
    else
        echo -e "${red}docker-compose 赋予权限失败${plain}" && exit 1
    fi
}

start_docker(){
    systemctl start docker
    service docker start
    systemctl enable docker.service
    systemctl status docker.service
    echo -e "${green}docker 启动成功${plain}"
}

uninstall(){

    case "${release}" in
        centos) yum remove -y docker-ce \
                              docker-ce-cli && 
                rm -rf /var/lib/docker && 
                rm -rf /var/lib/docker*
                rm -rf /usr/local/bin/docker-compose
                echo -e "${green}docker && docker-compose 卸载完成${plain}"
        ;;
        debian) apt-get remove docker docker-engine docker.io containerd runc
        ;;
        ubuntu) apt-get remove docker docker-engine docker.io containerd runc
        ;;
        *) echo -e "${red}请输入正确的数字 [0-4]${plain}"
        ;;
    esac
}


show_usage() {
    echo "soga 管理脚本使用方法: "
    echo "------------------------------------------"
    echo "soga              - 显示管理菜单 (功能更多)"
    echo "soga start        - 启动 soga"
    echo "soga stop         - 停止 soga"
    echo "soga restart      - 重启 soga"
    echo "soga status       - 查看 soga 状态"
    echo "soga enable       - 设置 soga 开机自启"
    echo "soga disable      - 取消 soga 开机自启"
    echo "soga log          - 查看 soga 日志"
    echo "soga update       - 更新 soga"
    echo "soga install      - 安装 soga"
    echo "soga uninstall    - 卸载 soga"
    echo "soga version      - 查看 soga 版本"
    echo "------------------------------------------"
}

show_menu() {
    echo -e "
  ${green}soga 后端一键对接脚本，${plain}${red}docker部署${plain}
--- https://github.com/beeij/soga一键 ---
  ${green}0.${plain} 退出脚本
————————————————

  ${green}1.${plain} 对接
  ${green}2.${plain} 更新
  ${green}3.${plain} 卸载

————————————————
  ${green}4.${plain} 一键安装 bbr (最新内核)
 "
    echo && read -p "请输入选择 [0-4]: " num

    case "${num}" in
        0) exit 0
        ;;
        1) install
        ;;
        2) check_install && update
        ;;
        3) uninstall
        ;;
        *) echo -e "${red}请输入正确的数字 [0-4]${plain}"
        ;;
    esac
}


if [[ $# > 0 ]]; then
    case $1 in
        "start") check_install 0 && start 0
        ;;
        "stop") check_install 0 && stop 0
        ;;
        "restart") check_install 0 && restart 0
        ;;
        "status") check_install 0 && status 0
        ;;
        "enable") check_install 0 && enable 0
        ;;
        "disable") check_install 0 && disable 0
        ;;
        "log") check_install 0 && show_log 0
        ;;
        "update") check_install 0 && update 0
        ;;
        "install") check_uninstall 0 && install 0
        ;;
        "uninstall") check_install 0 && uninstall 0
        ;;
        "version") check_install 0 && show_soga_version 0
        ;;
        *) show_usage
    esac
else
    show_menu
fi