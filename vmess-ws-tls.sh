#!/bin/bash
# RackNerd 一键 VMess + WS + TLS 经典稳定节点

red='\033[31m'; green='\033[32m'; yellow='\033[33m'; plain='\033[0m'
if [[ $EUID -ne 0 ]]; then echo -e "${red}请用 root 运行！${plain}"; exit 1; fi

apt update -y && apt install -y curl wget nginx qrencode -qq

echo "安装 Xray..."
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install --beta > /dev/null 2>&1

UUID=$(cat /proc/sys/kernel/random/uuid)

read -p "请输入你的域名（已解析到本VPS）: " DOMAIN
if [[ -z "$DOMAIN" ]]; then echo "域名不能为空！"; exit 1; fi

# 申请证书
curl https://get.acme.sh | sh > /dev/null 2>&1
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
~/.acme.sh/acme.sh --issue -d $DOMAIN --standalone > /dev/null 2>&1
~/.acme.sh/acme.sh --install-cert -d $DOMAIN --fullchain-file /data/fullchain.cer --key-file /data/private.key > /dev/null 2>&1

mkdir -p /usr/local/etc/xray /data
cp /data/fullchain.cer /usr/local/etc/xray/fullchain.crt
cp /data/private.key /usr/local/etc/xray/private.key

cat > /usr/local/etc/xray/config.json << EOF
{
  "log":{"loglevel":"warning"},
  "inbounds":[{
    "port":443,"protocol":"vmess","settings":{"clients":[{"id":"$UUID"}]},
    "streamSettings":{
      "network":"ws","security":"tls","tlsSettings":{"certificates":[{"certificateFile":"/usr/local/etc/xray/fullchain.crt","keyFile":"/usr/local/etc/xray/private.key"}]},
      "wsSettings":{"path":"/ray"}
    }
  }],
  "outbounds":[{"protocol":"freedom"}]
}
EOF

# Nginx 伪装网站
cat > /var/www/html/index.html << EOF
<h1>Welcome to my website</h1>
<p>正常网站内容...</p>
EOF

cat > /etc/nginx/conf.d/vmess.conf << EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/html;
    index index.html;
}
EOF
systemctl restart nginx

systemctl restart xray && systemctl enable xray

echo -e "${green}VMess+WS+TLS 安装完成！${plain}\n"
echo "地址: $DOMAIN"
echo "端口: 443"
echo "UUID: $UUID"
echo "alterId: 0"
echo "加密: auto"
echo "传输: ws"
echo "路径: /ray"
echo "底层: tls"
echo -e "\n链接：${yellow}vmess://$(echo -n "{\"v\":\"2\",\"ps\":\"RackNerd-VMess\",\"add\":\"$DOMAIN\",\"port\":\"443\",\"id\":\"$UUID\",\"aid\":0,\"net\":\"ws\",\"type\":\"none\",\"host\":\"$DOMAIN\",\"path\":\"/ray\",\"tls\":\"tls\"}" | base64 -w0)${plain}\n"
