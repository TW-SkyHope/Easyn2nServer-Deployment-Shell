#!/bin/bash

# 询问节点位置
read -p "节点是否在中国大陆？(y/n): " in_china

# 设置下载基础URL
if [[ "$in_china" =~ ^[Yy]$ ]]; then
    BASE_URL="https://ghproxy.com/https://github.com"
else
    BASE_URL="https://github.com"
fi

# 检测系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    echo "无法确定操作系统类型"
    exit 1
fi

# 安装n2n预编译包
install_prebuilt() {
    if [[ "$OS" =~ (ubuntu|debian) ]]; then
        PKG_NAME="n2n_3.1.1_amd64.deb"
        wget "${BASE_URL}/ntop/n2n/releases/download/3.1.1/${PKG_NAME}"
        sudo dpkg -i "$PKG_NAME"
        rm "$PKG_NAME"
    elif [[ "$OS" =~ (rhel|centos|fedora) ]]; then
        PKG_NAME="n2n-3.1.1-1.x86_64.rpm"
        wget "${BASE_URL}/ntop/n2n/releases/download/3.1.1/${PKG_NAME}"
        sudo rpm -ivh "$PKG_NAME"
        rm "$PKG_NAME"
    else
        echo "不支持的操作系统: $OS"
        exit 1
    fi
}

# 安装编译依赖
install_dependencies() {
    if [[ "$OS" =~ (ubuntu|debian) ]]; then
        sudo apt-get update
        sudo apt-get install -y autoconf make gcc
    elif [[ "$OS" =~ (rhel|centos|fedora) ]]; then
        sudo yum install -y autoconf make gcc
    fi
}

# 主程序
main() {
    # 安装预编译包
    install_prebuilt
    
    # 安装依赖
    install_dependencies
    
    # 设置目录
    read -p "设置easyn2n服务端目录(默认/opt): " work_dir
    work_dir=${work_dir:-/opt}
    sudo mkdir -p "$work_dir"
    cd "$work_dir" || exit
    
    # 下载并编译源码
    sudo wget "${BASE_URL}/ntop/n2n/archive/refs/tags/3.0.tar.gz"
    sudo tar xzvf 3.0.tar.gz
    cd n2n-3.0 || exit
    sudo ./autogen.sh
    sudo ./configure
    sudo make && sudo make install
    
    # 设置端口
    read -p "设置easyn2n运行端口: " port
    sudo ufw allow "$port"/udp 2>/dev/null || \
        sudo firewall-cmd --add-port="$port"/udp --permanent 2>/dev/null || \
        echo "警告: 无法自动配置防火墙，请手动开放端口 $port/udp"
    
    # 启动服务
    sudo supernode -p "$port" > /dev/null 2>&1 &
    sleep 2
    
    # 获取IP地址
    ip_addr=$(ip -o route get 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')
    
    # 输出结果
    echo ""
    echo "========================================"
    echo " easyn2n 节点部署成功!"
    echo "========================================"
    echo "监听地址: ${ip_addr}:${port}"
    echo "连接命令: edge -a 虚拟IP -c 组名 -k 密码 -l ${ip_addr}:${port}"
    echo "========================================"
    echo "关闭命令: sudo kill \$(ps -ef | grep 'supernode' | grep -v grep | awk '{print \$2}')"
    echo "========================================"
}

# 执行主程序
main
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
