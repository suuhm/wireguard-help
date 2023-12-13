![wg-help_logo](https://github.com/suuhm/wireguard-help/assets/11504990/047ca3f0-8437-4b76-aa0f-7c33eee1c2cd)


WireGuard helper script for building complex topologies (HUB/SPOKES) and using WireGuard with TCP stack

## Features

- Installing / Deinstalling of wireguard on linux based os
- Adding complex topologies like described in this article [Multi-Hop WireGuard](https://www.procustodibus.com/blog/2022/06/multi-hop-wireguard/#internet-gateway-as-a-spoke)
- Adding simply client P2P configs
- Using wg UDP traffic though TCP thanks to udp2raw tunneling
- Speedup traffic with speederv2
- Using alternative VPN with tinyFECvpn
- Run/Stop scripts
- Windows Client helper batchfiles inkluded.
  

## How to use

1. Clone the script via
```bash
git clone https://github.com/suuhm/wireguard-help && cd wireguard-help
chmod +x wireguard-help.sh
```

2. Run Script:
```bash
  ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
  ▒▒▒                                                       ▒▒▒
  ▒▒▒            W I R E G U A R D - H E L P                ▒▒▒
   ▒   ===================================================   ▒ 
   ▒  Wireguard admin and peer creator v0.2a (c) suuhm 2023  ▒ 
   ▒                                                         ▒ 
   ▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ 

Error no Input. 

    Usage: ./wireguard-help.sh [Command] [Options] 
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
```

## Examples

Installing wireguard on your system

```bash
./wireguard-help.sh --install-wg
```

Set up your wg hub/server

```bash
./wireguard-help.sh server --add-config
```

Set up first client peer

```bash
./wireguard-help.sh client --add-config
```

Set up UDP2RAW socket for using TCP on server and clientside

```bash
./wireguard-help.sh server --udp-tcp-tunnel
# On client pc
./wireguard-help.sh client --udp-tcp-tunnel

## When using Windows as client:
# Use the wg_help_udp2raw.bat and optional wg_help_speederv2.bat
```



## Connecting wireguard with wg-help-win.bat

You need to install first the windows version and run the batch file as Admin on Windows:


![wg-help-win](https://github.com/suuhm/wireguard-help/assets/11504990/b929e3c3-3d8e-44dc-9774-bb61ae0064a3)



## All rights reserved 2023 (c) suuhm



## Let me know if you find some bugs and feature wishes and post an issue!
