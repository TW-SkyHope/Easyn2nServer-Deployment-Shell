#!/bin/bash

# 询问节点位置
read -p "节点是否在中国大陆？(y/n): " in_china

# 设置下载代理
if [[ "$in_china" =~ ^[Yy]$ ]]; then
    proxy="https://ghproxy.com/"
else
    proxy=""
fi

# 检测系统类型
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si | tr '[:upper:]' '[:lower:]')
else
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
fi

# 设置安装目录
read -p "请输入easyn2n服务端目录（默认/opt）: " install_dir
install_dir=${install_dir:-/opt}

# 创建目录并进入
sudo mkdir -p "$install_dir"
cd "$install_dir" || exit 1

# 安装n2n主程序
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    pkg_name="n2n_3.1.1_amd64.deb"
    download_url="${proxy}https://github.com/ntop/n2n/releases/download/3.1.1/n2n_3.1.1_amd64.deb"
    wget "$download_url" -O "$pkg_name"
    sudo dpkg -i "$pkg_name"
    sudo apt-get update
    sudo apt-get install -y autoconf make gcc
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    pkg_name="n2n-3.1.1-1.x86_64.rpm"
    download_url="${proxy}https://github.com/ntop/n2n/releases/download/3.1.1/n2n-3.1.1-1.x86_64.rpm"
    wget "$download_url" -O "$pkg_name"
    sudo rpm -ivh "$pkg_name"
    sudo yum install -y autoconf make gcc
else
    echo "不支持的操作系统: $OS"
    exit 1
fi

# 下载并编译源码
src_url="${proxy}https://github.com/ntop/n2n/archive/refs/tags/3.0.tar.gz"
sudo wget "$src_url" -O "3.0.tar.gz"
sudo tar xzvf "3.0.tar.gz"
cd n2n-3.0 || exit 1
sudo ./autogen.sh
sudo ./configure
sudo make
sudo make install

# 设置运行端口
read -p "请输入运行端口（默认7777）: " port
port=${port:-7777}

# 配置防火墙
if [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    sudo ufw allow "$port"/udp
    sudo ufw reload
elif [[ "$OS" == "centos" || "$OS" == "rhel" || "$OS" == "fedora" ]]; then
    if command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port="$port"/udp
        sudo firewall-cmd --reload
    elif command -v iptables &> /dev/null; then
        sudo iptables -A INPUT -p udp --dport "$port" -j ACCEPT
        sudo service iptables save
    fi
fi

# 启动服务
sudo supernode -p "$port" > /dev/null 2>&1 &
sleep 2  # 等待进程启动

# 获取本机IP
ip=$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p')

# 显示结果
echo ""
echo "========================================"
echo " easyn2n节点部署成功!"
echo "----------------------------------------"
echo " 监听端口: UDP/$port"
echo " 连接地址: $ip:$port"
echo "----------------------------------------"
echo " 查看运行状态: ps -ef | grep supernode"
echo " 关闭节点: sudo kill $(pgrep supernode)"
echo "========================================"
