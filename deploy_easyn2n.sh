#!/bin/bash

# 检测系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS_NAME=$ID
    OS_VERSION=$VERSION_ID
else
    echo "无法检测操作系统类型"
    exit 1
fi

# 询问节点位置
read -p "节点是否在中国大陆？(y/n): " IN_CHINA
IN_CHINA=${IN_CHINA:-n}
IN_CHINA=$(echo "$IN_CHINA" | tr '[:upper:]' '[:lower:]')

# 设置下载源
if [[ "$IN_CHINA" == "y" || "$IN_CHINA" == "yes" ]]; then
    GITHUB_PREFIX="https://ghproxy.com/https://github.com/"
else
    GITHUB_PREFIX="https://github.com/"
fi

# 安装基础依赖
install_dependencies() {
    if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
        sudo apt-get update
        sudo apt-get install -y autoconf make gcc wget tar ufw
    elif [[ "$OS_NAME" == "rhel" || "$OS_NAME" == "centos" || "$OS_NAME" == "fedora" ]]; then
        sudo yum install -y epel-release
        sudo yum install -y autoconf make gcc wget tar firewalld
        sudo systemctl start firewalld
        sudo systemctl enable firewalld
    else
        echo "不支持的操作系统: $OS_NAME"
        exit 1
    fi
}

# 安装n2n
install_n2n() {
    local pkg_name
    if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
        pkg_name="n2n_3.1.1_amd64.deb"
        wget "${GITHUB_PREFIX}ntop/n2n/releases/download/3.1.1/$pkg_name"
        sudo dpkg -i "$pkg_name"
        rm -f "$pkg_name"
    else
        pkg_name="n2n-3.1.1-1.x86_64.rpm"
        wget "${GITHUB_PREFIX}ntop/n2n/releases/download/3.1.1/$pkg_name"
        sudo rpm -ivh "$pkg_name"
        rm -f "$pkg_name"
    fi
}

# 编译安装supernode
compile_supernode() {
    read -p "设置easyn2n服务端目录(默认/opt): " SERVER_DIR
    SERVER_DIR=${SERVER_DIR:-/opt}
    
    sudo mkdir -p "$SERVER_DIR"
    cd "$SERVER_DIR" || exit
    
    local tar_file="3.0.tar.gz"
    wget "${GITHUB_PREFIX}ntop/n2n/archive/refs/tags/$tar_file"
    sudo tar xzvf "$tar_file"
    cd n2n-3.0 || exit
    
    sudo ./autogen.sh
    sudo ./configure
    sudo make
    sudo make install
}

# 启动服务
start_service() {
    read -p "设置easyn2n运行端口: " PORT
    
    # 开放防火墙端口
    if [[ "$OS_NAME" == "ubuntu" || "$OS_NAME" == "debian" ]]; then
        sudo ufw allow "$PORT"/udp
        sudo ufw reload
    else
        sudo firewall-cmd --permanent --add-port="$PORT"/udp
        sudo firewall-cmd --reload
    fi
    
    # 启动supernode
    sudo supernode -p "$PORT" > /dev/null 2>&1 &
    
    # 获取IP地址
    IP_ADDR=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
    
    echo ""
    echo "========================================"
    echo "运行成功！"
    echo "连接地址: $IP_ADDR:$PORT"
    echo "========================================"
    echo "要停止服务，请运行: sudo kill \$(pgrep supernode)"
    echo "========================================"
}

# 主流程
main() {
    install_dependencies
    install_n2n
    compile_supernode
    start_service
}

main
