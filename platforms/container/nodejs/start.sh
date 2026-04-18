#!/bin/sh
export LANG=en_US.UTF-8
export uuid=${uuid}
export vlpt=${vlpt}
export vmpt=${vmpt}
export vwpt=${vwpt}
export hypt=${hypt}
export tupt=${tupt}
export xhpt=${xhpt}
export vxpt=${vxpt}
export anpt=${anpt}
export arpt=${arpt}
export sspt=${sspt}
export sopt=${sopt}
export reym=${reym}
export cdnym=${cdnym}
export ippz=${ippz}
export name=${name}
v46url="https://icanhazip.com"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
echo "SingulariX 一键部署脚本"
echo "当前版本：V26.04.19"
echo "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
hostname=$(uname -a | awk '{print $2}')
op=$(cat /etc/redhat-release 2>/dev/null || cat /etc/os-release 2>/dev/null | grep -i pretty_name | cut -d \" -f2)
[ -z "$(systemd-detect-virt 2>/dev/null)" ] && vi=$(virt-what 2>/dev/null) || vi=$(systemd-detect-virt 2>/dev/null)
case $(uname -m) in
aarch64) cpu=arm64;;
x86_64) cpu=amd64;;
*) echo "目前脚本不支持$(uname -m)架构" && exit
esac

if [ "$(id -u)" -ne 0 ]; then
echo "错误：仅支持 root 用户安装与管理，请先执行 sudo -i 后重试。"
exit 1
fi

mkdir -p "$HOME/sgx"

for logfile in "$HOME/sgx/xr.log" "$HOME/sgx/sb.log"; do
if [ -f "$logfile" ] && [ "$(wc -c < "$logfile")" -gt 1048576 ]; then
tail -c 102400 "$logfile" > "$logfile.tmp" && mv "$logfile.tmp" "$logfile"
fi
done

load_saved_var(){
key="$1"
eval "cur=\${$key:-}"
if [ -n "$cur" ]; then
return
fi
f="$HOME/sgx/$key"
if [ -s "$f" ]; then
val=$(cat "$f")
eval "$key=\$val"
export "$key"
fi
}

# When rerunning without env vars, recover previously saved protocol ports/options.
for key in vlpt vmpt vwpt hypt tupt xhpt vxpt anpt arpt sspt sopt reym cdnym ippz name uuid; do
load_saved_var "$key"
done

v4v6(){
v4=$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 --tries=2 -qO- "$v46url" 2>/dev/null) )
v6=$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 --tries=2 -qO- "$v46url" 2>/dev/null) )
v4dq=$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k https://ip.fm | sed -E 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/' 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 --tries=2 -qO- https://ip.fm | grep '<span class="has-text-grey-light">Location:' | tail -n1 | sed -E 's/.*>Location: <\/span>([^<]+)<.*/\1/' 2>/dev/null) )
v6dq=$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k https://ip.fm | sed -E 's/.*Location: ([^,]+(, [^,]+)*),.*/\1/' 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 --tries=2 -qO- https://ip.fm | grep '<span class="has-text-grey-light">Location:' | tail -n1 | sed -E 's/.*>Location: <\/span>([^<]+)<.*/\1/' 2>/dev/null) )
}
sync_port_file(){
port_value="$1"
port_key="$2"
port_file="$HOME/sgx/$port_key"

if [ -z "$port_value" ] && [ ! -e "$port_file" ]; then
port_value=$(shuf -i 10000-65535 -n 1)
echo "$port_value" > "$port_file"
elif [ -n "$port_value" ]; then
echo "$port_value" > "$port_file"
fi

if [ -e "$port_file" ]; then
cat "$port_file"
else
echo "$port_value"
fi
}
sync_cdn_domain(){
if [ -n "$cdnym" ]; then
echo "$cdnym" > "$HOME/sgx/cdnym"
echo "80系CDN或者回源CDN的host域名 (确保IP已解析在CF域名)：$cdnym"
fi
}

download_asset(){
url="$1"
out="$2"
if command -v curl >/dev/null 2>&1; then
curl -fsSL --http1.1 --retry 2 --connect-timeout 10 "$url" -o "$out"
return $?
fi
if command -v wget >/dev/null 2>&1; then
wget -qO "$out" "$url"
return $?
fi
return 127
}

