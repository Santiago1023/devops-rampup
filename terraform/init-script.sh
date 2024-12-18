#!/bin/bash

# Actualizar el sistema
sudo yum update -y

# Instalar Node.js y npm
# curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
# curl -fsSL https://rpm.nodesource.com/setup_16.x | sudo bash -
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

# Habilitar e iniciar los servicios
sudo systemctl daemon-reload
sudo systemctl enable front-end.service
sudo systemctl enable back-end.service
sudo systemctl start front-end.service
sudo systemctl start back-end.service
