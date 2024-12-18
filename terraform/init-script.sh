#!/bin/bash

# Actualizar el sistema
sudo yum update -y

# Instalar Node.js y npm
curl -sL https://rpm.nodesource.com/setup_16.x | sudo bash -
sudo yum install -y nodejs git

# Clonar tu repositorio desde GitHub
REPO_URL="https://github.com/Santiago1023/devops-rampup.git" # Cambia esta URL por la de tu fork
APP_DIR="/var/www/app"

sudo git clone $REPO_URL $APP_DIR

# Configurar y ejecutar el Front-end
cd $APP_DIR/movie-analyst-ui
sudo npm install
sudo npm run build # Si es necesario construir la app

# Configurar y ejecutar el Back-end
cd $APP_DIR/movie-analyst-api
sudo npm install

# Crear servicios de sistema para el Front-end y Back-end
sudo tee /etc/systemd/system/front-end.service > /dev/null <<EOF
[Unit]
Description=Front-end Service
After=network.target

[Service]
ExecStart=/usr/bin/node /var/www/app/movie-analyst-ui/server.js
Restart=always
User=ec2-user
Group=ec2-user
Environment=PORT=3030

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/back-end.service > /dev/null <<EOF
[Unit]
Description=Back-end Service
After=network.target

[Service]
ExecStart=/usr/bin/node /var/www/app/movie-analyst-api/server.js
Restart=always
User=ec2-user
Group=ec2-user
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

# Habilitar e iniciar los servicios del Front-end y Back-end
sudo systemctl daemon-reload
sudo systemctl enable front-end.service
sudo systemctl enable back-end.service
sudo systemctl start front-end.service
sudo systemctl start back-end.service

# Instalar y configurar Nginx como proxy reverso
sudo yum install -y nginx

sudo tee /etc/nginx/conf.d/app.conf > /dev/null <<EOF
server {
    listen 80;

    location / {
        proxy_pass http://localhost:3030;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }

    location /api/ {
        proxy_pass http://localhost:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

# Habilitar e iniciar Nginx
sudo systemctl enable nginx
sudo systemctl start nginx
