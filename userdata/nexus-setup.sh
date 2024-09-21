#!/bin/bash
set -e
apt update && apt upgrade -y
apt install openjdk-11-jdk wget -y
useradd -r -s /bin/false nexus || true
mkdir -p /opt/nexus /opt/sonatype-work
wget https://download.sonatype.com/nexus/3/latest-unix.tar.gz -O /tmp/nexus.tar.gz
tar -xvzf /tmp/nexus.tar.gz -C /tmp
NEXUSDIR=$(tar -tzf /tmp/nexus.tar.gz | head -1 | cut -d '/' -f1)
mv /tmp/$NEXUSDIR /opt/nexus/latest
chown -R nexus:nexus /opt/nexus /opt/sonatype-work
cat > /etc/systemd/system/nexus.service <<EOT
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
Environment=INSTALL4J_JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
ExecStart=/opt/nexus/latest/bin/nexus start
ExecStop=/opt/nexus/latest/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOT
chmod +x /opt/nexus/latest/bin/nexus
systemctl daemon-reload
systemctl start nexus
systemctl enable nexus
ufw allow 8081/tcp
