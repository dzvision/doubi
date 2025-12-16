#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

#=================================================
#	System Required: Debian/Ubuntu/RHEL/CentOS
#	Description: ocserv AnyConnect
#	Version: 1.1.5
#	Original Author: Toyo <=1.0.5
#   dzvision = 1.0.6
#   AI Qoder and Trae >=1.0.7
#=================================================
sh_ver="1.1.5"
file="/usr/local/sbin/ocserv"
conf_file="/etc/ocserv"
conf="/etc/ocserv/ocserv.conf"
passwd_file="/etc/ocserv/ocpasswd"
log_file="/tmp/ocserv.log"
#=================================================
# OCServ Version
#=================================================
ocserv_ver="1.3.0"
PID_FILE="/var/run/ocserv.pid"

Green_font_prefix="\033[32m" && Red_font_prefix="\033[31m" && Green_background_prefix="\033[42;37m" && Red_background_prefix="\033[41;37m" && Font_color_suffix="\033[0m"
Info="${Green_font_prefix}[信息]${Font_color_suffix}"
Error="${Red_font_prefix}[错误]${Font_color_suffix}"
Tip="${Green_font_prefix}[注意]${Font_color_suffix}"

check_root(){
	[[ $EUID != 0 ]] && echo -e "${Error} 当前非ROOT账号(或没有ROOT权限)，无法继续操作，请更换ROOT账号或使用 ${Green_background_prefix}sudo su${Font_color_suffix} 命令获取临时ROOT权限（执行后可能会提示输入当前账号的密码）。" && exit 1
}
#检查系统
check_sys(){
    # 定义系统文件路径
    File_LinuxRelease="/etc/os-release"
    
    # 初始化变量
    release=""
    rhel_major_version=""
    
    # 使用 /etc/os-release 文件进行系统检测
    if [ -s "${File_LinuxRelease}" ]; then
        # 从/etc/os-release文件中获取系统信息
        SYSTEM_NAME="$(grep -E "^NAME=" $File_LinuxRelease | cut -d= -f2- | sed "s/[\'\"]//g")"
        SYSTEM_VERSION_ID="$(grep -E "^VERSION_ID=" $File_LinuxRelease | cut -d= -f2- | sed "s/[\'\"]//g")"
        SYSTEM_ID="$(grep -E "^ID=" $File_LinuxRelease | cut -d= -f2- | sed "s/[\'\"]//g")"
        
        # 获取主版本号
        if [[ -n "${SYSTEM_VERSION_ID}" ]]; then
            SYSTEM_VERSION_ID_MAJOR="${SYSTEM_VERSION_ID%%.*}"
        fi
        
        # 根据系统ID判断发行版
        case "${SYSTEM_ID}" in
            debian)
                release="debian"
                ;;
            ubuntu)
                release="ubuntu"
                ;;
            centos|rhel|rocky|almalinux|oracle)
                release="centos"
                rhel_major_version="${SYSTEM_VERSION_ID_MAJOR:-8}"
                ;;
            *)
                # 不支持的系统
                release="unknown"
                ;;
        esac
        
        # 显示检测到的系统信息
        echo -e "${Info} 检测到系统: ${SYSTEM_NAME} ${SYSTEM_VERSION_ID}"
    else
        # 如果没有 /etc/os-release 文件，标记为未知系统
        release="unknown"
        echo -e "${Error} 无法检测到受支持的操作系统，请确保您使用的是 Debian/Ubuntu/RHEL/CentOS/Rocky/AlmaLinux 系统"
        exit 1
    fi
}
check_installed_status(){
	[[ ! -e ${file} ]] && echo -e "${Error} ocserv 没有安装，请检查 !" && exit 1
	[[ ! -e ${conf} ]] && echo -e "${Error} ocserv 配置文件不存在，请检查 !" && [[ $1 != "un" ]] && exit 1
}
check_pid(){
	if [[ ! -e ${PID_FILE} ]]; then
		PID=""
	else
		PID=$(cat ${PID_FILE})
	fi
}
Get_ip(){
	ip=$(wget -qO- -t1 -T2 ipinfo.io/ip)
	if [[ -z "${ip}" ]]; then
		ip=$(wget -qO- -t1 -T2 api.ip.sb/ip)
		if [[ -z "${ip}" ]]; then
			ip=$(wget -qO- -t1 -T2 members.3322.org/dyndns/getip)
			if [[ -z "${ip}" ]]; then
				ip="VPS_IP"
			fi
		fi
	fi
}
Download_ocserv(){
	mkdir "ocserv" && cd "ocserv"
	# Download latest ocserv 1.3.0 from GitLab
	wget "https://gitlab.com/openconnect/ocserv/-/archive/${ocserv_ver}/ocserv-${ocserv_ver}.tar.gz"
	[[ ! -s "ocserv-${ocserv_ver}.tar.gz" ]] && echo -e "${Error} ocserv 源码文件下载失败 !" && rm -rf "ocserv/" && rm -rf "ocserv-${ocserv_ver}.tar.gz" && exit 1
	
	# Extract and build
	tar -xzf ocserv-${ocserv_ver}.tar.gz && cd ocserv-${ocserv_ver}
	
	# Generate configure script (required for GitLab source)
	echo -e "${Info} 生成配置脚本..."
	autoreconf -fvi
	[[ $? != 0 ]] && echo -e "${Error} autoreconf 执行失败 !" && exit 1
	
	# Configure with recommended options
	echo -e "${Info} 配置编译选项..."
	# Disable tests to avoid needing test-only dependencies
	./configure --prefix=/usr/local --sysconfdir=/etc
	[[ $? != 0 ]] && echo -e "${Error} configure 执行失败 !" && exit 1
	
	# Build and install
	echo -e "${Info} 开始编译..."
	make
	[[ $? != 0 ]] && echo -e "${Error} 编译失败 !" && exit 1
	
	echo -e "${Info} 开始安装..."
	make install
	[[ $? != 0 ]] && echo -e "${Error} 安装失败 !" && exit 1
	
	cd .. && cd ..
	rm -rf ocserv/
	
	if [[ -e ${file} ]]; then
		mkdir "${conf_file}"
		# 直接写入ocserv.conf配置文件，避免下载
		# 原文下载路径doubi-original-backup/other/ocserv.conf
	cat > "${conf}" << 'EOF'
auth = "plain[passwd=/etc/ocserv/ocpasswd]"
# listen-host = [IP|HOSTNAME]
tcp-port = 443
udp-port = 443
run-as-user = nobody
run-as-group = daemon
socket-file = /var/run/ocserv-socket
server-cert = /etc/ocserv/ssl/server-cert.pem
server-key = /etc/ocserv/ssl/server-key.pem
ca-cert = /etc/ocserv/ssl/ca-cert.pem
isolate-workers = true
banner = "Welcome DOUB.IO"
max-clients = 0
max-same-clients = 0
rate-limit-ms = 0
server-stats-reset-time = 604800
keepalive = 32400
dpd = 90
mobile-dpd = 1800
switch-to-tcp-timeout = 25
try-mtu-discovery = false
tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0"
auth-timeout = 240
idle-timeout = 86400
mobile-idle-timeout = 86400
min-reauth-time = 300
max-ban-score = 80
ban-reset-time = 1200
cookie-timeout = 300
deny-roaming = false
rekey-time = 172800
rekey-method = ssl
use-occtl = true
pid-file = /var/run/ocserv.pid
net-priority = 6
device = vpns
predictable-ips = true
default-domain = example.com

ipv4-network = 192.168.1.0
ipv4-netmask = 255.255.255.0
# An alternative way of specifying the network:
#ipv4-network = 192.168.1.0/24
# The IPv6 subnet that leases will be given from.
#ipv6-network = fda9:4efe:7e3b:03ea::/48 
# Specify the size of the network to provide to clients. It is
# generally recommended to provide clients with a /64 network in
# IPv6, but any subnet may be specified. To provide clients only
# with a single IP use the prefix 128.
#ipv6-subnet-prefix = 128
#ipv6-subnet-prefix = 64

# tunnel-all-dns = true
dns = 8.8.8.8
dns = 8.8.4.4
ping-leases = false
no-route = 1.0.0.0/255.192.0.0
no-route = 1.64.0.0/255.224.0.0
no-route = 1.112.0.0/255.248.0.0
no-route = 1.176.0.0/255.240.0.0
no-route = 1.192.0.0/255.240.0.0
no-route = 14.0.0.0/255.224.0.0
no-route = 14.96.0.0/255.224.0.0
no-route = 14.128.0.0/255.224.0.0
no-route = 14.192.0.0/255.224.0.0
no-route = 27.0.0.0/255.192.0.0
no-route = 27.96.0.0/255.224.0.0
no-route = 27.128.0.0/255.224.0.0
no-route = 27.176.0.0/255.240.0.0
no-route = 27.192.0.0/255.224.0.0
no-route = 27.224.0.0/255.252.0.0
no-route = 36.0.0.0/255.192.0.0
no-route = 36.96.0.0/255.224.0.0
no-route = 36.128.0.0/255.192.0.0
no-route = 36.192.0.0/255.224.0.0
no-route = 36.240.0.0/255.240.0.0
no-route = 39.0.0.0/255.255.0.0
no-route = 39.64.0.0/255.224.0.0
no-route = 39.96.0.0/255.240.0.0
no-route = 39.128.0.0/255.192.0.0
no-route = 40.72.0.0/255.254.0.0
no-route = 40.124.0.0/255.252.0.0
no-route = 42.0.0.0/255.248.0.0
no-route = 42.48.0.0/255.240.0.0
no-route = 42.80.0.0/255.240.0.0
no-route = 42.96.0.0/255.224.0.0
no-route = 42.128.0.0/255.128.0.0
no-route = 43.224.0.0/255.224.0.0
no-route = 45.65.16.0/255.255.240.0
no-route = 45.112.0.0/255.240.0.0
no-route = 45.248.0.0/255.248.0.0
no-route = 47.92.0.0/255.252.0.0
no-route = 47.96.0.0/255.224.0.0
no-route = 49.0.0.0/255.128.0.0
no-route = 49.128.0.0/255.224.0.0
no-route = 49.192.0.0/255.192.0.0
no-route = 52.80.0.0/255.252.0.0
no-route = 54.222.0.0/255.254.0.0
no-route = 58.0.0.0/255.128.0.0
no-route = 58.128.0.0/255.224.0.0
no-route = 58.192.0.0/255.224.0.0
no-route = 58.240.0.0/255.240.0.0
no-route = 59.32.0.0/255.224.0.0
no-route = 59.64.0.0/255.224.0.0
no-route = 59.96.0.0/255.240.0.0
no-route = 59.144.0.0/255.240.0.0
no-route = 59.160.0.0/255.224.0.0
no-route = 59.192.0.0/255.192.0.0
no-route = 60.0.0.0/255.224.0.0
no-route = 60.48.0.0/255.240.0.0
no-route = 60.160.0.0/255.224.0.0
no-route = 60.192.0.0/255.192.0.0
no-route = 61.0.0.0/255.192.0.0
no-route = 61.80.0.0/255.248.0.0
no-route = 61.128.0.0/255.192.0.0
no-route = 61.224.0.0/255.224.0.0
no-route = 91.234.36.0/255.255.255.0
no-route = 101.0.0.0/255.128.0.0
no-route = 101.128.0.0/255.224.0.0
no-route = 101.192.0.0/255.240.0.0
no-route = 101.224.0.0/255.224.0.0
no-route = 103.0.0.0/255.0.0.0
no-route = 106.0.0.0/255.128.0.0
no-route = 106.224.0.0/255.240.0.0
no-route = 110.0.0.0/255.128.0.0
no-route = 110.144.0.0/255.240.0.0
no-route = 110.160.0.0/255.224.0.0
no-route = 110.192.0.0/255.192.0.0
no-route = 111.0.0.0/255.192.0.0
no-route = 111.64.0.0/255.224.0.0
no-route = 111.112.0.0/255.240.0.0
no-route = 111.128.0.0/255.192.0.0
no-route = 111.192.0.0/255.224.0.0
no-route = 111.224.0.0/255.240.0.0
no-route = 112.0.0.0/255.128.0.0
no-route = 112.128.0.0/255.240.0.0
no-route = 112.192.0.0/255.252.0.0
no-route = 112.224.0.0/255.224.0.0
no-route = 113.0.0.0/255.128.0.0
no-route = 113.128.0.0/255.240.0.0
no-route = 113.192.0.0/255.192.0.0
no-route = 114.16.0.0/255.240.0.0
no-route = 114.48.0.0/255.240.0.0
no-route = 114.64.0.0/255.192.0.0
no-route = 114.128.0.0/255.240.0.0
no-route = 114.192.0.0/255.192.0.0
no-route = 115.0.0.0/255.0.0.0
no-route = 116.0.0.0/255.0.0.0
no-route = 117.0.0.0/255.128.0.0
no-route = 117.128.0.0/255.192.0.0
no-route = 118.16.0.0/255.240.0.0
no-route = 118.64.0.0/255.192.0.0
no-route = 118.128.0.0/255.128.0.0
no-route = 119.0.0.0/255.128.0.0
no-route = 119.128.0.0/255.192.0.0
no-route = 119.224.0.0/255.224.0.0
no-route = 120.0.0.0/255.192.0.0
no-route = 120.64.0.0/255.224.0.0
no-route = 120.128.0.0/255.240.0.0
no-route = 120.192.0.0/255.192.0.0
no-route = 121.0.0.0/255.128.0.0
no-route = 121.192.0.0/255.192.0.0
no-route = 122.0.0.0/254.0.0.0
no-route = 124.0.0.0/255.0.0.0
no-route = 125.0.0.0/255.128.0.0
no-route = 125.160.0.0/255.224.0.0
no-route = 125.192.0.0/255.192.0.0
no-route = 137.59.59.0/255.255.255.0
no-route = 137.59.88.0/255.255.252.0
no-route = 139.0.0.0/255.224.0.0
no-route = 139.128.0.0/255.128.0.0
no-route = 140.64.0.0/255.240.0.0
no-route = 140.128.0.0/255.240.0.0
no-route = 140.192.0.0/255.192.0.0
no-route = 144.0.0.0/255.248.0.0
no-route = 144.12.0.0/255.255.0.0
no-route = 144.48.0.0/255.248.0.0
no-route = 144.123.0.0/255.255.0.0
no-route = 144.255.0.0/255.255.0.0
no-route = 146.196.0.0/255.255.128.0
no-route = 150.0.0.0/255.255.0.0
no-route = 150.96.0.0/255.224.0.0
no-route = 150.128.0.0/255.240.0.0
no-route = 150.192.0.0/255.192.0.0
no-route = 152.104.128.0/255.255.128.0
no-route = 153.0.0.0/255.192.0.0
no-route = 153.96.0.0/255.224.0.0
no-route = 157.0.0.0/255.255.0.0
no-route = 157.18.0.0/255.255.0.0
no-route = 157.61.0.0/255.255.0.0
no-route = 157.112.0.0/255.240.0.0
no-route = 157.144.0.0/255.240.0.0
no-route = 157.255.0.0/255.255.0.0
no-route = 159.226.0.0/255.255.0.0
no-route = 160.19.0.0/255.255.0.0
no-route = 160.20.48.0/255.255.252.0
no-route = 160.202.0.0/255.255.0.0
no-route = 160.238.64.0/255.255.252.0
no-route = 161.207.0.0/255.255.0.0
no-route = 162.105.0.0/255.255.0.0
no-route = 163.0.0.0/255.192.0.0
no-route = 163.96.0.0/255.224.0.0
no-route = 163.128.0.0/255.192.0.0
no-route = 163.192.0.0/255.224.0.0
no-route = 164.52.0.0/255.255.128.0
no-route = 166.111.0.0/255.255.0.0
no-route = 167.139.0.0/255.255.0.0
no-route = 167.189.0.0/255.255.0.0
no-route = 167.220.244.0/255.255.252.0
no-route = 168.160.0.0/255.255.0.0
no-route = 170.179.0.0/255.255.0.0
no-route = 171.0.0.0/255.128.0.0
no-route = 171.192.0.0/255.224.0.0
no-route = 175.0.0.0/255.128.0.0
no-route = 175.128.0.0/255.192.0.0
no-route = 180.64.0.0/255.192.0.0
no-route = 180.128.0.0/255.128.0.0
no-route = 182.0.0.0/255.0.0.0
no-route = 183.0.0.0/255.192.0.0
no-route = 183.64.0.0/255.224.0.0
no-route = 183.128.0.0/255.128.0.0
no-route = 192.124.154.0/255.255.255.0
no-route = 192.140.128.0/255.255.128.0
no-route = 195.78.82.0/255.255.254.0
no-route = 202.0.0.0/255.128.0.0
no-route = 202.128.0.0/255.192.0.0
no-route = 202.192.0.0/255.224.0.0
no-route = 203.0.0.0/255.0.0.0
no-route = 210.0.0.0/255.192.0.0
no-route = 210.64.0.0/255.224.0.0
no-route = 210.160.0.0/255.224.0.0
no-route = 210.192.0.0/255.224.0.0
no-route = 211.64.0.0/255.248.0.0
no-route = 211.80.0.0/255.240.0.0
no-route = 211.96.0.0/255.248.0.0
no-route = 211.136.0.0/255.248.0.0
no-route = 211.144.0.0/255.240.0.0
no-route = 211.160.0.0/255.248.0.0
no-route = 216.250.108.0/255.255.252.0
no-route = 218.0.0.0/255.128.0.0
no-route = 218.160.0.0/255.224.0.0
no-route = 218.192.0.0/255.192.0.0
no-route = 219.64.0.0/255.224.0.0
no-route = 219.128.0.0/255.224.0.0
no-route = 219.192.0.0/255.192.0.0
no-route = 220.96.0.0/255.224.0.0
no-route = 220.128.0.0/255.128.0.0
no-route = 221.0.0.0/255.224.0.0
no-route = 221.96.0.0/255.224.0.0
no-route = 221.128.0.0/255.128.0.0
no-route = 222.0.0.0/255.0.0.0
no-route = 223.0.0.0/255.224.0.0
no-route = 223.64.0.0/255.192.0.0
no-route = 223.128.0.0/255.128.0.0
cisco-client-compat = true
dtls-legacy = true
EOF
		[[ ! -s "${conf}" ]] && echo -e "${Error} ocserv 配置文件创建失败 !" && rm -rf "${conf_file}" && exit 1
	else
		echo -e "${Error} ocserv 编译安装失败，请检查！" && exit 1
	fi
}
Service_ocserv(){
	# Modern systems (Debian 8+, Ubuntu 15.04+, RHEL 7+) use systemd
	cat > /etc/systemd/system/ocserv.service << 'EOF'
[Unit]
Description=OpenConnect SSL VPN server
Documentation=man:ocserv(8)
After=network-online.target

[Service]
PrivateTmp=true
PIDFile=/var/run/ocserv.pid
ExecStart=/usr/local/sbin/ocserv --foreground --pid-file /var/run/ocserv.pid --config /etc/ocserv/ocserv.conf
ExecReload=/bin/kill -HUP $MAINPID

[Install]
WantedBy=multi-user.target
EOF
	systemctl daemon-reload
	systemctl enable ocserv
	echo -e "${Info} ocserv systemd 服务配置完成 !"
}
rand(){
	min=10000
	max=$((60000-$min+1))
	num=$(date +%s%N)
	echo $(($num%$max+$min))
}
Generate_SSL(){
	lalala=$(rand)
	mkdir /tmp/ssl && cd /tmp/ssl
	echo -e 'cn = "'${lalala}'"
organization = "'${lalala}'"
serial = 1
expiration_days = 365
ca
signing_key
cert_signing_key
crl_signing_key' > ca.tmpl
	[[ $? != 0 ]] && echo -e "${Error} 写入SSL证书签名模板失败(ca.tmpl) !" && over
	certtool --generate-privkey --outfile ca-key.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书密匙文件失败(ca-key.pem) !" && over
	certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书文件失败(ca-cert.pem) !" && over
	
	Get_ip
	if [[ -z "$ip" ]]; then
		echo -e "${Error} 检测外网IP失败 !"
		read -e -p "请手动输入你的服务器外网IP:" ip
		[[ -z "${ip}" ]] && echo "取消..." && over
	fi
	echo -e 'cn = "'${ip}'"
organization = "'${lalala}'"
expiration_days = 365
signing_key
encryption_key
tls_www_server' > server.tmpl
	[[ $? != 0 ]] && echo -e "${Error} 写入SSL证书签名模板失败(server.tmpl) !" && over
	certtool --generate-privkey --outfile server-key.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书密匙文件失败(server-key.pem) !" && over
	certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
	[[ $? != 0 ]] && echo -e "${Error} 生成SSL证书文件失败(server-cert.pem) !" && over
	
	mkdir /etc/ocserv/ssl
	mv ca-cert.pem /etc/ocserv/ssl/ca-cert.pem
	mv ca-key.pem /etc/ocserv/ssl/ca-key.pem
	mv server-cert.pem /etc/ocserv/ssl/server-cert.pem
	mv server-key.pem /etc/ocserv/ssl/server-key.pem
	cd .. && rm -rf /tmp/ssl/
}
Installation_dependency(){
	[[ ! -e "/dev/net/tun" ]] && echo -e "${Error} 你的VPS没有开启TUN，请联系IDC或通过VPS控制面板打开TUN/TAP开关 !" && exit 1
	
	if [[ ${release} = "centos" ]]; then
		# RHEL/CentOS/Rocky Linux/AlmaLinux dependencies
		echo -e "${Info} 检测到 RHEL 系列系统，安装依赖..."
		
		# Check system resources for RHEL (EPEL installation is resource-intensive)
		mem_total=$(free -m | awk '/^Mem:/{print $2}')
		cpu_cores=$(nproc)
		echo -e "${Info} 系统配置: CPU ${cpu_cores}核, 内存 ${mem_total}MB"
		
		if [ ${cpu_cores} -lt 2 ] || [ ${mem_total} -lt 1024 ]; then
			echo -e "${Error} ==================== 重要警告 ===================="
			echo -e "${Error} RHEL 系统的 EPEL 仓库和依赖安装对系统资源要求较高！"
			echo -e "${Error} 当前配置: CPU ${cpu_cores}核, 内存 ${mem_total}MB"
			echo -e "${Error} 最低要求: CPU 2核, 内存 1GB (1024MB) RHEL <=8.10"
			echo -e "${Error} "
			echo -e "${Tip} 强烈建议: 使用 Ubuntu/Debian 系统来安装 ocserv！"
			echo -e "${Tip} Ubuntu/Debian 对资源要求更低，安装更快速稳定。"
			echo -e "${Error} ====================================================="
			echo -e ""
			read -e -p "是否强制继续在 RHEL 系统上安装? (可能失败) [y/N]: " force_install
			[[ -z ${force_install} ]] && force_install="n"
			if [[ ${force_install} != [Yy] ]]; then
				echo -e "${Info} 已取消安装。请使用 Ubuntu 20.04/22.04 或 Debian 10/11 重试。"
				exit 0
			fi
			echo -e "${Tip} 用户选择强制继续，如遇到问题请切换到 Ubuntu/Debian..."
		fi
		
		# Clean yum cache to avoid issues
		yum clean all 2>/dev/null
		
		# Enable CRB (CodeReady Builder) repository for RHEL 9
		# This is required for protobuf-c-devel and other development packages
		if command -v dnf &> /dev/null; then
			echo -e "${Info} 启用 CRB (CodeReady Builder) 仓库..."
			dnf config-manager --set-enabled crb 2>/dev/null || \
			dnf config-manager --set-enabled powertools 2>/dev/null || \
			echo -e "${Tip} CRB/PowerTools 仓库可能已启用或不可用"
		fi
		
		# Install EPEL repository and configure mirror
		echo -e "${Info} 配置 EPEL 仓库（使用清华镜像）..."
		if command -v dnf &> /dev/null; then
			dnf install -y epel-release
		else
			yum install -y epel-release
		fi
		
		# Replace EPEL mirror with Tsinghua mirror for faster download
		if [ -f /etc/yum.repos.d/epel.repo ]; then
			sed -e 's!^metalink=!#metalink=!g' \
				-e 's!^#baseurl=!baseurl=!g' \
				-e 's!https\?://download\.fedoraproject\.org/pub/epel!https://mirrors.tuna.tsinghua.edu.cn/epel!g' \
				-e 's!https\?://download\.example/pub/epel!https://mirrors.tuna.tsinghua.edu.cn/epel!g' \
				-i /etc/yum.repos.d/epel.repo
		fi
		
		if [ -f /etc/yum.repos.d/epel-testing.repo ]; then
			sed -e 's!^metalink=!#metalink=!g' \
				-e 's!^#baseurl=!baseurl=!g' \
				-e 's!https\?://download\.fedoraproject\.org/pub/epel!https://mirrors.tuna.tsinghua.edu.cn/epel!g' \
				-e 's!https\?://download\.example/pub/epel!https://mirrors.tuna.tsinghua.edu.cn/epel!g' \
				-i /etc/yum.repos.d/epel-testing.repo
		fi
		
		echo -e "${Info} EPEL 镜像配置完成"
		
		# Refresh metadata once to avoid repeated updates
		echo -e "${Info} 刷新仓库元数据..."
		yum makecache fast 2>/dev/null || yum makecache 2>/dev/null
		
		# Install in smaller batches to reduce memory usage and disk I/O
		echo -e "${Info} 安装构建工具 (1/4)..."
		yum install -y -q vim net-tools make automake gcc --setopt=keepcache=0
		
		echo -e "${Info} 安装构建辅助工具 (2/4)..."
		yum install -y -q pkgconf-pkg-config autoconf libtool rubygem-ronn-ng --setopt=keepcache=0
		
		echo -e "${Info} 安装必需依赖 (3/4)..."
		
		# 统一使用 libev-devel，适用于所有RHEL版本
		echo -e "${Info} 安装必需依赖包..."
		yum install -y -q gnutls-devel libev-devel readline-devel nettle-devel --setopt=keepcache=0
		
		echo -e "${Info} 安装可选依赖 (4/4)..."
		yum install -y -q pam-devel lz4-devel libseccomp-devel libnl3-devel \
			krb5-devel radcli-devel libcurl-devel cjose-devel jansson-devel \
			liboath-devel protobuf-c-devel libtalloc-devel protobuf-c gperf \
			gnutls-utils iproute tcpdump --setopt=keepcache=0 2>/dev/null || echo -e "${Tip} 部分可选包安装失败，不影响核心功能"
		
		# Clean cache after installation to free disk space
		yum clean all 2>/dev/null
		
		echo -e "${Info} 依赖安装完成"
		# Note: Some packages may not be available in base repos
		# The configure script will detect and work without them
	elif [[ ${release} = "debian" ]]; then
		echo -e "${Info} 检测到 Debian 系统，使用默认源安装依赖..."
		apt-get update
		# 安装构建工具
		echo -e "${Info} 安装构建工具 (1/3)..."
		apt-get install -y vim net-tools build-essential pkg-config autoconf automake libtool ronn
		# 安装必需依赖
		echo -e "${Info} 安装必需依赖 (2/3)..."
		apt-get install -y libgnutls28-dev libev-dev libreadline-dev
		# 安装可选依赖
		echo -e "${Info} 安装可选依赖 (3/3)..."
		apt-get install -y libpam0g-dev liblz4-dev libseccomp-dev libnl-route-3-dev \
			libkrb5-dev libradcli-dev libcurl4-gnutls-dev libcjose-dev libjansson-dev \
			liboath-dev libprotobuf-c-dev libtalloc-dev protobuf-c-compiler gperf gnutls-bin ipcalc
		
		# Check if installation was successful
		if [[ $? != 0 ]]; then
			echo -e "${Error} 依赖安装失败，可能是因为系统源的问题。"
			echo -e "${Tip} 推荐使用 linuxmirrors.cn 提供的脚本更换国内源后重试。"
			echo -e "${Tip} 使用方法: curl -sSL https://linuxmirrors.cn/main.sh | bash"
			exit 1
		fi
	else
		apt-get update
		# 安装构建工具
		echo -e "${Info} 安装构建工具 (1/3)..."
		apt-get install -y vim net-tools build-essential pkg-config autoconf automake libtool ronn
		# 安装必需依赖
		echo -e "${Info} 安装必需依赖 (2/3)..."
		apt-get install -y libgnutls28-dev libev-dev libreadline-dev
		# 安装可选依赖
		echo -e "${Info} 安装可选依赖 (3/3)..."
		apt-get install -y libpam0g-dev liblz4-dev libseccomp-dev libnl-route-3-dev \
			libkrb5-dev libradcli-dev libcurl4-gnutls-dev libcjose-dev libjansson-dev \
			liboath-dev libprotobuf-c-dev libtalloc-dev protobuf-c-compiler gperf gnutls-bin ipcalc
	fi
}
Install_ocserv(){
	check_root
	[[ -e ${file} ]] && echo -e "${Error} ocserv 已安装，请检查 !" && exit 1
	echo -e "${Info} 开始安装/配置 依赖..."
	Installation_dependency
	echo -e "${Info} 开始下载/安装 配置文件..."
	Download_ocserv
	echo -e "${Info} 开始下载/安装 服务脚本(init)..."
	Service_ocserv
	echo -e "${Info} 开始自签SSL证书..."
	Generate_SSL
	echo -e "${Info} 开始设置账号配置..."
	Read_config
	Set_Config
	echo -e "${Info} 开始设置防火墙..."
	Set_iptables
	echo -e "${Info} 开始添加防火墙规则..."
	Add_iptables
	echo -e "${Info} 开始保存防火墙规则..."
	Save_iptables
	echo -e "${Info} 所有步骤 安装完毕，开始启动..."
	Start_ocserv
}
Start_ocserv(){
	check_installed_status
	check_pid
	[[ ! -z ${PID} ]] && echo -e "${Error} ocserv 正在运行，请检查 !" && exit 1
	systemctl start ocserv
	sleep 2s
	check_pid
	[[ ! -z ${PID} ]] && View_Config
}
Stop_ocserv(){
	check_installed_status
	check_pid
	[[ -z ${PID} ]] && echo -e "${Error} ocserv 没有运行，请检查 !" && exit 1
	systemctl stop ocserv
}
Restart_ocserv(){
	check_installed_status
	check_pid
	systemctl restart ocserv
	sleep 2s
	check_pid
	[[ ! -z ${PID} ]] && View_Config
}
Set_ocserv(){
	[[ ! -e ${conf} ]] && echo -e "${Error} ocserv 配置文件不存在 !" && exit 1
	tcp_port=$(cat ${conf}|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	udp_port=$(cat ${conf}|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	vim ${conf}
	set_tcp_port=$(cat ${conf}|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	set_udp_port=$(cat ${conf}|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	Del_iptables
	Add_iptables
	Save_iptables
	echo "是否重启 ocserv ? (Y/n)"
	read -e -p "(默认: Y):" yn
	[[ -z ${yn} ]] && yn="y"
	if [[ ${yn} == [Yy] ]]; then
		Restart_ocserv
	fi
}
Set_username(){
	echo "请输入 要添加的VPN账号 用户名"
	read -e -p "(默认: admin):" username
	[[ -z "${username}" ]] && username="admin"
	echo && echo -e "	用户名 : ${Red_font_prefix}${username}${Font_color_suffix}" && echo
}
Set_passwd(){
	echo "请输入 要添加的VPN账号 密码"
	read -e -p "(默认: doub.io):" userpass
	[[ -z "${userpass}" ]] && userpass="doub.io"
	echo && echo -e "	密码 : ${Red_font_prefix}${userpass}${Font_color_suffix}" && echo
}
Set_tcp_port(){
	while true
	do
	echo -e "请输入VPN服务端的TCP端口"
	read -e -p "(默认: 443):" set_tcp_port
	[[ -z "$set_tcp_port" ]] && set_tcp_port="443"
	echo $((${set_tcp_port}+0)) &>/dev/null
	if [[ $? -eq 0 ]]; then
		if [[ ${set_tcp_port} -ge 1 ]] && [[ ${set_tcp_port} -le 65535 ]]; then
			echo && echo -e "	TCP端口 : ${Red_font_prefix}${set_tcp_port}${Font_color_suffix}" && echo
			break
		else
			echo -e "${Error} 请输入正确的数字！"
		fi
	else
		echo -e "${Error} 请输入正确的数字！"
	fi
	done
}
Set_udp_port(){
	while true
	do
	echo -e "请输入VPN服务端的UDP端口"
	read -e -p "(默认: ${set_tcp_port}):" set_udp_port
	[[ -z "$set_udp_port" ]] && set_udp_port="${set_tcp_port}"
	echo $((${set_udp_port}+0)) &>/dev/null
	if [[ $? -eq 0 ]]; then
		if [[ ${set_udp_port} -ge 1 ]] && [[ ${set_udp_port} -le 65535 ]]; then
			echo && echo -e "	TCP端口 : ${Red_font_prefix}${set_udp_port}${Font_color_suffix}" && echo
			break
		else
			echo -e "${Error} 请输入正确的数字！"
		fi
	else
		echo -e "${Error} 请输入正确的数字！"
	fi
	done
}
Set_Config(){
	Set_username
	Set_passwd
	echo -e "${userpass}\n${userpass}"|ocpasswd -c ${passwd_file} ${username}
	Set_tcp_port
	Set_udp_port
	sed -i 's/tcp-port = '"$(echo ${tcp_port})"'/tcp-port = '"$(echo ${set_tcp_port})"'/g' ${conf}
	sed -i 's/udp-port = '"$(echo ${udp_port})"'/udp-port = '"$(echo ${set_udp_port})"'/g' ${conf}
}
Read_config(){
	[[ ! -e ${conf} ]] && echo -e "${Error} ocserv 配置文件不存在 !" && exit 1
	conf_text=$(cat ${conf}|grep -v '#')
	tcp_port=$(echo -e "${conf_text}"|grep "tcp-port ="|awk -F ' = ' '{print $NF}')
	udp_port=$(echo -e "${conf_text}"|grep "udp-port ="|awk -F ' = ' '{print $NF}')
	max_same_clients=$(echo -e "${conf_text}"|grep "max-same-clients ="|awk -F ' = ' '{print $NF}')
	max_clients=$(echo -e "${conf_text}"|grep "max-clients ="|awk -F ' = ' '{print $NF}')
}
List_User(){
	[[ ! -e ${passwd_file} ]] && echo -e "${Error} ocserv 账号配置文件不存在 !" && exit 1
	User_text=$(cat ${passwd_file})
	if [[ ! -z ${User_text} ]]; then
		User_num=$(echo -e "${User_text}"|wc -l)
		user_list_all=""
		for((integer = 1; integer <= ${User_num}; integer++))
		do
			user_name=$(echo -e "${User_text}" | awk -F ':*:' '{print $1}' | sed -n "${integer}p")
			user_status=$(echo -e "${User_text}" | awk -F ':*:' '{print $NF}' | sed -n "${integer}p"|cut -c 1)
			if [[ ${user_status} == '!' ]]; then
				user_status="禁用"
			else
				user_status="启用"
			fi
			user_list_all=${user_list_all}"用户名: "${user_name}" 账号状态: "${user_status}"\n"
		done
		echo && echo -e "用户总数 ${Green_font_prefix}"${User_num}"${Font_color_suffix}"
		echo -e ${user_list_all}
	fi
}
Add_User(){
	Set_username
	Set_passwd
	user_status=$(cat "${passwd_file}"|grep "${username}"':*:')
	[[ ! -z ${user_status} ]] && echo -e "${Error} 用户名已存在 ![ ${username} ]" && exit 1
	echo -e "${userpass}\n${userpass}"|ocpasswd -c ${passwd_file} ${username}
	user_status=$(cat "${passwd_file}"|grep "${username}"':*:')
	if [[ ! -z ${user_status} ]]; then
		echo -e "${Info} 账号添加成功 ![ ${username} ]"
	else
		echo -e "${Error} 账号添加失败 ![ ${username} ]" && exit 1
	fi
}
Del_User(){
	List_User
	[[ ${User_num} == 1 ]] && echo -e "${Error} 当前仅剩一个账号配置，无法删除 !" && exit 1
	echo -e "请输入要删除的VPN账号的用户名"
	read -e -p "(默认取消):" Del_username
	[[ -z "${Del_username}" ]] && echo "已取消..." && exit 1
	user_status=$(cat "${passwd_file}"|grep "${Del_username}"':*:')
	[[ -z ${user_status} ]] && echo -e "${Error} 用户名不存在 ! [${Del_username}]" && exit 1
	ocpasswd -c ${passwd_file} -d ${Del_username}
	user_status=$(cat "${passwd_file}"|grep "${Del_username}"':*:')
	if [[ -z ${user_status} ]]; then
		echo -e "${Info} 删除成功 ! [${Del_username}]"
	else
		echo -e "${Error} 删除失败 ! [${Del_username}]" && exit 1
	fi
}
Modify_User_disabled(){
	List_User
	echo -e "请输入要启用/禁用的VPN账号的用户名"
	read -e -p "(默认取消):" Modify_username
	[[ -z "${Modify_username}" ]] && echo "已取消..." && exit 1
	user_status=$(cat "${passwd_file}"|grep "${Modify_username}"':*:')
	[[ -z ${user_status} ]] && echo -e "${Error} 用户名不存在 ! [${Modify_username}]" && exit 1
	user_status=$(cat "${passwd_file}" | grep "${Modify_username}"':*:' | awk -F ':*:' '{print $NF}' |cut -c 1)
	if [[ ${user_status} == '!' ]]; then
			ocpasswd -c ${passwd_file} -u ${Modify_username}
			user_status=$(cat "${passwd_file}" | grep "${Modify_username}"':*:' | awk -F ':*:' '{print $NF}' |cut -c 1)
			if [[ ${user_status} != '!' ]]; then
				echo -e "${Info} 启用成功 ! [${Modify_username}]"
			else
				echo -e "${Error} 启用失败 ! [${Modify_username}]" && exit 1
			fi
		else
			ocpasswd -c ${passwd_file} -l ${Modify_username}
			user_status=$(cat "${passwd_file}" | grep "${Modify_username}"':*:' | awk -F ':*:' '{print $NF}' |cut -c 1)
			if [[ ${user_status} == '!' ]]; then
				echo -e "${Info} 禁用成功 ! [${Modify_username}]"
			else
				echo -e "${Error} 禁用失败 ! [${Modify_username}]" && exit 1
			fi
		fi
}
Set_Pass(){
	check_installed_status
	echo && echo -e " 你要做什么？
	
 ${Green_font_prefix} 0.${Font_color_suffix} 列出 账号配置
————————
 ${Green_font_prefix} 1.${Font_color_suffix} 添加 账号配置
 ${Green_font_prefix} 2.${Font_color_suffix} 删除 账号配置
————————
 ${Green_font_prefix} 3.${Font_color_suffix} 启用/禁用 账号配置
 
 注意：添加/修改/删除 账号配置后，VPN服务端会实时读取，无需重启服务端 !" && echo
	read -e -p "(默认: 取消):" set_num
	[[ -z "${set_num}" ]] && echo "已取消..." && exit 1
	if [[ ${set_num} == "0" ]]; then
		List_User
	elif [[ ${set_num} == "1" ]]; then
		Add_User
	elif [[ ${set_num} == "2" ]]; then
		Del_User
	elif [[ ${set_num} == "3" ]]; then
		Modify_User_disabled
	else
		echo -e "${Error} 请输入正确的数字[1-3]" && exit 1
	fi
}
View_Config(){
	Get_ip
	Read_config
	clear && echo "===================================================" && echo
	echo -e " AnyConnect 配置信息：" && echo
	echo -e " I  P\t\t  : ${Green_font_prefix}${ip}${Font_color_suffix}"
	echo -e " TCP端口\t  : ${Green_font_prefix}${tcp_port}${Font_color_suffix}"
	echo -e " UDP端口\t  : ${Green_font_prefix}${udp_port}${Font_color_suffix}"
	echo -e " 单用户设备数限制 : ${Green_font_prefix}${max_same_clients}${Font_color_suffix}"
	echo -e " 总用户设备数限制 : ${Green_font_prefix}${max_clients}${Font_color_suffix}"
	echo -e "\n 客户端链接请填写 : ${Green_font_prefix}${ip}:${tcp_port}${Font_color_suffix}"
	echo && echo "==================================================="
}
View_Log(){
	[[ ! -e ${log_file} ]] && echo -e "${Error} ocserv 日志文件不存在 !" && exit 1
	echo && echo -e "${Tip} 按 ${Red_font_prefix}Ctrl+C${Font_color_suffix} 终止查看日志" && echo -e "如果需要查看完整日志内容，请用 ${Red_font_prefix}cat ${log_file}${Font_color_suffix} 命令。" && echo
	tail -f ${log_file}
}
Uninstall_ocserv(){
	check_installed_status "un"
	echo "确定要卸载 ocserv ? (y/N)"
	echo
	read -e -p "(默认: n):" unyn
	[[ -z ${unyn} ]] && unyn="n"
	if [[ ${unyn} == [Yy] ]]; then
		check_pid
		[[ ! -z $PID ]] && kill -9 ${PID} && rm -f ${PID_FILE}
		Read_config
		Del_iptables
		Save_iptables
		
		if [[ ${release} = "centos" ]]; then
			# RHEL/CentOS systemd service
			systemctl disable ocserv 2>/dev/null
			systemctl stop ocserv 2>/dev/null
			rm -rf /usr/lib/systemd/system/ocserv.service
			systemctl daemon-reload
		else
			# Debian/Ubuntu init.d script
			update-rc.d -f ocserv remove
			rm -rf /etc/init.d/ocserv
		fi
		
		rm -rf "${conf_file}"
		rm -rf "${log_file}"
		cd '/usr/local/bin' && rm -f occtl
		rm -f ocpasswd
		cd '/usr/local/bin' && rm -f ocserv-fw
		cd '/usr/local/sbin' && rm -f ocserv
		cd '/usr/local/share/man/man8' && rm -f ocserv.8
		rm -f ocpasswd.8
		rm -f occtl.8
		echo && echo "ocserv 卸载完成 !" && echo
	else
		echo && echo "卸载已取消..." && echo
	fi
}
over(){
	if [[ ${release} = "centos" ]]; then
		# RHEL/CentOS systemd service
		systemctl disable ocserv 2>/dev/null
		systemctl stop ocserv 2>/dev/null
		rm -rf /usr/lib/systemd/system/ocserv.service
		systemctl daemon-reload
	else
		# Debian/Ubuntu init.d script
		update-rc.d -f ocserv remove 2>/dev/null
		rm -rf /etc/init.d/ocserv
	fi
	rm -rf "${conf_file}"
	rm -rf "${log_file}"
	cd '/usr/local/bin' && rm -f occtl
	rm -f ocpasswd
	cd '/usr/local/bin' && rm -f ocserv-fw
	cd '/usr/local/sbin' && rm -f ocserv
	cd '/usr/local/share/man/man8' && rm -f ocserv.8
	rm -f ocpasswd.8
	rm -f occtl.8
	echo && echo "安装过程错误，ocserv 卸载完成 !" && echo
}
Add_iptables(){
	if [[ ${release} = "centos" ]]; then
		# RHEL/CentOS use firewalld
		firewall-cmd --permanent --add-port=${set_tcp_port}/tcp
		firewall-cmd --permanent --add-port=${set_udp_port}/udp
		firewall-cmd --reload
	else
		# Debian/Ubuntu use iptables
		iptables -I INPUT -m state --state NEW -m tcp -p tcp --dport ${set_tcp_port} -j ACCEPT
		iptables -I INPUT -m state --state NEW -m udp -p udp --dport ${set_udp_port} -j ACCEPT
	fi
}
Del_iptables(){
	if [[ ${release} = "centos" ]]; then
		# RHEL/CentOS use firewalld
		firewall-cmd --permanent --remove-port=${tcp_port}/tcp 2>/dev/null
		firewall-cmd --permanent --remove-port=${udp_port}/udp 2>/dev/null
		firewall-cmd --reload
	else
		# Debian/Ubuntu use iptables
		iptables -D INPUT -m state --state NEW -m tcp -p tcp --dport ${tcp_port} -j ACCEPT
		iptables -D INPUT -m state --state NEW -m udp -p udp --dport ${udp_port} -j ACCEPT
	fi
}
Save_iptables(){
	if [[ ${release} = "centos" ]]; then
		# RHEL/CentOS firewalld rules are already saved by firewall-cmd --permanent
		echo -e "${Info} firewalld 规则已保存"
	else
		# Debian/Ubuntu save iptables rules
		iptables-save > /etc/iptables.up.rules
	fi
}
Set_iptables(){
	echo -e "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
	sysctl -p
	
	if [[ ${release} = "centos" ]]; then
		# RHEL/CentOS use firewalld
		echo -e "${Info} 配置 firewalld 防火墙规则..."
		
		# Ensure firewalld is running
		systemctl start firewalld 2>/dev/null
		systemctl enable firewalld 2>/dev/null
		
		# Get default zone
		default_zone=$(firewall-cmd --get-default-zone)
		echo -e "${Info} 默认防火墙区域: ${default_zone}"
		
		# Enable masquerading for VPN
		firewall-cmd --permanent --zone=${default_zone} --add-masquerade
		
		# Add rich rule for IP forwarding if needed
		firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -j MASQUERADE
		
		# Reload firewalld
		firewall-cmd --reload
		echo -e "${Info} firewalld 配置完成"
	else
		# Debian/Ubuntu use iptables
		ifconfig_status=$(ifconfig)
		if [[ -z ${ifconfig_status} ]]; then
			echo -e "${Error} ifconfig 未安装 !"
			read -e -p "请手动输入你的网卡名(一般情况下，网卡名为 eth0，Debian9 则为 ens3，CentOS Ubuntu 最新版本可能为 enpXsX(X代表数字或字母)，OpenVZ 虚拟化则为 venet0):" Network_card
			[[ -z "${Network_card}" ]] && echo "取消..." && exit 1
		else
			Network_card=$(ifconfig|grep "eth0")
			if [[ ! -z ${Network_card} ]]; then
				Network_card="eth0"
			else
				Network_card=$(ifconfig|grep "ens3")
				if [[ ! -z ${Network_card} ]]; then
					Network_card="ens3"
				else
					Network_card=$(ifconfig|grep "venet0")
					if [[ ! -z ${Network_card} ]]; then
						Network_card="venet0"
					else
						ifconfig
						read -e -p "检测到本服务器的网卡非 eth0 \ ens3(Debian9) \ venet0(OpenVZ) \ enpXsX(CentOS Ubuntu 最新版本，X代表数字或字母)，请根据上面输出的网卡信息手动输入你的网卡名:" Network_card
						[[ -z "${Network_card}" ]] && echo "取消..." && exit 1
					fi
				fi
			fi
		fi
		iptables -t nat -A POSTROUTING -o ${Network_card} -j MASQUERADE
		
		iptables-save > /etc/iptables.up.rules
		echo -e '#!/bin/bash\n/sbin/iptables-restore < /etc/iptables.up.rules' > /etc/network/if-pre-up.d/iptables
		chmod +x /etc/network/if-pre-up.d/iptables
	fi
}
Update_Shell(){
	sh_new_ver=$(wget --no-check-certificate -qO- -t1 -T3 "https://raw.githubusercontent.com/dzvision/openconnect-install/main/openconnect_vpn_server_installl.sh"|grep 'sh_ver="'|awk -F "=" '{print $NF}'|sed 's/\"//g'|head -1) && sh_new_type="github"
	[[ -z ${sh_new_ver} ]] && echo -e "${Error} 无法链接到 Github !" && exit 0
	if [[ -e "/etc/init.d/ocserv" ]]; then
		rm -rf /etc/init.d/ocserv
		Service_ocserv
	fi
	wget -N --no-check-certificate "https://raw.githubusercontent.com/dzvision/openconnect-install/main/openconnect_vpn_server_installl.sh" && chmod +x openconnect_vpn_server_installl.sh
	echo -e "脚本已更新为最新版本[ ${sh_new_ver} ] !(注意：因为更新方式为直接覆盖当前运行的脚本，所以可能下面会提示一些报错，无视即可)" && exit 0
}
check_sys
[[ ${release} != "debian" ]] && [[ ${release} != "ubuntu" ]] && [[ ${release} != "centos" ]] && echo -e "${Error} 本脚本不支持当前系统 ${release} !" && exit 1
echo && echo -e " ocserv 一键安装管理脚本 ${Red_font_prefix}[v${sh_ver}]${Font_color_suffix}
  -- Toyo <=1.0.5, dzvision 1.0.6, AI >=1.0.7 --
  
 ${Green_font_prefix}0.${Font_color_suffix} 升级脚本
————————————
 ${Green_font_prefix}1.${Font_color_suffix} 安装 ocserv
 ${Green_font_prefix}2.${Font_color_suffix} 卸载 ocserv
————————————
 ${Green_font_prefix}3.${Font_color_suffix} 启动 ocserv
 ${Green_font_prefix}4.${Font_color_suffix} 停止 ocserv
 ${Green_font_prefix}5.${Font_color_suffix} 重启 ocserv
————————————
 ${Green_font_prefix}6.${Font_color_suffix} 设置 账号配置
 ${Green_font_prefix}7.${Font_color_suffix} 查看 配置信息
 ${Green_font_prefix}8.${Font_color_suffix} 修改 配置文件
 ${Green_font_prefix}9.${Font_color_suffix} 查看 日志信息
————————————" && echo
if [[ -e ${file} ]]; then
	check_pid
	if [[ ! -z "${PID}" ]]; then
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 并 ${Green_font_prefix}已启动${Font_color_suffix}"
	else
		echo -e " 当前状态: ${Green_font_prefix}已安装${Font_color_suffix} 但 ${Red_font_prefix}未启动${Font_color_suffix}"
	fi
else
	echo -e " 当前状态: ${Red_font_prefix}未安装${Font_color_suffix}"
fi
echo
read -e -p " 请输入数字 [0-9]:" num
case "$num" in
	0)
	Update_Shell
	;;
	1)
	Install_ocserv
	;;
	2)
	Uninstall_ocserv
	;;
	3)
	Start_ocserv
	;;
	4)
	Stop_ocserv
	;;
	5)
	Restart_ocserv
	;;
	6)
	Set_Pass
	;;
	7)
	View_Config
	;;
	8)
	Set_ocserv
	;;
	9)
	View_Log
	;;
	*)
	echo "请输入正确数字 [0-9]"
	;;
esac

