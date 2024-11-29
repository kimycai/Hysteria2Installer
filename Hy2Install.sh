#!/bin/bash

# Function to display messages in green
green_echo() {
  echo -e "\\033[32m$1\\033[0m"
}

# Function to display messages in red
red_echo() {
  echo -e "\\033[31m$1\\033[0m"
}

# Function to view the current configuration
view_current_config() {
  if [ -f /etc/hysteria/config.yaml ]; then
    local port=$(grep -E "^listen:" /etc/hysteria/config.yaml | awk '{print $2}' | tr -d ':')
    local password=$(grep -E "^  password:" /etc/hysteria/config.yaml | awk '{print $2}')
    local domain=$(grep -E "^    url:" /etc/hysteria/config.yaml | awk '{print $2}')
    green_echo "----------------------------------------"
    red_echo "$config_port_message: $port"
    red_echo "$config_password_message: $password"
    red_echo "$config_domain_message: $domain"
    green_echo "----------------------------------------"
  else
    red_echo "$config_missing_message"
  fi
}

# Function to check the status of the Hysteria service
check_hysteria_status() {
  local status=$(systemctl is-active hysteria-server.service)
  local enabled=$(systemctl is-enabled hysteria-server.service 2>/dev/null)
  local congestion=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | awk '{print $3}')
  
  green_echo "----------------------------------------"
  green_echo "$status_message: $status"
  green_echo "$autostart_message: $enabled"
  green_echo "$congestion_message: $congestion"
  green_echo "----------------------------------------"
}

