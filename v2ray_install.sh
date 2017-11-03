#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

#Check Root
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }

YUM_CMD=$(command -v yum)
APT_CMD=$(command -v apt-get)

function install_component() {
  local COMPONENT=$1
  COMPONENT_CMD=$(command -v $COMPONENT)
  if [ -n "${COMPONENT_CMD}" ]; then
    echo "$COMPONENT was installed";
    return
  fi

  if [ -n "${YUM_CMD}" ]; then
    echo "Installing ${COMPONENT} via yum."
    ${YUM_CMD} -y -q install $COMPONENT
  elif [ -n "${APT_CMD}" ]; then
    echo "Installing ${COMPONENT} via apt-get."
    ${APT_CMD} -y -qq install $COMPONENT
  fi
}

#V2Ray Install
echo "准备安装V2Ray，websock+tls与tcp+tls方式"
bash <(curl -L -s https://install.direct/go.sh)

read -p "输入TLS域名： " domain
read -p "输入tcp的TLS端口： " port
read -p "输入ws的TLS端口：" port2
#read -p "输入传输方式(tcp或ws，默认ws)： " network
# [ -z "${network}" ] && network="ws"
#安装 acmey.sh依赖
install_component "socat"
#安装 acme.sh
curl  https://get.acme.sh | sh
#确保acme.sh脚本所设置的命令别名生效
source ~/.bashrc
#证书生成
echo "生成证书..."
iptables -I INPUT 1 -p tcp --dport 443 -j ACCEPT
~/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
echo "安装证书..."
#证书安装
~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
#mkdir /etc/v2ray
UUID=$(cat /proc/sys/kernel/random/uuid)
echo -e "{
  \"log\" : {
    \"access\": \"/var/log/v2ray/access.log\",
    \"error\": \"/var/log/v2ray/error.log\",
    \"loglevel\": \"warning\"
  },
  \"inbound\": {
    \"port\": $port,
    \"protocol\": \"vmess\",
    \"settings\": {
      \"clients\": [
        {
          \"id\": \"$UUID\",
          \"level\": 1,
          \"alterId\": 64
        }
      ]
    },
    \"streamSettings\":{
      \"network\": \"tcp\",
      \"security\": \"tls\",
      \"tlsSettings\": {
        \"allowInsecure\" : true,
        \"certificates\": [
          {
            \"certificateFile\": \"/etc/v2ray/v2ray.crt\",
            \"keyFile\": \"/etc/v2ray/v2ray.key\"
          }
        ]
      }
    }
  },
  \"inboundDetour\": [
    {
      \"port\": $port2,
      \"protocol\": \"vmess\",
      \"settings\": {
        \"clients\": [
          {
            \"id\": \"$UUID\",
            \"level\": 1,
            \"alterId\": 64
          }
        ]
      },
      \"streamSettings\":{
        \"network\": \"ws\",
        \"security\": \"tls\",
        \"tlsSettings\": {
          \"allowInsecure\" : true,
          \"certificates\": [
            {
              \"certificateFile\": \"/etc/v2ray/v2ray.crt\",
              \"keyFile\": \"/etc/v2ray/v2ray.key\"
            }
          ]
        }
      }
    }
  ],
  \"outbound\": {
    \"protocol\": \"freedom\",
    \"settings\": {}
  },
  \"outboundDetour\": [
    {
      \"protocol\": \"blackhole\",
      \"settings\": {},
      \"tag\": \"blocked\"
    }
  ],
  \"routing\": {
    \"strategy\": \"rules\",
    \"settings\": {
      \"rules\": [
        {
          \"type\": \"field\",
          \"ip\": [
            \"0.0.0.0/8\",
            \"10.0.0.0/8\",
            \"100.64.0.0/10\",
            \"127.0.0.0/8\",
            \"169.254.0.0/16\",
            \"172.16.0.0/12\",
            \"192.0.0.0/24\",
            \"192.0.2.0/24\",
            \"192.168.0.0/16\",
            \"198.18.0.0/15\",
            \"198.51.100.0/24\",
            \"203.0.113.0/24\",
            \"::1/128\",
            \"fc00::/7\",
            \"fe80::/10\"
          ],
          \"outboundTag\": \"blocked\"
        }
      ]
    }
  }
}" > /etc/v2ray/config.json

echo "安装完成，传输方式为ws+tls和tcp+tls。"
echo "域名：$domain"
echo "tcp端口：$port, ws端口：$port2"
echo "uuid：$UUID"


service v2ray restart
