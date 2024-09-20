#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# -------------------------------
# 1. Update Package Index
# -------------------------------
echo "Updating package index..."
sudo apt update

# -------------------------------
# 2. Install Java 1.8 and wget
# -------------------------------
echo "Installing OpenJDK 8 and wget..."
sudo apt install openjdk-8-jdk wget -y

# Verify Java installation
echo "Verifying Java installation..."
java -version

# -------------------------------
# 3. Create Necessary Directories
# -------------------------------
echo "Creating directories..."
sudo mkdir -p /opt/nexus/
sudo mkdir -p /tmp/nexus/

# -------------------------------
# 4. Download and Extract Nexus
# -------------------------------
echo "Navigating to /tmp/nexus/..."
cd /tmp/nexus/

NEXUSURL="https://download.sonatype.com/nexus/3/latest-unix.tar.gz"
echo "Downloading Nexus from $NEXUSURL..."
wget $NEXUSURL -O nexus.tar.gz

echo "Extracting Nexus..."
EXTRACT_OUTPUT=$(tar xzvf nexus.tar.gz)
NEXUSDIR=$(echo $EXTRACT_OUTPUT | head -n 1 | cut -d '/' -f1)

echo "Nexus directory extracted: $NEXUSDIR"

# Clean up the downloaded tar.gz file
echo "Removing downloaded tar.gz file..."
rm -rf /tmp/nexus/nexus.tar.gz

# -------------------------------
# 5. Move Nexus to /opt/nexus/
# -------------------------------
echo "Copying Nexus files to /opt/nexus/..."
sudo cp -r /tmp/nexus/* /opt/nexus/

# -------------------------------
# 6. Create Nexus User
# -------------------------------
echo "Creating 'nexus' user..."
# Check if user already exists
if id "nexus" &>/dev/null; then
    echo "User 'nexus' already exists. Skipping user creation."
else
    sudo useradd -r -s /bin/false nexus
    echo "User 'nexus' created."
fi

# Assign ownership of Nexus directories to the 'nexus' user
echo "Setting ownership of /opt/nexus/ to 'nexus' user..."
sudo chown -R nexus:nexus /opt/nexus/

# -------------------------------
# 7. Configure Systemd Service for Nexus
# -------------------------------
echo "Creating systemd service file for Nexus..."

sudo tee /etc/systemd/system/nexus.service > /dev/null <<EOT
[Unit]
Description=Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
Environment=INSTALL4J_JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ExecStart=/opt/nexus/$NEXUSDIR/bin/nexus start
ExecStop=/opt/nexus/$NEXUSDIR/bin/nexus stop
User=nexus
Restart=on-abort

[Install]
WantedBy=multi-user.target
EOT

echo "Systemd service file created."

# -------------------------------
# 8. Configure Nexus Runtime Settings
# -------------------------------
echo "Configuring Nexus runtime settings..."
echo 'run_as_user="nexus"' | sudo tee /opt/nexus/$NEXUSDIR/bin/nexus.rc > /dev/null

# -------------------------------
# 9. Reload Systemd and Start Nexus Service
# -------------------------------
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Starting Nexus service..."
sudo systemctl start nexus

echo "Enabling Nexus service to start on boot..."
sudo systemctl enable nexus

# -------------------------------
# 10. Verify Nexus Service Status
# -------------------------------
echo "Checking Nexus service status..."
sudo systemctl status nexus --no-pager

# -------------------------------
# 11. Cleanup Temporary Files
# -------------------------------
echo "Cleaning up temporary files..."
cd ~
sudo rm -rf /tmp/nexus/

echo "Nexus installation and setup completed successfully."
