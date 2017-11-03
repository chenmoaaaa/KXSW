#!/bin/bash
export PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

#Check Root
[ $(id -u) != "0" ] && { echo "Error: You must be root to run this script"; exit 1; }

#V2Ray Install
echo "准备安装V2Ray"
bash <(curl -L -s https://install.direct/go.sh)

read -p "输入TLS域名： " udomain
read -p "输入TLS端口： " uport
#无tls的端口
uport2=$[uport + 1]
echo "无TLS的端口为：$uport2"
read -p "输入用户UUID： " uuid
read -p "输入传输方式(tcp或ws，默认ws)： " utype
[ -z "${utype}" ] && utype="ws"
#安装 acmey.sh依赖
apt-get install socat
#安装 acme.sh
curl  https://get.acme.sh | sh
#确保acme.sh脚本所设置的命令别名生效
source ~/.bashrc
#证书生成
echo "生成证书..."
~/.acme.sh/acme.sh --issue -d $udomain --standalone -k ec-256
echo "安装证书..."
#证书安装
~/.acme.sh/acme.sh --installcert -d $udomain --fullchainpath /etc/v2ray/v2ray.crt --keypath /etc/v2ray/v2ray.key --ecc
#mkdir /etc/v2ray
echo -e "{
  \"log\" : {
    \"access\": \"/var/log/v2ray/access.log\",
    \"error\": \"/var/log/v2ray/error.log\",
    \"loglevel\": \"warning\"
  },
  \"inbound\": {
    \"port\": $uport2,
    \"protocol\": \"vmess\",
    \"settings\": {
      \"clients\": [
        {
          \"id\": \"$uuid\",
          \"level\": 1,
          \"alterId\": 64
        }
      ]
    },
    \"streamSettings\":{
      \"network\": \"$utype\"
    }
  },
  \"inboundDetour\":[
    {
      \"port\": $uport,
      \"protocol\": \"vmess\",
      \"settings\": {
        \"clients\": [
          {
            \"id\": \"$uuid\",
            \"level\": 1,
            \"alterId\": 64
          }
        ]
      },
      \"streamSettings\":{
        \"network\": \"$utype\",
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
}
" > /etc/v2ray/config.json

service v2ray restart
