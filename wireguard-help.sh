#!/bin/bash

# =====================================================
# WireGuard-help.sh
# Wireguard installer, hub and peer creator v0.2a (c) suuhm 2023
#
# For building complex topologies (HUB/SPOKES) and using WireGuard with TCP stack
# 
# Credits/Inspirations:
# ---------------------
# - https://the-suuhmmary.coldwareveryday.com/how-to-wireguard-behind-nat/
# - https://github.com/wangyu-/udp2raw
# - https://www.procustodibus.com/blog/2022/06/multi-hop-wireguard/#internet-gateway-as-a-spoke
# - yet another google search
# =====================================================
#
# START WINDOWS
# -------------
#
# START ->   "c:\Program Files\WireGuard\wireguard.exe" /installtunnelservice c:\wg0.conf
# STOP ->   "c:\Program Files\WireGuard\wireguard.exe" /uninstalltunnelservice wg0
# HELP ->   "c:\Program Files\WireGuard\wireguard.exe" -h 
#
# Or using wg_help_win.bat
#

#
# GLOBAL VAR SERVER DATA
#
LPORT=51820
IPADDR="10.1.1.1"
SN=24
IPV6="fdfc:cccc:dddd:ffff::/64"
# /24 Scope only yet!
# MISC
IPEXT=$(curl -s ifconfig.co)
PORTEXT=443 #maybe useful for fw bypassing
NDEV=$(ip r | grep defa | sed 's/.*dev\ \([^ ]*\).*/\1/g')
[ ! -f /etc/wireguard/.SCOPE ] && mkdir -p /etc/wireguard 2>/dev/null && echo $IPADDR > /etc/wireguard/.SCOPE
__XIP=$(cut -d "." -f4 < /etc/wireguard/.SCOPE)
PREUP_RULES=""


clear
echo "  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒"
echo "  ▒▒▒                                                       ▒▒▒"
echo "  ▒▒▒            W I R E G U A R D - H E L P                ▒▒▒"
echo "   ▒   ===================================================   ▒ "
echo "   ▒  Wireguard admin and peer creator v0.2a (c) suuhm 2023  ▒ "
echo "   ▒                                                         ▒ "
echo "   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ "


_server_conf() {

    echo; read -p "[?] Please enter your IPS Provider IP [$IPEXT] " IP_IN
    [ -z $IP_IN ] && IPEXT=$IPEXT || IPEXT=$IP_IN
    echo; read -p "[?] Please enter your ListenPort [$LPORT] " PORT_IN
    [ -z $PORT_IN ] && LPORT=$LPORT || LPORT=$PORT_IN

    #until _topology_mode; do : ; done
    while [ ! $? -eq 1 ]; do
        _topology_mode
    done

    echo -e "\n[*] Setup IP forwarding..."
    #echo -e "#wg server port forward\nnet.ipv4.ip_forward=1\nnet.ipv6.conf.all.forwarding=1" >> /etc/sysctl.conf
    #reboot
    sysctl -p

    # Keygen process..
    echo -e "\n[*] Generating keys and config for Serverside, take some time..."; sleep 3
    cd /etc/wireguard && umask 077
    wg genkey | tee priv-serv.key | wg pubkey > pub-serv.key
    # Setup rw only on private key:
    chmod 600 priv-serv.key


    cat << EOG > /etc/wireguard/wire0.conf
[Interface]
PrivateKey = $(cat priv-serv.key)
Address = $IPADDR/$SN
#
# IPv6 Scopes:
# Localhost ::1/128
# Link Local Unicast (APIPA) fe80::/64
# Unique Local Host fc00 --> fdff (fc00::/7)
# Multicast ff00::/8
#
Address = $IPV6
ListenPort = $LPORT
#SaveConfig = true

PreUp = sysctl -w net.ipv4.ip_forward=1
PostDown = sysctl -w net.ipv4.ip_forward=1
$PREUP_RULES
$POSTDOWN_RULES

#UDP TUN PASSTHOUGH:
#--------------
#MTU = 1280
#PreUp = udp2raw -s -l 0.0.0.0:51822 -r 127.0.0.1:51821 -k "key" -a >/var/log/udp2raw.log 2>&1 &
#PreUp = speederv2 -s -l 0.0.0.0:51821 -r 127.0.0.1:51820 -f20:20 --timeout 8 >/var/log/udp2speeder.log 2>&1 &
#PostDown = killall udp2raw speederv2 || true
EOG

    chmod 600 /etc/wireguard/wire0.conf
    # fw allowing
    # ufw allow $LPORT/udp
    iptables -A INPUT -p udp --dport $LPORT -j ACCEPT
    
    echo; read -p "[?] Starting wireguard Host? [Y/N] " YN ;echo
    [ "$YN" == "N" ] && exit 0;

    _run_wg

}


