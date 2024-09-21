#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Backup and update system limits
sudo cp /etc/sysctl.conf /root/sysctl.conf_backup
cat <<EOT | sudo tee /etc/sysctl.conf
vm.max_map_count=524288
fs.file-max=131072
EOT

sudo cp /etc/security/limits.conf /root/sec_limit.conf_backup
cat <<EOT | sudo tee -a /etc/security/limits.conf
sonar   -   nofile   131072
sonar   -   nproc    8192
EOT

# Apply new sysctl settings
sudo sysctl -p

# Update ulimit settings
echo "ulimit -n 131072" | sudo tee -a /etc/profile
echo "ulimit -u 8192" | sudo tee -a /etc/profile
source /etc/profile

# Install Java (Java 11)
sudo apt-get update -y
sudo apt-get install openjdk-11-jdk -y

# Verify Java installation
java -version

# Set Java alternatives
sudo update-alternatives --install /usr/bin/java java /usr/lib/jvm/java-11-openjdk-amd64/bin/java 1111
sudo update-alternatives --set java /usr/lib/jvm/java-11-openjdk-amd64/bin/java

# Install PostgreSQL
sudo apt-get install postgresql postgresql-contrib -y

# Start and enable PostgreSQL service
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Configure PostgreSQL for SonarQube
sudo -u postgres psql -c "CREATE USER sonar WITH ENCRYPTED PASSWORD 'admin123';"
sudo -u postgres psql -c "CREATE DATABASE sonarqube OWNER sonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;"

# Install SonarQube
sudo apt-get install wget unzip -y
cd /opt/
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-9.9.0.65466.zip
sudo unzip sonarqube-9.9.0.65466.zip
sudo mv sonarqube-9.9.0.65466 sonarqube

# Create SonarQube user and set permissions
sudo groupadd sonar || true
sudo useradd -c "SonarQube User" -d /opt/sonarqube -g sonar sonar || true
sudo chown -R sonar:sonar /opt/sonarqube

# Configure SonarQube
sudo cp /opt/sonarqube/conf/sonar.properties /opt/sonarqube/conf/sonar.properties_backup
cat <<EOT | sudo tee /opt/sonarqube/conf/sonar.properties
sonar.jdbc.username=sonar
sonar.jdbc.password=admin123
sonar.jdbc.url=jdbc:postgresql://localhost/sonarqube
sonar.web.host=0.0.0.0
sonar.web.port=9000
EOT

# Create systemd service file for SonarQube
cat <<EOT | sudo tee /etc/systemd/system/sonarqube.service
[Unit]
Description=SonarQube service
After=network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=sonar
Group=sonar
Restart=always
LimitNOFILE=131072
LimitNPROC=8192
TimeoutStartSec=600
Environment="JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64"
Environment="SONAR_JAVA_PATH=/usr/lib/jvm/java-11-openjdk-amd64/bin/java"

[Install]
WantedBy=multi-user.target
EOT

# Reload systemd daemon and enable SonarQube service
sudo systemctl daemon-reload
sudo systemctl enable sonarqube.service

# Install and configure Nginx
sudo apt-get install nginx -y
sudo rm -rf /etc/nginx/sites-enabled/default
sudo rm -rf /etc/nginx/sites-available/default
cat <<EOT | sudo tee /etc/nginx/sites-available/sonarqube
server {
    listen      80;
    server_name sonarqube.example.com;

    access_log  /var/log/nginx/sonar.access.log;
    error_log   /var/log/nginx/sonar.error.log;

    location / {
        proxy_pass  http://127.0.0.1:9000;
        proxy_set_header    Host            \$host;
        proxy_set_header    X-Real-IP       \$remote_addr;
        proxy_set_header    X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header    X-Forwarded-Proto http;
    }
}
EOT

# Enable Nginx configuration and restart service
sudo ln -s /etc/nginx/sites-available/sonarqube /etc/nginx/sites-enabled/sonarqube
sudo systemctl enable nginx.service
sudo systemctl restart nginx.service

# Adjust firewall settings
sudo ufw allow 80/tcp
sudo ufw allow 9000/tcp
sudo ufw allow 9001/tcp
sudo ufw reload || echo "Firewall not enabled (skipping reload)"

# Reboot the system
echo "System reboot in 30 seconds"
sleep 30
sudo reboot
