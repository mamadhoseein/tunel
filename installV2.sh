#!/bin/bash

function get_current_ip() {
    curl -s https://api.ipify.org
}

function execute_commands() {
    for command in "${commands[@]}"; do
        eval "$command" || { echo -e "\033[91mError executing: $command\033[0m"; return 1; }
    done
}

function write_to_rc_local() {
    if [[ -f "/etc/rc.local" ]]; then
        read -p "File /etc/rc.local already exists. Do you want to overwrite it? (y/n): " overwrite
        if [[ $overwrite != "y" && $overwrite != "yes" ]]; then
            echo "Stopped process."
            sleep 5
            return
        fi
    fi

    echo "#! /bin/bash" > /etc/rc.local
    for command in "${commands[@]}"; do
        echo "$command" >> /etc/rc.local
    done
    echo "exit 0" >> /etc/rc.local
    chmod +x /etc/rc.local
}

function install_tunnel() {
    local iran_ip=$1
    local foreign_ip=$2
    local server_type=$3
    local tunnel_type=$4

    commands=()

    if [[ $tunnel_type == "6to4" ]]; then
        if [[ $server_type == "iran" ]]; then
            commands=(
                "ip tunnel add 6to4_iran mode sit remote $foreign_ip local $iran_ip"
                "ip -6 addr add 2002:a00:100::1/64 dev 6to4_iran"
                "ip link set 6to4_iran mtu 1480"
                "ip link set 6to4_iran up"
                "ip -6 tunnel add GRE6Tun_iran mode ip6gre remote 2002:a00:100::2 local 2002:a00:100::1"
                "ip addr add 192.168.168.1/30 dev GRE6Tun_iran"
                "ip link set GRE6Tun_iran mtu 1436"
                "ip link set GRE6Tun_iran up"
                "sysctl net.ipv4.ip_forward=1"
                "iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination 192.168.168.1"
                "iptables -t nat -A PREROUTING -j DNAT --to-destination 192.168.168.2"
                "iptables -t nat -A POSTROUTING -j MASQUERADE"
            )
        else
            commands=(
                "ip tunnel add 6to4_Forign mode sit remote $iran_ip local $foreign_ip"
                "ip -6 addr add 2002:a00:100::2/64 dev 6to4_Forign"
                "ip link set 6to4_Forign mtu 1480"
                "ip link set 6to4_Forign up"
                "ip -6 tunnel add GRE6Tun_Forign mode ip6gre remote 2002:a00:100::1 local 2002:a00:100::2"
                "ip addr add 192.168.168.2/30 dev GRE6Tun_Forign"
                "ip link set GRE6Tun_Forign mtu 1436"
                "ip link set GRE6Tun_Forign up"
                "iptables -A INPUT --proto icmp -j DROP"
            )
        fi
    elif [[ $tunnel_type == "6to6" ]]; then
        if [[ $server_type == "iran" ]]; then
            commands=(
                "ip tunnel add ip6mhm mode ipip6 remote $foreign_ipv6 local $iran_ipv6 ttl 255"
                "ip link set dev ip6mhm up"
                "ip addr add 10.194.25.2/30 dev ip6mhm"
            )
        else
            commands=(
                "ip tunnel add ip6mhm mode ipip6 remote $iran_ipv6 local $foreign_ipv6 ttl 255"
                "ip link set dev ip6mhm up"
                "ip addr add 10.194.25.1/30 dev ip6mhm"
                "iptables -t nat -A POSTROUTING -s 10.194.25.0/24 -j MASQUERADE"
                "sysctl -w net.ipv4.conf.all.forwarding=1"
                "ufw disable"
            )
        fi
    elif [[ $tunnel_type == "iptables" ]]; then
        commands=(
            "sysctl net.ipv4.ip_forward=1"
            "iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination $iran_ip"
            "iptables -t nat -A PREROUTING -j DNAT --to-destination $foreign_ip"
            "iptables -t nat -A POSTROUTING -j MASQUERADE"
        )
    fi

    execute_commands
    write_to_rc_local
    echo -e "\033[92mInstallation successful.\033[0m"
}

function uninstall_tunnel() {
    local server_type=$1
    rm /etc/rc.local
    echo -e "\033[92mUninstallation successful.\033[0m"
}