_client_conf() {

    echo; read -p "[?] Please enter a name of the User Peer: " UCLIENT

    #until _topology_mode; do : ; done
    while [ ! $? -eq 1 ]; do
        _topology_mode
    done

    echo -e "\n[**] Enter allowed IP-range (Example: 0.0.0.0/0, ::/0 -> Route all)"

    echo; read -p "[?] Input [Default: ${IPADDR%.*}.0/24] " AIPS
    [ "$AIPS" == "" ] && ALLOWED_IPS="AllowedIPs = ${IPADDR%.*}.0/24" || ALLOWED_IPS="AllowedIPs = $AIPS"


    echo -e "\n[*] Generating keys and config for Clientside ($UCLIENT), take some time..."; sleep 3
    # change dir and create keys
    cd /etc/wireguard && umask 077
    wg genkey | tee priv-client_$UCLIENT.key | wg pubkey > pub-client_$UCLIENT.key
    # Setup rw only on private key:
    chmod 600 priv-client_$UCLIENT.key

    # Raise VIRTUAL-IP Address /24:
    #echo $__XIP > /etc/wireguard/.SCOPE
    PEER_IP=$(echo $IPADDR | awk -v xip=$__XIP -F "." '{print $1"."$2"."$3"."xip+1}') 
    let __XIP++ ; echo $__XIP > /etc/wireguard/.SCOPE
    
    cat << EOG > /etc/wireguard/client_$UCLIENT.conf
[Interface]
PrivateKey = $(cat priv-client_$UCLIENT.key)
Address = $PEER_IP/32
ListenPort = 51337
#
# Adminforge DNS / Quard9 ?
# DNS = 176.9.93.198, 176.9.1.117, 2a01:4f8:151:34aa::198, 2a01:4f8:141:316d::117
# DNS = 9.9.9.9, 2620:fe::9
$CPREUP_RULES
$CPOSTDOW_RULES

[Peer]
PublicKey = $(cat pub-serv.key)
Endpoint = $IPEXT:$LPORT
$ALLOWED_IPS
PersistentKeepalive = 25
EOG

    echo
    echo -e "[+] Adding peer client_$UCLIENT.conf with IP: $PEER_IP on server...\n"
    wg set wire0 peer $(cat pub-client_$UCLIENT.key) allowed-ips $PEER_IP/32

    echo -e "\n=============================================================================================="
    echo -e "================================   S H O W   C O N F I G   ==================================="
    echo -e "==============================================================================================\n"
    cat /etc/wireguard/client_$UCLIENT.conf
    echo -e "\n==============================================================================================\n"

    echo -e "\n[!!] Copy config to client and run: wg-quick up client_$UCLIENT\n\n"; sleep 2

    echo; read -p "[?] Start SCP Transfer of config? [Y/N] " YN ;echo
    if [ "$YN" == "Y" ] || [ "$YN" == "y" ]; then
        echo; read -p "[?] Please enter your SSH Server IP [$IPEXT] " IP_SSH ;echo
        echo; read -p "[?] Please enter your SSH Port [22] " PORT_SSH ;echo
        echo; read -p "[?] Please enter your SSH User [$(whoami)] " USER_SSH ;echo
        scp /etc/wireguard/client_$UCLIENT.conf -l$USER_SSH -p$PORT_SSH $IP_SSH:/etc/wireguard/
    else
        return 0
    fi
}


