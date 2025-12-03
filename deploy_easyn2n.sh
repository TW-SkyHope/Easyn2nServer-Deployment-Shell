#!/bin/bash

# 检测系统发行版
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME=$ID
        OS_VERSION=$VERSION_ID
    else
        echo "无法确定操作系统类型"
        exit 1
    fi
}

# 安装依赖函数
install_dependencies() {
    if [ "$OS_NAME" = "ubuntu" ]; then
        sudo apt-get update
        sudo apt-get install -y autoconf make gcc wget tar ufw
    elif [ "$OS_NAME" = "centos" ]; then
        sudo yum install -y epel-release
        sudo yum install -y autoconf make gcc wget tar firewalld
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
    else
        echo "不支持的操作系统: $OS_NAME"
        exit 1
    fi
}

# 主程序
main() {
    detect_os
    
    # 询问是否在中国大陆
    read -p "节点是否在中国大陆? (y/n): " in_china
    USE_MIRROR=false
    if [[ "$in_china" =~ ^[Yy]$ ]]; then
        USE_MIRROR=true
        echo "将使用国内镜像源"
    fi

    # 安装基础依赖
    install_dependencies

    # 下载n2n二进制包
    N2N_VERSION="3.1.1"
    ARCH="amd64"
    if [ "$USE_MIRROR" = true ]; then
        BASE_URL="https://ghproxy.com/https://github.com/ntop/n2n/releases/download"
    else
        BASE_URL="https://github.com/ntop/n2n/releases/download"
    fi

    if [ "$OS_NAME" = "ubuntu" ]; then
        PKG_NAME="n2n_${N2N_VERSION}_${ARCH}.deb"
        wget "${BASE_URL}/${N2N_VERSION}/${PKG_NAME}"
        sudo dpkg -i "$PKG_NAME"
        rm -f "$PKG_NAME"
    elif [ "$OS_NAME" = "centos" ]; then
        PKG_NAME="n2n-${N2N_VERSION}-1.${ARCH}.rpm"
        wget "${BASE_URL}/${N2N_VERSION}/${PKG_NAME}"
        sudo rpm -ivh "$PKG_NAME"
        rm -f "$PKG_NAME"
    fi

    # 设置easyn2n目录
    read -p "设置easyn2n服务端目录 (默认/opt): " EASYN2N_DIR
    EASYN2N_DIR=${EASYN2N_DIR:-/opt}
    sudo mkdir -p "$EASYN2N_DIR"
    cd "$EASYN2N_DIR" || exit 1

    # 下载并编译n2n 3.0源码
    SOURCE_URL="${BASE_URL}/3.0.tar.gz"
    wget "$SOURCE_URL" -O n2n-3.0.tar.gz
    sudo tar xzvf n2n-3.0.tar.gz
    cd n2n-3.0 || exit 1
    sudo ./autogen.sh
    sudo ./configure
    sudo make
    sudo make install

    # 设置运行端口
    read -p "设置easyn2n运行端口: " PORT
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "无效的端口号"
        exit 1
    fi

    # 配置防火墙
    if [ "$OS_NAME" = "ubuntu" ]; then
        sudo ufw allow "$PORT"/udp
        sudo ufw reload
    elif [ "$OS_NAME" = "centos" ]; then
        sudo firewall-cmd --permanent --add-port="$PORT"/udp
        sudo firewall-cmd --reload
    fi

    # 启动服务
    sudo supernode -p "$PORT" &
    SUPERNODE_PID=$!
    sleep 2

    # 获取本机IP
    IP_ADDR=$(hostname -I | awk '{print $1}')

    echo ""
    echo "========================================"
    echo " easyn2n 节点部署成功!"
    echo "----------------------------------------"
    echo " 监听地址: ${IP_ADDR}:${PORT}"
    echo " 进程ID: ${SUPERNODE_PID}"
    echo "========================================"
    echo ""
    echo "关闭服务:"
    echo "  sudo kill ${SUPERNODE_PID}"
    echo "或手动查找进程:"
    echo "  ps -ef | grep supernode"
    echo "  sudo kill <PID>"
    echo "========================================"

    # 返回前台运行（可选）
    wait $SUPERNODE_PID
}

# 执行主程序
main
