# OpenConnect SSL VPN installer


**This project is a bash script that aims to setup a [OpenConnect](https://ocserv.openconnect-vpn.net/) VPN on a Linux server, as easily as possible!**

OpenConnect VPN server (ocserv) is a VPN server compatible with the OpenConnect VPN client. It follows the AnyConnect VPN protocol which is used by several CISCO routers.  

ocserv is OpenConnect SSL VPN Server side, and is designed for privacy, protecting the clients from accessing each others data using strict isolation and privilege separation. It secures the VPN channels using only standard protocols like TLS and Datagram TLS and prevents the leakage of cryptographic keys with Hardware Security Modules (HSMs).

## Requirements

Supported distributions:
Debian/Ubuntu/RHEL/CentOS/Alma/Rocky

## Usage

Download and execute the script. Answer the questions asked by the script and it will take care of the rest.

Option 1: WGET
```sh
wget -N --no-check-certificate https://raw.githubusercontent.com/dzvision/openconnect-install/main/openconnect_vpn_server_install.sh && chmod +x openconnect_vpn_server_install.sh && bash openconnect_vpn_server_install.sh
```

Option 2: CURL
```bash
curl -O https://raw.githubusercontent.com/dzvision/openconnect-install/main/openconnect_vpn_server_install.sh
chmod +x openconnect_vpn_server_install.sh
./openconnect_vpn_server_installl.sh
```

It will install ocserv (kernel module and tools) on the server, configure it, create a systemd service and a client configuration file.

Run the script again to add or remove clients!


## History of this Project
This part originated from the now-discontinued Doubi project. After its sunset, I migrated the script from using FTP downloads to GitLab and have since maintained it as ocserv. The rest of the Doubi projects are archived in a backup folder for historical reference.


## Contributing

Contributions are welcome! Here's how you can help:

### Discuss changes

Please open an issue before submitting a PR if you want to discuss a change, especially if it's a big one.

## Version Update Changes
- **v1.0.6:** Jun 8, 2019 - Debian/Ubuntu only, Originally FTP switch to Gitlab and upgrade to using ocserv 0.12.3
- **v1.0.7:** Debian/Ubuntu + RHEL/CentOS/Rocky/AlmaLinux, ocserv upgrade to 1.3.0
- **v1.0.8:** Added firewalld support for RHEL systems, Added low-memory VPS optimizations, Added RHEL version-specific package handling
- **v1.0.9:** Unified systemd service management across all platforms, Debian also using systemd instead
- **v1.1.0:** Removed Debian source backup; if the installation still fails, switch to linuxmirrors.cn.
- **v1.1.1:** Removed download ocserv.conf from github, directly put code in script.
- **v1.1.2:** Optimize display wording on Debian when apt-get install.
- **v1.1.3:** Repair ronn on RHEL and Debian.