_topology_mode() {

    echo -e "\n[!] Choose Topology / Mode:\n

    [[ 1 ]] DEFAULT - PEER TO PEER:
    # ----------------------------
    # EP 1 ===> HUB <=== EP2
    # 

    [[ 2 ]] LAN PARTY GAMING:
    # -----------------------
    # EP 1 ===> [ P:443 : HUB/ SPOKE ] <=== EP 2
    # ROUTE OVER V_NET OR ALL ::0/0
    #

    [[ 3 ]] INTERNET PROXY GW:
    # ------------------------
    # ROUTE ALL OVER HUB
    # EP 1 ===> HUB ===> (WWW)
    # 

    [[ 4 ]] SITE GATEWAY AS A SPOKE:
    # ------------------------------
    # ROUTE FROM EP1 OVER HUB TO SITE EP2
    # EP 1 ===> HUB ===> EP 2 ---> (NO WG CLIENTS)
    # 

    [[ 5 ]] HUB IS SITE GATEWAY WITH INET GW SPOKE:
    # ---------------------------------------------
    # ROUTE FROM EP1 OVER HUB /W SITEGW TO SITE EP2 WITH INET GW
    # EP 1 ===> HUB (---> (CLIENTS)) ===> EP 2 ---> (WWW)
    # 
    \n"

    read -p "[?] Please enter the number of wished mode [Default = 1]: " TINPUT

case $TINPUT in
    1)
        # TOPOLOGIES / MODES:
        #
        # DEFAULT PEER TO PEER:
        # ---------------------
        # EP 1 ===> HUB <=== EP2
        # 
        PREUP_RULES=""
        ;;

    2)
        # LAN PARTY GAMING:
        # -----------------
        # EP 1 ===> [ P:443 : HUB/ SPOKE ] <=== EP 2
        # ROUTE OVER V_NET OR ALL ::0/0
        #
        PREUP_RULES="#NOPOSTUP NEDDED?"
        ;;

    3)
        # DEFAULT PEER TO PEER:
        # ---------------------
        # ROUTE ALL OVER HUB
        # EP 1 ===> HUB ===> (WWW)
        # 
        PREUP_RULES="PostUp = iptables -A FORWARD -i wire0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $NDEV -j MASQUERADE; ip6tables -A FORWARD -i wire0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $NDEV -j MASQUERADE; iptables -A FORWARD -o %i -j ACCEPT"
        POSTDOWN_RULES="PostDown = iptables -D FORWARD -i wire0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $NDEV -j MASQUERADE; ip6tables -D FORWARD -i wire0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $NDEV -j MASQUERADE; iptables -D FORWARD -o %i -j ACCEPT"
        ;;

    4)
        # SITE GATEWAY AS A SPOKE:
        # ------------------------
        # ROUTE FROM EP1 OVER HUB TO SITE EP2
        # EP 1 ===> HUB ===> EP 2 ---> (NO WG CLIENTS)
        # 
        PREUP_RULES=""
        CPREUP_RULES=$(cat <<EOV
# IP forwarding
PreUp = sysctl -w net.ipv4.ip_forward=1
# IP masquerading
# iptables -t nat -A POSTROUTING -s ${IPADDR%.*}.0/24 -d 10.2.3.0/24 -j MASQUERADE
PreUp = iptables -t mangle -A PREROUTING -i $UCLIENT -j MARK --set-mark 0x30
PreUp = iptables -t nat -A POSTROUTING ! -o $UCLIENT -m mark --mark 0x30 -j MASQUERADE
EOV
)
        CPOSTDOW_RULES=$(cat <<EOV
PostDown = iptables -t mangle -D PREROUTING -i $UCLIENT -j MARK --set-mark 0x30
PostDown = iptables -t nat -D POSTROUTING ! -o $UCLIENT -m mark --mark 0x30 -j MASQUERADE
EOV
)
        ;;

    5)
        # HUB IS SITE GATEWAY WITH INET GW SPOKE:
        # ---------------------------------------------
        # ROUTE FROM EP1 OVER HUB /W SITEGW TO SITE EP2 WITH INET GW
        # EP 1 ===> HUB (---> (CLIENTS)) ===> EP 2 ---> (WWW)
        # 
        CPREUP_RULES=""
        SITEC=192.168.0.0/24
        PREUP_RULES=$(cat <<EOV
Table = 123

# IP forwarding
PreUp = sysctl -w net.ipv4.ip_forward=1
# default routing for incoming WireGuard packets
PreUp = ip rule add iif wire0 table 123 priority 456
# routing for packets sent from WireGuard network to Site C
PreUp = ip rule add to $SITEC table main priority 444
# routing for packets returning from Site C back to WireGuard network
PostUp = ip route add 10.0.0.0/24 dev wire0
# IP masquerading
PreUp = iptables -t mangle -A PREROUTING -i wire0 -j MARK --set-mark 0x30
PreUp = iptables -t nat -A POSTROUTING ! -o wire0 -m mark --mark 0x30 -j MASQUERADE
# IPv6 forwarding & routing
PreUp = sysctl -w net.ipv6.conf.all.forwarding=1
PreUp = ip -6 rule add iif wire0 table 123 priority 456
EOV
)
        POSTDOW_RULES=$(cat <<EOV
PostDown = ip rule del iif wire0 table 123 priority 456
PostDown = ip rule del to $SITEC table main priority 444
PostDown = iptables -t mangle -D PREROUTING -i wire0 -j MARK --set-mark 0x30
PostDown = iptables -t nat -D POSTROUTING ! -o wire0 -m mark --mark 0x30 -j MASQUERADE
# IPv6 forwarding & routing
PostDown = ip -6 rule del iif wire0 table 123 priority 456
EOV
)
        ;;
    *)  
        echo "[!!] Bad input, try again.."
        clear; return 0
        ;;
