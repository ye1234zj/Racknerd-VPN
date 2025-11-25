#!/bin/bash
# RackNerd 一键 Hysteria2 超强抗丢包节点

green='\033[32m'; yellow='\033[33m'; plain='\033[0m'
if [[ $EUID -ne 0 ]]; then echo "请用 root 运行！"; exit 1; fi

apt update -y && apt install -y curl wget qrencode

# 安装最新版 Hysteria2
bash <(curl -fsSL https://get.hy2.sh/)

# 生成密码和证书
PASSWORD=$(openssl rand -base64 12)
read -p "请输入你的域名（已解析到本VPS）: " DOMAIN

# 自动申请证书
/usr/local/bin/hysteria applycert -d $DOMAIN

cat > /etc/hysteria/config.yaml << EOF
listen: :443
acme:
  domains:
    - $DOMAIN
  email: admin@$DOMAIN
tls:
  cert: /etc/hysteria/$DOMAIN.crt
  key: /etc/hysteria/$DOMAIN.key
auth:
  type: password
  password: $PASSWORD
masquerade:
  type: proxy
  proxy:
    url: https://www.microsoft.com
    rewriteHost: true
EOF

systemctl restart hysteria-server && systemctl enable hysteria-server

echo -e "${green}Hysteria2 安装成功！${plain}\n"
echo "节点地址: $DOMAIN:443"
echo "密码: $PASSWORD"
echo "支持 QUIC 协议，弱网神器！"
echo -e "\n客户端通用链接：${yellow}hysteria2://$PASSWORD@$DOMAIN:443/?sni=$DOMAIN&alpn=h3&insecure=0#RackNerd-Hysteria2${plain}\n"
qrencode -t ansiutf8 "hysteria2://$PASSWORD@$DOMAIN:443/?sni=$DOMAIN&alpn=h3&insecure=0#RackNerd-Hysteria2"