binary_ok(){
bin="$1"
shift
"$bin" "$@" >/dev/null 2>&1
}
sgx_core_running(){
if find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null | grep -Eq 'sgx/(sing-box|xray)'; then
return 0
fi
pgrep -f 'sgx/(sing-box|xray)' >/dev/null 2>&1
}
insuuid(){
if [ -z "$uuid" ] && [ ! -e "$HOME/sgx/uuid" ]; then
if [ -x "$HOME/sgx/sing-box" ] && binary_ok "$HOME/sgx/sing-box" version; then
uuid=$("$HOME/sgx/sing-box" generate uuid 2>/dev/null || true)
fi
if [ -z "$uuid" ] && [ -x "$HOME/sgx/xray" ] && binary_ok "$HOME/sgx/xray" version; then
uuid=$("$HOME/sgx/xray" uuid 2>/dev/null || true)
fi
if [ -z "$uuid" ] && [ -r /proc/sys/kernel/random/uuid ]; then
uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || true)
fi
[ -n "$uuid" ] || { echo "生成 UUID 失败，安装终止。"; exit 1; }
echo "$uuid" > "$HOME/sgx/uuid"
elif [ -n "$uuid" ]; then
echo "$uuid" > "$HOME/sgx/uuid"
fi
uuid=$(cat "$HOME/sgx/uuid")
echo "UUID密码：$uuid"
}
installxray(){
echo
echo "=========启用xray内核========="
mkdir -p "$HOME/sgx/xrk"
if [ ! -e "$HOME/sgx/xray" ]; then
[ "$cpu" = "amd64" ] && xarch="64" || xarch="arm64-v8a"
url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-$xarch.zip"; out="$HOME/sgx/xray.zip"
download_asset "$url" "$out" || { echo "下载 Xray 失败，请稍后重试。"; exit 1; }
if ! command -v unzip >/dev/null 2>&1 && ! command -v bsdtar >/dev/null 2>&1; then
if command -v apt >/dev/null 2>&1; then
apt update >/dev/null 2>&1 && apt install -y unzip >/dev/null 2>&1
elif command -v apk >/dev/null 2>&1; then
apk add --no-cache unzip >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
yum install -y unzip >/dev/null 2>&1
fi
fi
if command -v unzip >/dev/null 2>&1; then
unzip -o "$out" xray -d "$HOME/sgx" >/dev/null 2>&1
elif command -v bsdtar >/dev/null 2>&1; then
bsdtar -xf "$out" -C "$HOME/sgx" xray >/dev/null 2>&1
else
echo "缺少 unzip/bsdtar，无法解压 Xray，请先安装 unzip" && exit 1
fi
rm -f "$out"
chmod +x "$HOME/sgx/xray"
binary_ok "$HOME/sgx/xray" version || { echo "Xray 内核执行失败（可能下载损坏或架构不兼容），安装终止。"; exit 1; }
sbcore=$("$HOME/sgx/xray" version 2>/dev/null | awk '/^Xray/{print $2}' | head -n1)
echo "已安装Xray正式版内核：$sbcore"
fi
cat > "$HOME/sgx/xr.json" <<EOF
{
  "log": {
  "loglevel": "none"
  },
  "dns": {
    "servers": [
      "${xsdns}"
      ]
   },
  "inbounds": [
EOF
insuuid
if [ -n "$xhpt" ] || [ -n "$vlpt" ]; then
if [ -z "$reym" ]; then
reym=apple.com
fi
echo "$reym" > "$HOME/sgx/reym"
echo "Reality域名：$reym"
if [ ! -e "$HOME/sgx/xrk/private_key" ]; then
key_pair=$("$HOME/sgx/xray" x25519)
private_key=$(echo "$key_pair" | grep "PrivateKey" | awk '{print $2}')
public_key=$(echo "$key_pair" | grep "Password" | awk '{print $2}')
short_id=$(date +%s%N | sha256sum | cut -c 1-8)
echo "$private_key" > "$HOME/sgx/xrk/private_key"
echo "$public_key" > "$HOME/sgx/xrk/public_key"
echo "$short_id" > "$HOME/sgx/xrk/short_id"
fi
private_key_x=$(cat "$HOME/sgx/xrk/private_key")
public_key_x=$(cat "$HOME/sgx/xrk/public_key")
short_id_x=$(cat "$HOME/sgx/xrk/short_id")
fi
if [ -n "$xhpt" ] || [ -n "$vxpt" ] || [ -n "$vwpt" ]; then
if [ ! -e "$HOME/sgx/xrk/dekey" ]; then
vlkey=$("$HOME/sgx/xray" vlessenc)
dekey=$(echo "$vlkey" | grep '"decryption":' | sed -n '2p' | cut -d' ' -f2- | tr -d '"')
enkey=$(echo "$vlkey" | grep '"encryption":' | sed -n '2p' | cut -d' ' -f2- | tr -d '"')
echo "$dekey" > "$HOME/sgx/xrk/dekey"
echo "$enkey" > "$HOME/sgx/xrk/enkey"
fi
dekey=$(cat "$HOME/sgx/xrk/dekey")
enkey=$(cat "$HOME/sgx/xrk/enkey")
fi

if [ -n "$xhpt" ]; then
xhpt=$(sync_port_file "$xhpt" "xhpt")
echo "Vless-xhttp-reality-v端口：$xhpt"
cat >> "$HOME/sgx/xr.json" <<EOF
    {
      "tag":"xhttp-reality",
      "listen": "::",
      "port": ${xhpt},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "${dekey}"
      },
      "streamSettings": {
        "network": "xhttp",
        "security": "reality",
        "realitySettings": {
          "fingerprint": "chrome",
          "target": "${reym}:443",
          "serverNames": [
            "${reym}"
          ],
          "privateKey": "$private_key_x",
          "shortIds": ["$short_id_x"]
        },
        "xhttpSettings": {
          "host": "",
          "path": "${uuid}-xh",
          "mode": "auto"
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
fi
if [ -n "$vxpt" ]; then
vxpt=$(sync_port_file "$vxpt" "vxpt")
echo "Vless-xhttp-enc端口：$vxpt"
sync_cdn_domain
cat >> "$HOME/sgx/xr.json" <<EOF
    {
      "tag":"vless-xhttp",
      "listen": "::",
      "port": ${vxpt},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "${dekey}"
      },
      "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
          "host": "",
          "path": "${uuid}-vx",
          "mode": "auto"
        }
      },
        "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
fi
if [ -n "$vwpt" ]; then
vwpt=$(sync_port_file "$vwpt" "vwpt")
echo "Vless-ws-enc端口：$vwpt"
sync_cdn_domain
cat >> "$HOME/sgx/xr.json" <<EOF
    {
      "tag":"vless-ws",
      "listen": "::",
      "port": ${vwpt},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "${dekey}"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${uuid}-vw"
        }
      },
        "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls", "quic"],
        "metadataOnly": false
      }
    },