esac
return 1

}


_run_wg() {

    echo -e "\n[+] Starting Wireguard with VIP: $IPADDR ...\n"; sleep 2
    wg-quick up wire0
}


_stop_wg() {

    echo -e "\n[+] Stopping Wireguard with VIP: $IPADDR ...\n"; sleep 2
    wg-quick down wire0
}


_install_wg() {

    echo -e "\n[+] Update and install wireguard..:\n"; sleep 1

    apt update && apt autoremove -y && apt install curl -y
    
    apt install -y wireguard wireguard-tools || \
    echo "[~] Not working with repos .. try gitrepos.."; \
    wget https://git.io/wireguard -O wireguard-install.sh && bash wireguard-install.sh
}


_uninstall_wg() {

    echo -e "\n[+] Remove wireguard..:\n"; sleep 1
    
    apt purge wireguard wireguard-tools && \
    rm -rf /etc/wireguard/
}


_setup_udptunnel() {

    PSKKEY=$(wg genpsk)

    # Install necesseary tools
    if [ ! -f /usr/bin/udp2raw ]; then
        echo -e "\n[*] Installing missing udp2raw and speeder files..:\n"

        curl -sSL https://github.com/wangyu-/udp2raw/releases/download/20230206.0/udp2raw_binaries.tar.gz | \
        tar -xzv -C /usr/bin/ udp2raw_amd64 && \
        mv /usr/bin/udp2raw_amd64 /usr/bin/udp2raw && \
        chmod +x /usr/bin/udp2raw
    fi

    if [ ! -f /usr/bin/speederv2 ]; then
        curl -sSL https://github.com/wangyu-/UDPspeeder/releases/download/20230206.0/speederv2_binaries.tar.gz | \
        tar -xzv -C /usr/bin/ speederv2_amd64 && \
        mv /usr/bin/speederv2_amd64 /usr/bin/speederv2 && \
        chmod +x /usr/bin/speederv2
    fi

    if [ $1 -gt 0 ]; then
        echo -e "\n[+] Creating UDPTunnel for clientside:\n"

        #wireguard_client-->udpspeeder_client L:50001-->udp2raw_client L:50002---(WWW)--->udp2raw_server 0:51822-->udpspeeder_server 0:51821 -->wireguard_server L:51820
        #

        echo; read -p "[?] Please enter your IPS Provider IP: " IP_IN ;echo
        echo; read -p "[?] Please enter your IPS Provider Port: " PORT_I ;echo

        echo -e "\n[+] Starting UDPTunnel for clientside:\n"
        udp2raw -c -l 0.0.0.0:50001 -r $IP_IN:$PORT_I -k $PSKKEY -a >/var/log/udp2raw.log 2>&1 &
        speederv2 -c -l 0.0.0.0:51821 -r 127.0.0.1:50001 -f20:20 --timeout 8 >/var/log/udp2speeder.log 2>&1 &
        echo -e "\n[!!] You can stop processes with: ( killall udp2raw speederv2 ) \n"; sleep 1

    else
        echo -e "\n[+] Creating UDPTunnel for serverside:\n"

        #MTU = 1280
        udp2raw -s -l 0.0.0.0:51822 -r 127.0.0.1:51821 -k $PSKKEY -a >/var/log/udp2raw.log 2>&1 &
        speederv2 -s -l 0.0.0.0:51821 -r 127.0.0.1:51820 -f20:20 --timeout 8 >/var/log/speederv2.log 2>&1 &
        echo -e "\n[!!] You can stop processes with: ( killall udp2raw speederv2 ) \n"; sleep 1
    fi

    #DEBUG
    echo; read -p "[?] Start Debugging? [Y/N] " YN ;echo
    [ "$YN" == "N" ] && exit 0;
    tail -f /var/log/{udp2raw,speederv*}.log

}


