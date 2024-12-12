#!/bin/bash

# sudo vi /etc/nginx/nginx.conf
# server { ・・・ } の部分を、下記内容に変更します

# server {
#         listen 80;
#         server_name _;
#         location / {
#             proxy_pass http://localhost:8080;
#             proxy_http_version 1.1;
#             proxy_set_header Upgrade $http_upgrade;
#             proxy_set_header Connection 'upgrade';
#             proxy_set_header Host $host;
#             proxy_cache_bypass $http_upgrade;
#         }
#     }
# 設定を更新した後、Nginxを再起動します。
# sudo systemctl restart nginx

# 1. yumのアップデート
# システムを最新の状態に保つためにyumパッケージをアップデートします。
yum update -y

# 2. Gitのインストール
# EC2インスタンスにソースコードをダウンロードするために、Gitをインストールします。
yum install -y git

# 3. Goのインストール
# APIサーバとして機能するGo言語をインストールします。
yum install -y golang

# 4. ソースコードのダウンロード
# Gitを使用してソースコードをダウンロードします。
cd /home/ec2-user/
git clone https://github.com/CloudTechOrg/cloudtech-reservation-api.git

# 5. サービスの自動起動設定
# システムの再起動時にもAPIが自動で起動するようにsystemdを設定します。
cat <<EOF > /etc/systemd/system/goserver.service
[Unit]
Description=Go Server

[Service]
WorkingDirectory=/home/ec2-user/cloudtech-reservation-api
ExecStart=/usr/bin/go run main.go
User=ec2-user
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# 設定を有効にし、サービスを開始します。
systemctl daemon-reload
systemctl enable goserver.service
systemctl start goserver.service

# 6. リバースプロキシの設定
# 8080ポートで動作するGoのAPIを80ポートで利用できるように、Nginxをリバースプロキシとして設定します。
yum install nginx
systemctl start nginx
systemctl enable nginx

# Nginxの設定ファイルを編集し、適切なリバースプロキシ設定を行います。
# server { ・・・ } の部分を、下記内容に変更します
cat <<EOF > /etc/nginx/nginx.conf
server {
        listen 80;
        server_name _;
        location / {
            proxy_pass http://localhost:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }
    }
EOF

# 設定を更新した後、Nginxを再起動します。
systemctl restart nginx