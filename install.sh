#!/bin/bash

function get_current_ip() {
    local current_ip
    current_ip=$(curl -s https://api.ipify.org)
    echo "$current_ip"
}

install_tunnel() {
    local iran_ip=$1
    local foreign_ip=$2
    local server_type=$3
    local tunnel_type=$4

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
        elif [[ $server_type == "foreign" ]]; then
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
    elif [[ $tunnel_type == "iptables" ]]; then
        commands=(
            "sysctl net.ipv4.ip_forward=1"
            "iptables -t nat -A PREROUTING -p tcp --dport 22 -j DNAT --to-destination $iran_ip"
            "iptables -t nat -A PREROUTING -j DNAT --to-destination $foreign_ip"
            "iptables -t nat -A POSTROUTING -j MASQUERADE"
        )
    fi

    for command in "${commands[@]}"; do
        eval "$command"
    done

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

    echo -e "\033[92mSuccessful\033[0m"
}

uninstall_tunnel() {
    local server_type=$1

    rm /etc/rc.local

    echo -e "\033[92mSuccessful\033[0m"
}

install_sanaie_script() {
    bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
}

install_alireza_script() {
    bash <(curl -Ls https://raw.githubusercontent.com/alireza0/x-ui/master/install.sh)
}

install_ghost_script() {
    bash <(curl -Ls https://github.com/masoudgb/Gost-ip6/raw/main/Gost.sh)
}

install_pftun_script() {
    bash <(curl -s https://raw.githubusercontent.com/opiran-club/pf-tun/main/pf-tun.sh --ipv4)
}

install_reverse_script() {
    bash <(curl -fsSL https://raw.githubusercontent.com/Ptechgithub/ReverseTlsTunnel/main/RtTunnel.sh)
}

install_ispblocker_script() {
    bash <(curl -s https://raw.githubusercontent.com/Kiya6955/IR-ISP-Blocker/main/ir-isp-blocker.sh)
}

main_menu() {
    clear
    echo -e "\033[94mTunnel System Installer/Uninstaller\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    read -p $'\033[93mWhat would you like to do?\n\033[92m1. Install\n\033[91m2. Uninstall\n\033[94m3. Scripts\n\033[0mEnter the number of your choice: ' choice

    if [[ $choice != "1" && $choice != "2" && $choice != "3" ]]; then
        echo -e "\033[91mInvalid action. Please enter '1', '2', or '3'.\033[0m"
        return
    fi

    if [[ $choice == "1" ]]; then
        install_menu
    elif [[ $choice == "2" ]]; then
        uninstall_menu
    elif [[ $choice == "3" ]]; then
        scripts_menu
    fi
}

install_menu() {
    clear
    echo -e "\033[94mInstall Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. 6to4\033[0m"
    echo -e "\033[91m2. iptables\033[0m"
    echo -e "\033[90m6. Back\033[0m"
    read -r tunnel_type

    if [[ $tunnel_type != "1" && $tunnel_type != "2" && $tunnel_type != "3" ]]; then
        echo -e "\033[91mInvalid tunnel type. Please enter '1', '2', or '3'.\033[0m"
        return
    fi

    if [[ $tunnel_type == "1" ]]; then
        tunnel_type="6to4"
    elif [[ $tunnel_type == "2" ]]; then
        tunnel_type="iptables"
    elif [[ $tunnel_type == "3" ]]; then
        main_menu
        return
    fi

    echo -e "\033[93mSelect your server type:\n\033[92m1. Iran\033[0m\n\033[91m2. Foreign\033[0m\n\033[91m3. Back\033[0m\nEnter the number of your server type: "
    read -r server_type

    if [[ $server_type != "1" && $server_type != "2" && $server_type != "3" ]]; then
        echo -e "\033[91mInvalid server type. Please enter '1', '2', or '3'.\033[0m"
        return
    fi

    if [[ $server_type == "1" ]]; then
        server_type="iran"
        iran_ip=$(get_current_ip)
        echo -e "\033[93mIran server IP address: $iran_ip\033[0m"
        read -p $'\033[93mEnter Foreign server IP address: \033[0m' foreign_ip
    elif [[ $server_type == "2" ]]; then
        server_type="foreign"
        foreign_ip=$(get_current_ip)
        echo -e "\033[93mForeign server IP address: $foreign_ip\033[0m"
        read -p $'\033[93mEnter Iran server IP address: \033[0m' iran_ip
    elif [[ $server_type == "3" ]]; then
        install_menu
        return
    fi

    install_tunnel "$iran_ip" "$foreign_ip" "$server_type" "$tunnel_type"
    main_menu
}

uninstall_menu() {
    clear
    echo -e "\033[94mUninstall Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. Iran\033[0m"
    echo -e "\033[91m2. Foreign\033[0m"
    echo -e "\033[91m3. Back\033[0m"
    read -r server_type

    if [[ $server_type != "1" && $server_type != "2" && $server_type != "3" ]]; then
        echo -e "\033[91mInvalid server type. Please enter '1', '2', or '3'.\033[0m"
        return
    fi

    if [[ $server_type == "1" ]]; then
        server_type="iran"
    elif [[ $server_type == "2" ]]; then
        server_type="foreign"
    elif [[ $server_type == "3" ]]; then
        main_menu
        return
    fi

    uninstall_tunnel "$server_type"
    main_menu
}

scripts_menu() {
    clear
    echo -e "\033[94mScripts Menu\033[0m"
    echo -e "\033[93m-----------------------------------------\033[0m"
    echo -e "\033[92m1. Install Sanaie Script\033[0m"
    echo -e "\033[34m2. Install Alireza Script\033[0m"
    echo -e "\033[36m3. Install Ghost Script\033[0m"
    echo -e "\033[33m4. Install PFTUN Script\033[0m"
    echo -e "\033[35m5. Install Reverse Script\033[0m"
    echo -e "\033[34m6. Install IR-ISPBLOCKER Script\033[0m"
    echo -e "\033[91m6. Back\033[0m"

    read -p $'\033[93mEnter the number of your choice: \033[0m' script_choice

    case $script_choice in
        1)
            install_sanaie_script
            ;;
        2)
            install_alireza_script
            ;;
        3)
            install_ghost_script
            ;;
        4)
            install_pftun_script
            ;;
        5)
            install_reverse_script
            ;;
        6)
            install_ispblocker_script
            ;;
        7)
            main_menu
            ;;    
        *)
            echo -e "\033[91mInvalid choice. Please enter a number from 1 to 6.\033[0m"
            ;;
    esac
    main_menu
}

main_menu