_run_tinyfecvpn() {

    PSKKEY=$(wg genpsk)
    PIP=10.10.10.1
    #Parameter Expansion:
    # /24
    PIP_SUB=${PIP%.*}.0
    # /16
    #PIP2=${PIP%.*.*}.0.0

    # Install necesseary tools
    if [ ! -f /usr/bin/tinyvpn ]; then
        echo -e "\n[*] Installing missing tinyfecvpn files..:\n"

        curl -sSL https://github.com/wangyu-/tinyfecVPN/releases/download/20230206.0/tinyvpn_binaries.tar.gz | \
        tar -xzv -C /usr/bin/ tinyvpn_amd64 && \
        mv /usr/bin/tinyvpn_amd64 /usr/bin/tinyvpn && \
        chmod +x /usr/bin/tinyvpn
    fi

    echo -e "\n[*] Creating tinyvpn for serverside:\n"
    echo; read -p "[?] Continue, your on server? [Y/N] " YN ;echo
    [ "$YN" == "N" ] && exit 0;

    #enable ip forward and Iptables:
    echo 1 >/proc/sys/net/ipv4/ip_forward
    iptables -t nat -A POSTROUTING -s $PIP/16 ! -d $PIP/16 -j MASQUERADE

    #run tinyfecVPN server
    tinyvpn -s -l 0.0.0.0:51820 --sub-net $PIP_SUB --tun-dev tun100 --report 10 -k $PSKKEY >/var/log/tinyfecvpn.log 2>&1 &

    if [ "$1" == "--tcp-mode" ]; then
        echo -e "\n[*] Starting TCPMode with udp2raw:\n"

        # Install necesseary tools
        if [ ! -f /usr/bin/udp2raw ]; then
            echo -e "\n[*] Installing missing udp2raw and speeder files..:\n"

            curl -sSL https://github.com/wangyu-/udp2raw/releases/download/20230206.0/udp2raw_binaries.tar.gz | \
            tar -xzv -C /usr/bin/ udp2raw_amd64 && \
            mv /usr/bin/udp2raw_amd64 /usr/bin/udp2raw && \
            chmod +x /usr/bin/udp2raw
        fi

        udp2raw -s -l 0.0.0.0:51822 -r 127.0.0.1:51820 -k $PSKKEY -a >/var/log/udp2raw.log 2>&1 &
    fi



    echo -e "\n\n[*] Creating tinyvpn for clientside:\n"; sleep 2

    echo "run tinyFecVPN client:"
    echo "----------------------"

    if [ "$1" == "--tcp-mode" ]; then
        echo "udp2raw -c -l 0.0.0.0:50001 -r $IPEXT:$PORTEXT -k $PSKKEY -a >/var/log/udp2raw.log 2>&1 &"
        echo "tinyvpn -c -r 127.0.0.1:50001 --sub-net $PIP_SUB --tun-dev tun100 --keep-reconnect --report 10 -k $PSKKEY >/var/log/tinyfecvpn.log 2>&1 &" 
    else
        echo "tinyvpn -c -r $IPEXT:51822 --sub-net $PIP_SUB --tun-dev tun100 --keep-reconnect --report 10 -k $PSKKEY >/var/log/tinyfecvpn.log 2>&1 &"
    fi
    
    echo
    echo "[+] add rules: Route all"
    echo "------------------------"
    echo "ip route add $IPEXT/32 via 192.168.xx.1"
    echo "ip route add 0.0.0.0/1 via $PIP dev tun100"
    echo "ip route add 128.0.0.0/1 via $PIP dev tun100"
    echo; sleep 2

    #DEBUG
    echo; read -p "[?] Start Debugging? [Y/N] " YN ;echo
    [ "$YN" == "N" ] && exit 0;
    tail -f /var/log/{udp2raw,tiny*}.log

}


#
# MAIN 
#
if [ "$1" == "server" ] && [ "$2" == "--add-config" ]; then
    _server_conf
elif [ "$1" == "client" ] && [ "$2" == "--add-config" ]; then
    _client_conf
elif [ "$1" == "server" ] && [ "$2" == "--udp-tcp-tunnel" ]; then
    _setup_udptunnel 0
elif [ "$1" == "client" ] && [ "$2" == "--udp-tcp-tunnel" ]; then
    _setup_udptunnel 1
elif [ "$1" == "--run-tinyvpn" ]; then
    _run_tinyfecvpn $2
elif [ "$1" == "--install-wg" ]; then
    _install_wg
elif [ "$1" == "--run-wg" ]; then
    _run_wg
elif [ "$1" == "--remove-wg" ]; then
    _uninstall_wg
elif [ "$1" == "--stop-wg" ]; then
    _stop_wg
else
    echo -e "\nError no Input. 

    Usage: $0 [Command] [Options] 
    Wireguard admin and peer creator v0.2a (c) suuhm 2023

    Commands:

        server [--add-config] [--udp-tcp-tunnel] [--start-wg]
        client [--add-config] [--udp-tcp-tunnel] [--start-wg]

    Options:

        --run-tinyvpn [--tcp-mode]
        --install-wg
        --run-wg
        --remove-wg
        --stop-wg
        --version
        --help

    \n"
    
    exit 1
fi


exit 0