# Function to install Hysteria2 and enable BBR
install_hysteria() {
  green_echo "$update_message"
  sudo apt update && sudo apt install -y curl openssl

  green_echo "$domain_message"
  read USER_DOMAIN
  USER_DOMAIN=${USER_DOMAIN:-bing.com}

  green_echo "$port_message"
  read USER_PORT
  USER_PORT=${USER_PORT:-6688}

  green_echo "$install_message"
  bash <(curl -fsSL https://get.hy2.sh/)

  green_echo "$create_dir_message"
  sudo mkdir -p /etc/hysteria

  green_echo "$generate_cert_message"
  openssl ecparam -name prime256v1 -out ecparams.pem
  sudo openssl req -x509 -nodes -newkey ec:ecparams.pem \
    -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt \
    -subj "/CN=$USER_DOMAIN" -days 36500
  rm -f ecparams.pem

  if ! id "hysteria" &>/dev/null; then
    green_echo "$create_user_message"
    sudo useradd --system --no-create-home hysteria
  fi

  green_echo "$set_owner_message"
  sudo chown hysteria /etc/hysteria/server.key
  sudo chown hysteria /etc/hysteria/server.crt

  DEFAULT_PASSWORD=$(openssl rand -base64 16 | tr -d '=+/' | cut -c1-16)
  green_echo "$password_message"
  read USER_PASSWORD
  USER_PASSWORD=${USER_PASSWORD:-$DEFAULT_PASSWORD}

  green_echo "$create_config_message"
  cat <<EOF | sudo tee /etc/hysteria/config.yaml
listen: :$USER_PORT

tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key

auth:
  type: password
  password: $USER_PASSWORD

masquerade:
  type: proxy
  proxy:
    url: https://$USER_DOMAIN
    rewriteHost: true
EOF

  green_echo "$create_service_message"
  sudo tee /etc/systemd/system/hysteria-server.service <<EOF
[Unit]
Description=Hysteria2 Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria -c /etc/hysteria/config.yaml server
Restart=on-failure
User=hysteria
Group=hysteria

[Install]
WantedBy=multi-user.target
EOF

  green_echo "$reload_service_message"
  sudo systemctl daemon-reload
  sudo systemctl start hysteria-server.service
  sudo systemctl enable hysteria-server.service

  # Install and enable BBR
  green_echo "$bbr_message"
  wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh
  chmod +x /opt/bbr.sh
  sudo /opt/bbr.sh

  green_echo "$install_success_message"
  red_echo "$port_output: $USER_PORT"
  red_echo "$password_output: $USER_PASSWORD"
  red_echo "$domain_output: $USER_DOMAIN"
  check_hysteria_status
}

# Function to enable BBR manually from the menu
enable_bbr() {
  green_echo "$bbr_manual_message"
  wget --no-check-certificate -O /opt/bbr.sh https://github.com/teddysun/across/raw/master/bbr.sh
  chmod +x /opt/bbr.sh
  sudo /opt/bbr.sh
  green_echo "$bbr_success_message"
  check_hysteria_status
}

# Language selection
green_echo "Select language / 选择语言:"
green_echo "0: 中文 (default)"
green_echo "1: English"
read language
language=${language:-0}


if [ "$language" -eq 1 ]; then
  # English messages
  update_message="Updating system and installing dependencies..."
  domain_message="Please enter the masquerade URL (press Enter to use default: bing.com):"
  port_message="Please enter the port you want Hysteria2 to listen on (press Enter to use default: 6688):"
  install_message="Installing Hysteria2..."
  create_dir_message="Creating /etc/hysteria directory..."
  generate_cert_message="Generating self-signed certificates..."
  create_user_message="Creating hysteria user..."
  set_owner_message="Setting certificate ownership..."
  password_message="Please enter a password for Hysteria2 authentication (press Enter to use a randomly generated password):"
  create_config_message="Creating Hysteria2 configuration..."
  create_service_message="Creating Hysteria2 systemd service file..."
  reload_service_message="Starting and enabling Hysteria2 service..."
  install_success_message="Installation and configuration of Hysteria2 completed successfully!"
  bbr_message="Installing and enabling BBR congestion control..."
  bbr_manual_message="Manually enabling BBR congestion control..."
  bbr_success_message="BBR congestion control has been successfully enabled."
  port_output="Hysteria2 is running on port"
  password_output="Your Hysteria2 password is"
  domain_output="Your masquerade URL is"
  status_message="Hysteria status"
  autostart_message="Hysteria autostart"
  congestion_message="Current congestion control"
  config_port_message="Configured Port"
  config_password_message="Configured Password"
  config_domain_message="Configured Masquerade URL"
  config_missing_message="Configuration file not found!"
  # Additional menu options
  view_config_message="View current configuration"
else
  # Chinese messages
  update_message="正在更新系统并安装依赖..."
  domain_message="请输入伪装域名（直接回车默认为 bing.com）："
  port_message="请输入 Hysteria2 监听的端口（直接回车默认为 6688）："
  install_message="正在安装 Hysteria2..."
  create_dir_message="正在创建 /etc/hysteria 目录..."
  generate_cert_message="正在生成自签证书..."
  create_user_message="正在创建 hysteria 用户..."
  set_owner_message="正在设置证书权限..."
  password_message="请输入 Hysteria2 的认证密码（直接回车随机生成密码）："
  create_config_message="正在创建 Hysteria2 配置文件..."
  create_service_message="正在创建 Hysteria2 systemd 服务文件..."
  reload_service_message="正在启动并启用 Hysteria2 服务..."
  install_success_message="Hysteria2 安装和配置成功！"
  bbr_message="正在安装并启用 BBR 拥塞控制算法..."
  bbr_manual_message="手动启用 BBR 拥塞控制算法..."
  bbr_success_message="BBR 拥塞控制算法已成功启用。"
  port_output="Hysteria2 正在运行的端口"
  password_output="您的 Hysteria2 密码"
  domain_output="您的伪装域名"
  status_message="Hysteria 状态"
  autostart_message="Hysteria 开机自启"
  congestion_message="当前拥塞控制算法"
  config_port_message="配置的端口"
  config_password_message="配置的密码"
  config_domain_message="配置的伪装域名"
  config_missing_message="找不到配置文件！"
  view_config_message="查看当前配置"
fi

# Menu options based on selected language
if [ "$language" -eq 1 ]; then
  menu_install="Install Hysteria2"
  menu_modify="Modify configuration"
  menu_view="View current configuration"
  menu_status="Show status"
  menu_start="Start Hysteria2"
  menu_restart="Restart Hysteria2"
  menu_stop="Stop Hysteria2"
  menu_enable_autostart="Enable Hysteria2 autostart"
  menu_disable_autostart="Disable Hysteria2 autostart"
  menu_enable_bbr="Enable BBR congestion control"
  menu_quit="Quit"
  menu_title="Hysteria Menu"
  enterChoice="Enter your choice"
else
  menu_install="安装 Hysteria2"
  menu_modify="修改配置"
  menu_view="查看当前配置"
  menu_status="查看状态"
  menu_start="启动 Hysteria2"
  menu_restart="重启 Hysteria2"
  menu_stop="停止 Hysteria2"
  menu_enable_autostart="开启开机自启"
  menu_disable_autostart="关闭开机自启"
  menu_enable_bbr="启用 BBR 拥塞控制算法"
  menu_quit="退出"
  menu_title="Hysteria 菜单"
  enterChoice="请输入您的选择"
fi

# Menu loop
while true; do
  green_echo "=================== $menu_title ==================="
  green_echo "0: $menu_install"
  green_echo "1: $menu_modify"
  green_echo "2: $menu_view"
  green_echo "3: $menu_status"
  green_echo "4: $menu_start"
  green_echo "5: $menu_restart"
  green_echo "6: $menu_stop"
  green_echo "7: $menu_enable_autostart"
  green_echo "8: $menu_disable_autostart"
  green_echo "9: $menu_enable_bbr"
  green_echo "q: $menu_quit"
  green_echo "====================================================="
  check_hysteria_status

  green_echo $enterChoice
  read choice

  case $choice in
    0)
      install_hysteria
      ;;
    1)
      green_echo "$menu_modify_message"
      sudo vim /etc/hysteria/config.yaml
      green_echo "$menu_restart_message"
      sudo systemctl restart hysteria-server.service
      green_echo "$menu_restart_success"
      check_hysteria_status
      ;;
    2)
      view_current_config
      ;;
    3)
      green_echo "$menu_status_message"
      check_hysteria_status
      ;;
    4)
      green_echo "$menu_start_message"
      sudo systemctl start hysteria-server.service
      green_echo "$menu_start_success"
      check_hysteria_status
      ;;
    5)
      green_echo "$menu_restart_message"
      sudo systemctl restart hysteria-server.service
      green_echo "$menu_restart_success"
      check_hysteria_status
      ;;
    6)
      green_echo "$menu_stop_message"
      sudo systemctl stop hysteria-server.service
      green_echo "$menu_stop_success"
      check_hysteria_status
      ;;
    7)
      green_echo "$menu_enable_autostart_message"
      sudo systemctl enable hysteria-server.service
      green_echo "$menu_enable_autostart_success"
      check_hysteria_status
      ;;
    8)
      green_echo "$menu_disable_autostart_message"
      sudo systemctl disable hysteria-server.service
      green_echo "$menu_disable_autostart_success"
      check_hysteria_status
      ;;
    9)
      enable_bbr
      ;;
    q)
      green_echo "$menu_quit_message"
      exit 0
      ;;
    *)
      green_echo "$menu_invalid_message"
      ;;
  esac
done