function install_script() {
    local script_url=$1
    bash <(curl -Ls "$script_url")
}

function main_menu() {
    clear
    echo -e "\033[94mTunnel System Installer/Uninstaller\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    read -p $'\033[93mWhat would you like to do?\n\033[92m1. Install\n\033[91m2. Uninstall\n\033[94m3. Scripts\n\033[0mEnter the number of your choice: ' choice

    case $choice in
        1) install_menu ;;
        2) uninstall_menu ;;
        3) scripts_menu ;;
        *) echo -e "\033[91mInvalid action. Please enter '1', '2', or '3'.\033[0m" ;;
    esac
}

function install_menu() {
    clear
    echo -e "\033[94mInstall Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. 6to4\033[0m"
    echo -e "\033[93m2. 6to6\033[0m"
    echo -e "\033[91m3. iptables\033[0m"
    echo -e "\033[90m6. Back\033[0m"
    read -r tunnel_type

    case $tunnel_type in
        1) tunnel_type="6to4" ;;
        2) tunnel_type="6to6" ;;
        3) tunnel_type="iptables" ;;
        *) echo -e "\033[91mInvalid tunnel type. Please enter '1', '2', or '3'.\033[0m" && return ;;
    esac

    echo -e "\033[93mSelect your server type:\n\033[92m1. Iran\033[0m\n\033[91m2. Foreign\033[0m\n\033[91m3. Back\033[0m"
    read -r server_type

    case $server_type in
        1) server_type="iran"; read -p $'\033[93mEnter the IPv6 address of the Iran server: \033[0m' iran_ipv6; read -p $'\033[93mEnter Foreign server IPv6 address: \033[0m' foreign_ipv6 ;;
        2) server_type="foreign"; read -p $'\033[93mEnter the IPv6 address of the Foreign server: \033[0m' foreign_ipv6; read -p $'\033[93mEnter Iran server IPv6 address: \033[0m' iran_ipv6 ;;
        3) install_menu; return ;;
        *) echo -e "\033[91mInvalid server type. Please enter '1', '2', or '3'.\033[0m" && return ;;
    esac

    install_tunnel "$iran_ipv6" "$foreign_ipv6" "$server_type" "$tunnel_type"
    main_menu
}


function uninstall_menu() {
    clear
    echo -e "\033[94mUninstall Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. Iran\033[0m"
    echo -e "\033[91m2. Foreign\033[0m"
    echo -e "\033[91m3. Back\033[0m"
    read -r server_type

    case $server_type in
        1) server_type="iran" ;;
        2) server_type="foreign" ;;
        3) main_menu; return ;;
        *) echo -e "\033[91mInvalid server type. Please enter '1', '2', or '3'.\033[0m" && return ;;
    esac

    uninstall_tunnel "$server_type"
    main_menu
}

function scripts_menu() {
    clear
    echo -e "\033[94mScripts Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. Install Sanaie Script\033[0m"
    echo -e "\033[34m2. Install Alireza Script\033[0m"
    echo -e "\033[36m3. Install Ghost Script\033[0m"
    echo -e "\033[33m4. Install PFTUN Script\033[0m"
    echo -e "\033[35m5. Install Reverse Script\033[0m"
    echo -e "\033[34m6. Install IR-ISPBLOCKER Script\033[0m"
    echo -e "\033[91m7. Back\033[0m"

    read -p $'\033[93mEnter the number of your choice: \033[0m' script_choice

    case $script_choice in
        1) install_script "https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh" ;;
        2) install_script "https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh" ;;
        3) install_script "https://github.com/masoudgb/Gost-ip6/raw/main/Gost.sh" ;;
        4) install_script "https://raw.githubusercontent.com/opiran-club/pf-tun/main/pf-tun.sh" ;;
        5) install_script "https://raw.githubusercontent.com/Ptechgithub/ReverseTlsTunnel/main/RtTunnel.sh" ;;
        6) install_script "https://raw.githubusercontent.com/Kiya6955/IR-ISP-Blocker/main/ir-isp-blocker.sh" ;;
        7) main_menu ;;
        *) echo -e "\033[91mInvalid choice. Please enter a number from 1 to 6.\033[0m" ;;
    esac
    main_menu
}

main_menu
