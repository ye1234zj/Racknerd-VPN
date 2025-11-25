#!/bin/bash
# RackNerd 一键 VLESS + Reality + gRPC 干净节点
# GitHub: 你的仓库地址

red='\033[31m'; green='\033[32m'; yellow='\033[33m'; plain='\033[0m'
if [[ $EUID -ne 0 ]]; then echo -e "${red}请用 root 运行！${plain}"; exit 1; fi

apt update -y && apt install -y curl wget qrencode unzip -qq

echo "正在安装 Xray-core..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta > /dev/null 2>&1

UUID=$(cat /proc/sys/kernel/random/uuid)
SHORT=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8)
PRIVATE_KEY=$(xray x25519 | grep "Private key" | awk '{print $3}')
PUBLIC_KEY=$(xray x25519 | grep "Public key" | awk '{print $3}')

read -p "请输入你的域名（已解析到本VPS IP）: " DOMAIN
if [[ -z "$DOMAIN" ]]; then echo "域名不能为空！"; exit 1; fi

curl https://get.acme.sh | sh -s email=my@example.com > /dev/null 2>&1
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt > /dev/null 2>&1
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone --keylength ec-256 > /dev/null 2>&1
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --ecc --fullchain-file /usr/local/etc/xray/fullchain.crt --key-file /usr/local/etc/xray/private.key > /dev/null 2>&1

cat > /usr/local/etc/xray/config.json << EOF
{
  "log":{"loglevel":"warning"},
  "inbounds":[{
    "port":443,"protocol":"vless","settings":{"clients":[{"id":"$UUID","flow":"xtls-rprx-vision"}],"decryption":"none"},
    "streamSettings":{
      "network":"grpc","security":"reality",
      "realitySettings":{
        "dest":"www.microsoft.com:443","serverNames":["$DOMAIN"],
        "privateKey":"$PRIVATE_KEY","publicKey":"$PUBLIC_KEY","shortIds":["$SHORT"]
      },
      "grpcSettings":{"serviceName":"grpc"}
    }
  }],
  "outbounds":[{"protocol":"freedom"}]
}
EOF

systemctl restart xray && systemctl enable xray > /dev/null

echo -e "${green}VLESS-Reality 安装完成！${plain}\n"
echo "地址: $DOMAIN"
echo "端口: 443"
echo "UUID: $UUID"
echo "PublicKey: $PUBLIC_KEY"
echo "ShortId: $SHORT"
echo "传输: grpc   安全: reality"
echo -e "\n链接：${yellow}vless://$UUID@$DOMAIN:443?security=reality&pbk=$PUBLIC_KEY&sid=$SHORT&type=grpc&serviceName=grpc&sni=$DOMAIN#RackNerd-Reality${plain}\n"
qrencode -t ansiutf8 "vless://$UUID@$DOMAIN:443?security=reality&pbk=$PUBLIC_KEY&sid=$SHORT&type=grpc&serviceName=grpc&sni=$DOMAIN#RackNerd-Reality"