EOF
fi
if [ -n "$vlpt" ]; then
vlpt=$(sync_port_file "$vlpt" "vlpt")
echo "Vless-tcp-reality-v端口：$vlpt"
cat >> "$HOME/sgx/xr.json" <<EOF
        {
            "tag":"reality-vision",
            "listen": "::",
            "port": $vlpt,
            "protocol": "vless",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}",
                        "flow": "xtls-rprx-vision"
                    }
                ],
                "decryption": "none"
            },
            "streamSettings": {
                "network": "tcp",
                "security": "reality",
                "realitySettings": {
                    "fingerprint": "chrome",
                    "dest": "${reym}:443",
                    "serverNames": [
                      "${reym}"
                    ],
                    "privateKey": "$private_key_x",
                    "shortIds": ["$short_id_x"]
                }
            },
          "sniffing": {
          "enabled": true,
          "destOverride": ["http", "tls", "quic"],
          "metadataOnly": false
      }
    },  
EOF
fi
}

installsb(){
echo
echo "=========启用Sing-box内核========="
if [ ! -e "$HOME/sgx/sing-box" ]; then
sver=$( (command -v curl >/dev/null 2>&1 && curl -s https://api.github.com/repos/SagerNet/sing-box/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' | head -n1) || (command -v wget >/dev/null 2>&1 && wget -qO- https://api.github.com/repos/SagerNet/sing-box/releases/latest | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p' | head -n1) )
[ -z "$sver" ] && sver="1.11.1"
url="https://github.com/SagerNet/sing-box/releases/download/v$sver/sing-box-$sver-linux-$cpu.tar.gz"; out="$HOME/sgx/sing-box.tar.gz"
download_asset "$url" "$out" || { echo "下载 Sing-box 失败，请稍后重试。"; exit 1; }
tar -xzf "$out" -C "$HOME/sgx" --strip-components=1 "sing-box-$sver-linux-$cpu/sing-box" >/dev/null 2>&1 || { echo "解压 Sing-box 失败，安装终止。"; rm -f "$out"; exit 1; }
rm -f "$out"
chmod +x "$HOME/sgx/sing-box"
fi
binary_ok "$HOME/sgx/sing-box" version || { echo "Sing-box 内核执行失败（可能下载损坏或架构不兼容），安装终止。"; rm -f "$HOME/sgx/sing-box"; exit 1; }
sbcore=$("$HOME/sgx/sing-box" version 2>/dev/null | awk '/version/{print $NF}' | head -n1)
echo "已安装Sing-box正式版内核：$sbcore"
cat > "$HOME/sgx/sb.json" <<EOF
{
"log": {
    "disabled": false,
    "level": "info",
    "timestamp": true
  },
  "inbounds": [
EOF
insuuid
command -v openssl >/dev/null 2>&1 && openssl ecparam -genkey -name prime256v1 -out "$HOME/sgx/private.key" >/dev/null 2>&1
command -v openssl >/dev/null 2>&1 && openssl req -new -x509 -days 36500 -key "$HOME/sgx/private.key" -out "$HOME/sgx/cert.pem" -subj "/CN=www.bing.com" >/dev/null 2>&1
if [ ! -f "$HOME/sgx/private.key" ]; then
if [ "$(id -u)" -eq 0 ]; then
if command -v apk >/dev/null 2>&1; then
apk add --no-cache openssl >/dev/null 2>&1 || true
elif command -v apt >/dev/null 2>&1; then
apt update >/dev/null 2>&1 && apt install -y openssl >/dev/null 2>&1 || true
fi
fi
if command -v openssl >/dev/null 2>&1; then
openssl ecparam -genkey -name prime256v1 -out "$HOME/sgx/private.key" >/dev/null 2>&1
openssl req -new -x509 -days 36500 -key "$HOME/sgx/private.key" -out "$HOME/sgx/cert.pem" -subj "/CN=www.bing.com" >/dev/null 2>&1
fi
if [ ! -f "$HOME/sgx/private.key" ]; then
echo "缺少证书文件且无法生成，请安装 openssl 后重试。" && exit 1
fi
fi
if [ -n "$hypt" ]; then
hypt=$(sync_port_file "$hypt" "hypt")
echo "Hysteria2端口：$hypt"
cat >> "$HOME/sgx/sb.json" <<EOF
    {
        "type": "hysteria2",
        "tag": "hy2-sb",
        "listen": "::",
        "listen_port": ${hypt},
        "users": [
            {
                "password": "${uuid}"
            }
        ],
        "ignore_client_bandwidth":false,
        "tls": {
            "enabled": true,
            "alpn": [
                "h3"
            ],
            "certificate_path": "$HOME/sgx/cert.pem",
            "key_path": "$HOME/sgx/private.key"
        }
    },
EOF
fi
if [ -n "$tupt" ]; then
tupt=$(sync_port_file "$tupt" "tupt")
echo "Tuic端口：$tupt"
cat >> "$HOME/sgx/sb.json" <<EOF
        {
            "type":"tuic",
            "tag": "tuic5-sb",
            "listen": "::",
            "listen_port": ${tupt},
            "users": [
                {
                    "uuid": "${uuid}",
                    "password": "${uuid}"
                }
            ],
            "congestion_control": "bbr",
            "tls":{
                "enabled": true,
                "alpn": [
                    "h3"
                ],
                "certificate_path": "$HOME/sgx/cert.pem",
                "key_path": "$HOME/sgx/private.key"
            }
        },
EOF
fi
if [ -n "$anpt" ]; then
anpt=$(sync_port_file "$anpt" "anpt")
echo "Anytls端口：$anpt"
cat >> "$HOME/sgx/sb.json" <<EOF
        {
            "type":"anytls",
            "tag":"anytls-sb",
            "listen":"::",
            "listen_port":${anpt},
            "users":[
                {
                  "password":"${uuid}"
                }
            ],
            "padding_scheme":[],
            "tls":{
                "enabled": true,
                "certificate_path": "$HOME/sgx/cert.pem",
                "key_path": "$HOME/sgx/private.key"
            }
        },
EOF
fi
if [ -n "$arpt" ]; then
if [ -z "$reym" ]; then
reym=apple.com
fi
echo "$reym" > "$HOME/sgx/reym"
echo "Reality域名：$reym"
mkdir -p "$HOME/sgx/sbk"
if [ ! -e "$HOME/sgx/sbk/private_key" ]; then
key_pair=$("$HOME/sgx/sing-box" generate reality-keypair)
private_key=$(echo "$key_pair" | awk '/PrivateKey/ {print $2}' | tr -d '"')
public_key=$(echo "$key_pair" | awk '/PublicKey/ {print $2}' | tr -d '"')
short_id=$("$HOME/sgx/sing-box" generate rand --hex 4)
echo "$private_key" > "$HOME/sgx/sbk/private_key"
echo "$public_key" > "$HOME/sgx/sbk/public_key"
echo "$short_id" > "$HOME/sgx/sbk/short_id"
fi
private_key_s=$(cat "$HOME/sgx/sbk/private_key")
public_key_s=$(cat "$HOME/sgx/sbk/public_key")
short_id_s=$(cat "$HOME/sgx/sbk/short_id")
arpt=$(sync_port_file "$arpt" "arpt")
echo "Any-Reality端口：$arpt"
cat >> "$HOME/sgx/sb.json" <<EOF
        {
            "type":"anytls",
            "tag":"anyreality-sb",
            "listen":"::",
            "listen_port":${arpt},
            "users":[
                {
                  "password":"${uuid}"
                }
            ],
            "padding_scheme":[],
            "tls": {
            "enabled": true,
            "server_name": "${reym}",
             "reality": {
              "enabled": true,
              "handshake": {
              "server": "${reym}",
              "server_port": 443
             },
             "private_key": "$private_key_s",
             "short_id": ["$short_id_s"]
            }
          }
        },
EOF
fi
if [ -n "$sspt" ]; then
if [ ! -e "$HOME/sgx/sskey" ]; then
sskey=$("$HOME/sgx/sing-box" generate rand 16 --base64)
echo "$sskey" > "$HOME/sgx/sskey"
fi
sspt=$(sync_port_file "$sspt" "sspt")
sskey=$(cat "$HOME/sgx/sskey")
echo "Shadowsocks-2022端口：$sspt"
cat >> "$HOME/sgx/sb.json" <<EOF
        {
            "type": "shadowsocks",
            "tag":"ss-2022",
            "listen": "::",
            "listen_port": $sspt,
            "method": "2022-blake3-aes-128-gcm",
            "password": "$sskey"
    },  
EOF
fi
}

xrsbvm(){
if [ -n "$vmpt" ]; then
vmpt=$(sync_port_file "$vmpt" "vmpt")
echo "Vmess-ws端口：$vmpt"
sync_cdn_domain
if [ -e "$HOME/sgx/xr.json" ]; then
cat >> "$HOME/sgx/xr.json" <<EOF
        {
            "tag": "vmess-xr",
            "listen": "::",
            "port": ${vmpt},
            "protocol": "vmess",
            "settings": {
                "clients": [
                    {
                        "id": "${uuid}"
                    }
                ]
            },
            "streamSettings": {
                "network": "ws",
                "security": "none",
                "wsSettings": {
                  "path": "${uuid}-vm"
            }
        },
            "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls", "quic"],
            "metadataOnly": false
            }
         }, 
EOF
else
cat >> "$HOME/sgx/sb.json" <<EOF
{
        "type": "vmess",
        "tag": "vmess-sb",
        "listen": "::",
        "listen_port": ${vmpt},
        "users": [
            {
                "uuid": "${uuid}",
                "alterId": 0
            }
        ],
        "transport": {
            "type": "ws",
            "path": "${uuid}-vm",
            "max_early_data":2048,
            "early_data_header_name": "Sec-WebSocket-Protocol"
        }
    },
EOF
fi
fi
}

xrsbso(){
if [ -n "$sopt" ]; then
sopt=$(sync_port_file "$sopt" "sopt")
echo "Socks5端口：$sopt"
if [ -e "$HOME/sgx/xr.json" ]; then
cat >> "$HOME/sgx/xr.json" <<EOF
        {
         "tag": "socks5-xr",
         "port": ${sopt},
         "listen": "::",
         "protocol": "socks",
         "settings": {
            "auth": "password",
             "accounts": [
               {
               "user": "${uuid}",
               "pass": "${uuid}"
               }
            ],
            "udp": true
          },
            "sniffing": {
            "enabled": true,
            "destOverride": ["http", "tls", "quic"],
            "metadataOnly": false
            }
         }, 
EOF
else
cat >> "$HOME/sgx/sb.json" <<EOF
    {
      "tag": "socks5-sb",
      "type": "socks",
      "listen": "::",
      "listen_port": ${sopt},
      "users": [
      {
      "username": "${uuid}",
      "password": "${uuid}"
      }
     ]
    },
EOF
fi
fi
}

xrsbout(){
if [ -e "$HOME/sgx/xr.json" ]; then
sed -i '${s/,\s*$//}' "$HOME/sgx/xr.json"
cat >> "$HOME/sgx/xr.json" <<EOF
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {
        "domainStrategy":"${xryx}"
      }
    }
  ],
  "routing": {
    "domainStrategy": "IPOnDemand",
    "rules": [
      {
        "type": "field",
        "network": "tcp,udp",
        "outboundTag": "direct"
      }
    ]
  }
}
EOF
nohup "$HOME/sgx/xray" run -c "$HOME/sgx/xr.json" >> "$HOME/sgx/xr.log" 2>&1 &
fi
if [ -e "$HOME/sgx/sb.json" ]; then
sed -i '${s/,\s*$//}' "$HOME/sgx/sb.json"
cat >> "$HOME/sgx/sb.json" <<EOF
  ],
  "outbounds": [
    {
      "type": "direct",
      "tag": "direct"
    }
  ],
  "route": {
    "rules": [
      {
        "action": "sniff"
      },
      {
        "action": "resolve",
        "strategy": "${sbyx}"
      }
    ],
    "final": "direct"
  },
  "dns": {
    "servers": [
      {
        "type": "https",
        "server": "${xsdns}"
      }
    ],
    "strategy": "${sbdnsyx}"
  }
}
EOF
nohup "$HOME/sgx/sing-box" run -c "$HOME/sgx/sb.json" >> "$HOME/sgx/sb.log" 2>&1 &
fi
}
ins(){
if [ -n "$name" ]; then
sxname=$name-
echo "$sxname" > "$HOME/sgx/name"
echo
echo "所有节点名称前缀：$name"
fi
if [ -z "$hypt" ] && [ -z "$tupt" ] && [ -z "$anpt" ] && [ -z "$arpt" ] && [ -z "$sspt" ]; then
installxray
xrsbvm
xrsbso
xrsbout
elif [ -z "$xhpt" ] && [ -z "$vlpt" ] && [ -z "$vxpt" ] && [ -z "$vwpt" ]; then
installsb
xrsbvm
xrsbso
xrsbout
else
installsb
installxray
xrsbvm
xrsbso
xrsbout
fi
}
singularix_status(){
echo "=========当前内核运行状态========="
procs=$(find /proc/*/exe -type l 2>/dev/null | grep -E '/proc/[0-9]+/exe' | xargs -r readlink 2>/dev/null)
if echo "$procs" | grep -Eq 'sgx/sing-box' || pgrep -f 'sgx/sing-box' >/dev/null 2>&1; then
echo "Sing-box：运行中"
else
echo "Sing-box：未启用"
fi
if echo "$procs" | grep -Eq 'sgx/xray' || pgrep -f 'sgx/xray' >/dev/null 2>&1; then
echo "Xray：运行中"
else
echo "Xray：未启用"
fi
}
cip(){
ipbest(){
serip=$( (command -v curl >/dev/null 2>&1 && (curl -s4m5 -k "$v46url" 2>/dev/null || curl -s6m5 -k "$v46url" 2>/dev/null) ) || (command -v wget >/dev/null 2>&1 && (timeout 3 wget -4 -qO- --tries=2 "$v46url" 2>/dev/null || timeout 3 wget -6 -qO- --tries=2 "$v46url" 2>/dev/null) ) )
if echo "$serip" | grep -q ':'; then
server_ip="[$serip]"
echo "$server_ip" > "$HOME/sgx/server_ip.log"
else
server_ip="$serip"
echo "$server_ip" > "$HOME/sgx/server_ip.log"
fi
}
ipchange(){
v4v6
if [ -z "$v4" ]; then
vps_ipv4='无IPV4'
vps_ipv6="$v6"
location="$v6dq"
elif [ -n "$v4" ] && [ -n "$v6" ]; then
vps_ipv4="$v4"
vps_ipv6="$v6"
location="$v4dq"
else
vps_ipv4="$v4"
vps_ipv6='无IPV6'
location="$v4dq"
fi
sleep 1
if [ "$ippz" = "4" ]; then
if [ -z "$v4" ]; then
ipbest
else
server_ip="$v4"
echo "$server_ip" > "$HOME/sgx/server_ip.log"
fi
elif [ "$ippz" = "6" ]; then
if [ -z "$v6" ]; then
ipbest
else
server_ip="[$v6]"
echo "$server_ip" > "$HOME/sgx/server_ip.log"
fi
else
ipbest
fi
}
ipchange
rm -rf "$HOME/sgx/jh.txt"
uuid=$(cat "$HOME/sgx/uuid")
server_ip=$(cat "$HOME/sgx/server_ip.log")
sxname=$(cat "$HOME/sgx/name" 2>/dev/null)
xvvmcdnym=$(cat "$HOME/sgx/cdnym" 2>/dev/null)
echo "*********************************************************"
echo "*********************************************************"
echo "SingulariX 输出节点配置如下："
echo
reym=$(cat "$HOME/sgx/reym" 2>/dev/null)
cfip() { echo $((RANDOM % 13 + 1)); }
if [ -e "$HOME/sgx/xray" ]; then
private_key_x=$(cat "$HOME/sgx/xrk/private_key" 2>/dev/null)
public_key_x=$(cat "$HOME/sgx/xrk/public_key" 2>/dev/null)
short_id_x=$(cat "$HOME/sgx/xrk/short_id" 2>/dev/null)
enkey=$(cat "$HOME/sgx/xrk/enkey" 2>/dev/null)
fi
if [ -e "$HOME/sgx/sing-box" ]; then
private_key_s=$(cat "$HOME/sgx/sbk/private_key" 2>/dev/null)
public_key_s=$(cat "$HOME/sgx/sbk/public_key" 2>/dev/null)
short_id_s=$(cat "$HOME/sgx/sbk/short_id" 2>/dev/null)
sskey=$(cat "$HOME/sgx/sskey" 2>/dev/null)
fi
if grep xhttp-reality "$HOME/sgx/xr.json" >/dev/null 2>&1; then
echo "💣【 Vless-xhttp-reality-enc 】支持ENC加密，节点信息如下："
xhpt=$(cat "$HOME/sgx/xhpt")
vl_xh_link="vless://$uuid@$server_ip:$xhpt?encryption=$enkey&flow=xtls-rprx-vision&security=reality&sni=$reym&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=xhttp&path=$uuid-xh&mode=auto#${sxname}vl-xhttp-reality-$hostname"
echo "$vl_xh_link" >> "$HOME/sgx/jh.txt"
echo "$vl_xh_link"
echo
fi
if grep vless-xhttp "$HOME/sgx/xr.json" >/dev/null 2>&1; then
echo "💣【 Vless-xhttp-enc 】支持ENC加密，节点信息如下："
vl_vx_link="vless://$uuid@$server_ip:$vxpt?encryption=$enkey&flow=xtls-rprx-vision&type=xhttp&path=$uuid-vx&mode=auto#${sxname}vl-xhttp-$hostname"
echo "$vl_vx_link" >> "$HOME/sgx/jh.txt"
echo "$vl_vx_link"
echo
if [ -f "$HOME/sgx/cdnym" ]; then
echo "💣【 Vless-xhttp-ecn-cdn 】支持ENC加密，节点信息如下："
echo "注：请将地址替换为你的优选域名/IP；如是回源端口请手动修改对应端口"
vl_vx_cdn_link="vless://$uuid@$xvvmcdnym:$vxpt?encryption=$enkey&flow=xtls-rprx-vision&type=xhttp&host=$xvvmcdnym&path=$uuid-vx&mode=auto#${sxname}vl-xhttp-$hostname"
echo "$vl_vx_cdn_link" >> "$HOME/sgx/jh.txt"
echo "$vl_vx_cdn_link"
echo
fi
fi
if grep vless-ws "$HOME/sgx/xr.json" >/dev/null 2>&1; then
echo "💣【 Vless-ws-enc 】支持ENC加密，节点信息如下："
vwpt=$(cat "$HOME/sgx/vwpt")
vl_vw_link="vless://$uuid@$server_ip:$vwpt?encryption=$enkey&flow=xtls-rprx-vision&type=ws&path=$uuid-vw#${sxname}vl-ws-enc-$hostname"
echo "$vl_vw_link" >> "$HOME/sgx/jh.txt"
echo "$vl_vw_link"
echo
if [ -f "$HOME/sgx/cdnym" ]; then
echo "💣【 Vless-ws-enc-cdn 】支持ENC加密，节点信息如下："
echo "注：请将地址替换为你的优选域名/IP；如是回源端口请手动修改对应端口"
vl_vw_cdn_link="vless://$uuid@$xvvmcdnym:$vwpt?encryption=$enkey&flow=xtls-rprx-vision&type=ws&host=$xvvmcdnym&path=$uuid-vw#${sxname}vl-ws-enc-cdn-$hostname"
echo "$vl_vw_cdn_link" >> "$HOME/sgx/jh.txt"
echo "$vl_vw_cdn_link"
echo
fi
fi
if grep reality-vision "$HOME/sgx/xr.json" >/dev/null 2>&1; then
echo "💣【 Vless-tcp-reality-vision 】节点信息如下："
vlpt=$(cat "$HOME/sgx/vlpt")
vl_link="vless://$uuid@$server_ip:$vlpt?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$reym&fp=chrome&pbk=$public_key_x&sid=$short_id_x&type=tcp&headerType=none#${sxname}vl-reality-vision-$hostname"
echo "$vl_link" >> "$HOME/sgx/jh.txt"
echo "$vl_link"
echo
fi
if grep ss-2022 "$HOME/sgx/sb.json" >/dev/null 2>&1; then
echo "💣【 Shadowsocks-2022 】节点信息如下："
sspt=$(cat "$HOME/sgx/sspt")
ss_link="ss://$(echo -n "2022-blake3-aes-128-gcm:$sskey@$server_ip:$sspt" | base64 -w0)#${sxname}Shadowsocks-2022-$hostname"
echo "$ss_link" >> "$HOME/sgx/jh.txt"
echo "$ss_link"
echo
fi
if grep vmess-xr "$HOME/sgx/xr.json" >/dev/null 2>&1 || grep vmess-sb "$HOME/sgx/sb.json" >/dev/null 2>&1; then
echo "💣【 Vmess-ws 】节点信息如下："
vmpt=$(cat "$HOME/sgx/vmpt")
vm_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vm-ws-$hostname\", \"add\": \"$server_ip\", \"port\": \"$vmpt\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"www.bing.com\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
echo "$vm_link" >> "$HOME/sgx/jh.txt"
echo "$vm_link"
echo
if [ -f "$HOME/sgx/cdnym" ]; then
echo "💣【 Vmess-ws-cdn 】节点信息如下："
echo "注：请将地址替换为你的优选域名/IP；如是回源端口请手动修改对应端口"
vm_cdn_link="vmess://$(echo "{ \"v\": \"2\", \"ps\": \"${sxname}vm-ws-cdn-$hostname\", \"add\": \"$xvvmcdnym\", \"port\": \"$vmpt\", \"id\": \"$uuid\", \"aid\": \"0\", \"scy\": \"auto\", \"net\": \"ws\", \"type\": \"none\", \"host\": \"$xvvmcdnym\", \"path\": \"/$uuid-vm\", \"tls\": \"\"}" | base64 -w0)"
echo "$vm_cdn_link" >> "$HOME/sgx/jh.txt"
echo "$vm_cdn_link"
echo
fi
fi
if grep anytls-sb "$HOME/sgx/sb.json" >/dev/null 2>&1; then
echo "💣【 AnyTLS 】节点信息如下："
anpt=$(cat "$HOME/sgx/anpt")
an_link="anytls://$uuid@$server_ip:$anpt?insecure=1&allowInsecure=1#${sxname}anytls-$hostname"
echo "$an_link" >> "$HOME/sgx/jh.txt"
echo "$an_link"
echo
fi
if grep anyreality-sb "$HOME/sgx/sb.json" >/dev/null 2>&1; then
echo "💣【 Any-Reality 】节点信息如下："
arpt=$(cat "$HOME/sgx/arpt")
ar_link="anytls://$uuid@$server_ip:$arpt?security=reality&sni=$reym&fp=chrome&pbk=$public_key_s&sid=$short_id_s&type=tcp&headerType=none#${sxname}any-reality-$hostname"
echo "$ar_link" >> "$HOME/sgx/jh.txt"
echo "$ar_link"
echo
fi
if grep hy2-sb "$HOME/sgx/sb.json" >/dev/null 2>&1; then
echo "💣【 Hysteria2 】节点信息如下："
hypt=$(cat "$HOME/sgx/hypt")
hy2_link="hysteria2://$uuid@$server_ip:$hypt?insecure=1&sni=www.bing.com#${sxname}hy2-$hostname"
echo "$hy2_link" >> "$HOME/sgx/jh.txt"
echo "$hy2_link"
echo
fi
if grep tuic5-sb "$HOME/sgx/sb.json" >/dev/null 2>&1; then
echo "💣【 Tuic 】节点信息如下："
tupt=$(cat "$HOME/sgx/tupt")
tuic5_link="tuic://$uuid:$uuid@$server_ip:$tupt?congestion_control=bbr&udp_relay_mode=native&alpn=h3&sni=www.bing.com&allow_insecure=1&allowInsecure=1#${sxname}tuic-$hostname"
echo "$tuic5_link" >> "$HOME/sgx/jh.txt"
echo "$tuic5_link"
echo
fi
if grep socks5-xr "$HOME/sgx/xr.json" >/dev/null 2>&1 || grep socks5-sb "$HOME/sgx/sb.json" >/dev/null 2>&1; then
echo "💣【 Socks5 】客户端信息如下："
sopt=$(cat "$HOME/sgx/sopt")
echo "请配合其他应用内置代理使用，勿做节点直接使用"
echo "客户端地址：$server_ip"
echo "客户端端口：$sopt"
echo "客户端用户名：$uuid"
echo "客户端密码：$uuid"
echo
fi
echo "---------------------------------------------------------"
echo "聚合节点信息，请进入 $HOME/sgx/jh.txt 文件目录查看或者运行 cat $HOME/sgx/jh.txt 查看"
echo "========================================================="
}
if ! sgx_core_running; then
for P in /proc/[0-9]*; do if [ -L "$P/exe" ]; then TARGET=$(readlink -f "$P/exe" 2>/dev/null); if echo "$TARGET" | grep -qE '/sgx/(sing-box|xray)'; then PID=$(basename "$P"); kill "$PID" 2>/dev/null && echo "Killed $PID ($TARGET)" || echo "Could not kill $PID ($TARGET)"; fi; fi; done
kill -15 $(pgrep -f 'sgx/sing-box' 2>/dev/null) $(pgrep -f 'sgx/xray' 2>/dev/null) >/dev/null 2>&1
v4orv6(){
if [ -z "$( (command -v curl >/dev/null 2>&1 && curl -s4m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -4 -qO- --tries=2 "$v46url" 2>/dev/null) )" ]; then
echo -e "nameserver 2a00:1098:2b::1\nnameserver 2a00:1098:2c::1" > /etc/resolv.conf
fi
if [ -n "$( (command -v curl >/dev/null 2>&1 && curl -s6m5 -k "$v46url" 2>/dev/null) || (command -v wget >/dev/null 2>&1 && timeout 3 wget -6 -qO- --tries=2 "$v46url" 2>/dev/null) )" ]; then
xsdns="[2001:4860:4860::8888]"
sbdnsyx="ipv6_only"
xryx="ForceIPv6v4"
sbyx="prefer_ipv6"
else
xsdns="8.8.8.8"
sbdnsyx="ipv4_only"
xryx="ForceIPv4v6"
sbyx="prefer_ipv4"
fi
}
v4orv6
echo "SingulariX脚本未安装，开始安装..." && sleep 2
ins
if ! sgx_core_running; then
echo "核心进程未启动，安装失败，已停止输出节点信息。"
exit 1
fi
cip
echo
else
echo "SingulariX脚本已安装"
echo
singularix_status
exit
fi
