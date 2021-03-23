#!/bin/bash

### Database Variables ###
MYSQL_WORDPRESS_USER=wordpress
MYSQL_WORDPRESS_PASSWORD=changeme
MYSQL_WORDPRESS_DB=wordpress

### Enable command echo-ing for /var/log/cloud-init ###
set -x
umask 0002

### Install Docker ###
sudo apt-get update
sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

### Enable password authentication for sshd ###
sed -i "s/PasswordAuthentication\ no/PasswordAuthentication yes/" /etc/ssh/sshd_config
service sshd restart

### Add new group and users for the WordPress & MySQL administrators ###
groupadd -g 1001 wordpress
useradd -m -u 1001 -g 1001 -G 1001,1000,docker,0 -s /bin/bash wordpress
echo -e "changeme\nchangeme" | passwd wordpress
echo 'wordpress  ALL=(ALL:ALL) ALL' >> /etc/sudoers

### Setup Wordpress ###
mkdir /home/wordpress/wordpress_data
chown wordpress:wordpress /home/wordpress/wordpress_data

### Install Docker-Compose ###
sudo curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
chmod 755 /usr/bin/docker-compose

### Start MySQL and Wordpress with Docker-Compose ###
cat <<EOT >> /home/wordpress/docker-compose.yml
version: '3.1'

services:

  wordpress:
    image: wordpress
    restart: always
    ports:
      - 80:80
    environment:
      WORDPRESS_DB_HOST: ${rds-cluster-endpoint}
      WORDPRESS_DB_USER: $MYSQL_WORDPRESS_USER
      WORDPRESS_DB_PASSWORD: $MYSQL_WORDPRESS_PASSWORD
      WORDPRESS_DB_NAME: $MYSQL_WORDPRESS_DB
    volumes:
      - /home/wordpress/wordpress_data:/var/www/html
    logging:
      driver: awslogs
      options:
        awslogs-region: us-east-1
        awslogs-group: ${name}

EOT
chown wordpress:wordpress /home/wordpress/docker-compose.yml

cd /home/wordpress/
docker-compose up -d
