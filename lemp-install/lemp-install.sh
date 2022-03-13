#!/bin/bash
# Verify root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "WARN: Not Sudo user. Please run as root."
    exit
fi

# Script Disclaimer
echo "############################
### IMPORTANT DISCLAIMER ###
############################

WARNING!!! THIS IS A STUPID SCRIPT!
This script was intended to run only ONCE over 
a fresh installation of Unbutu 20.04 Desktop enviromnent.
This script was NOT tested on any other environment and 
might BREAK YOUR ENVIRONMENT.

Please use this script with caution."
read -p "Do you seriously want to continue?(y/n) " -n 1 -r
echo    
if [[ $REPLY =~ ^[Yy]$ ]]
then
    # OS preperation
    echo "INFO: Installing prequisites"
    ip_addr=$(hostname -I)
    ip_addr=`echo $ip_addr | sed 's/ *$//g'` # Cleaning trailing spaces
    sudo apt update
    sudo apt upgrade -y
    sudo apt install -y vim \
    wget \
    nginx \
    php-fpm \
    php-cli \
    php-mysql \
    unzip \
    ca-certificates \
    mariadb-server \
    expect

    # Retrieving Demo Site to path /var/www/html
    echo "INFO: Downloading demo web-page"
    sudo wget https://davidp.jfrog.io/artifactory/public-generic-local/web-demo-php-1.zip
    unzip web-demo-php-1.zip
    sudo cp -r www.pe-demo.com /var/www/html/.
    sudo rm /var/www/html/index*

    # Configuring Firewall
    echo "INFO: Configuring firewall"
    sudo ufw deny 'HTTP'
    sudo ufw allow 'Nginx HTTPS'
    sudo ufw allow 3306
    yes | sudo ufw enable

    #Generating SSL certificates for Nginx
    echo "INFO: Generating SSL certificate for Nginx"
    sudo mkdir /etc/nginx/ssl
    sudo openssl req -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=pe-demo.com" \
    -newkey rsa:2048 -nodes -keyout /etc/nginx/ssl/key.pem \
    -x509 -days 365 -out /etc/nginx/ssl/certificate.pem
    # certbot --nginx -d pe-demo.duckdns.org -d www.pe-demo.duckdns.org --non-interactive --agree-tos -m davidp@test.com

    # Configuring Nginx
    echo "INFO: Creating Nginx configuration files"
    sudo rm -rf /etc/nginx/sites-enabled/default
    sudo rm -rf /etc/nginx/sites-available/default
    echo "127.0.0.1 pe-demo.com www.pe-demo.com" >> /etc/hosts
    sudo cat <<'EOF' > /etc/nginx/sites-available/www.pe-demo.com.conf
# LEMP STACK DEMO NGINX CONFIGURATION
ssl_certificate		/etc/nginx/ssl/certificate.pem;
ssl_certificate_key	/etc/nginx/ssl/key.pem;
ssl_session_cache	shared:SSL:1m;

server {
    listen 80;

    server_name pe-demo.com www.pe-demo.com;
    return 301 https://www.pe-demo.com$request_uri;
}

server {
    listen 443 ssl;

    root /var/www/html/www.pe-demo.com;
    server_name pe-demo.com www.pe-demo.com;
    rewrite ^/$ https://www.pe-demo.com/welcome.php redirect;
    error_page 404 /404.html;
    location = /404.html {
        root /var/www/html/www.pe-demo.com/;
        internal;
    }

    location / {
        index index.php index.html index.htm;
        try_files $uri $uri/ =404;
    }
    
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
        include snippets/fastcgi-php.conf;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF
    sudo ln -s /etc/nginx/sites-available/www.pe-demo.com.conf /etc/nginx/sites-enabled/www.pe-demo.com.conf
    sudo nginx -s reload

    # Configuring PHP
    echo "INFO: Configuring PHP"
    echo "<?php include 'index.html';?>" > /var/www/html/www.pe-demo.com/index.php
    sudo cat <<'EOF' > /var/www/html/www.pe-demo.com/info.php
<?php
    phpinfo();
?>
EOF

    # Configuring MariaDB with mysql_secure_installation
    echo "INFO: Configuring MariaDB"
    MYSQL_ROOT_PASSWORD=pass
    SECURE_MYSQL=$(expect -c "
    set timeout 10
    spawn mysql_secure_installation
    expect \"Enter current password for root (enter for none):\"
    send \"$MYSQL\r\"
    expect \"Change the root password?\"
    send \"n\r\"
    expect \"Remove anonymous users?\"
    send \"y\r\"
    expect \"Disallow root login remotely?\"
    send \"y\r\"
    expect \"Remove test database and access to it?\"
    send \"y\r\"
    expect \"Reload privilege tables now?\"
    send \"y\r\"
    expect eof
    ")
    echo "$SECURE_MYSQL"

    # Configure Certificates for MariaDB
    echo "INFO: Creating certificates for MariaDB"
    mkdir -p /etc/mysql/certificates
    cd /etc/mysql/certificates
    openssl genrsa 2048 > ca-key.pem
    openssl req -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=ca.pe-demo.com" \
        -new -x509 -nodes -days 365000 \
        -key /etc/mysql/certificates/ca-key.pem \
        -out /etc/mysql/certificates/ca-cert.pem
    openssl req -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=server.pe-demo.com" \
        -newkey rsa:2048 -days 365000 -nodes \
        -keyout /etc/mysql/certificates/server-key.pem \
        -out /etc/mysql/certificates/server-req.pem
    openssl rsa -in /etc/mysql/certificates/server-key.pem -out /etc/mysql/certificates/server-key.pem
    openssl x509 -req -in /etc/mysql/certificates/server-req.pem \
        -days 365000 -CA /etc/mysql/certificates/ca-cert.pem \
        -CAkey /etc/mysql/certificates/ca-key.pem -set_serial 01 \
        -out /etc/mysql/certificates/server-cert.pem
    openssl req -subj "/C=GB/ST=London/L=London/O=Global Security/OU=IT Department/CN=client.pe-demo.com" \
        -newkey rsa:2048 -days 365000 -nodes \
        -keyout /etc/mysql/certificates/client-key.pem \
        -out /etc/mysql/certificates/client-req.pem
    openssl rsa -in /etc/mysql/certificates/client-key.pem -out /etc/mysql/certificates/client-key.pem
    openssl x509 -req -in client-req.pem -days 365000 \
        -CA /etc/mysql/certificates/ca-cert.pem \
        -CAkey /etc/mysql/certificates/ca-key.pem -set_serial 01 \
        -out /etc/mysql/certificates/client-cert.pem
    chmod 644 *

    # DB Encryption Keys
    echo "INFO: Generating encryption keys for MariaDB"
    mkdir -p /etc/mysql/encryption
    cd /etc/mysql/encryption
    echo -n "1;"$(openssl rand -hex 32) > keys
    echo -n "
2;"$(openssl rand -hex 32) >> keys
    echo -n "
3;"$(openssl rand -hex 32) >> keys
    echo -n "
4;"$(openssl rand -hex 32) >> keys
    openssl rand -hex 128 > password_file
    openssl enc -aes-256-cbc -md sha1 -pass file:password_file -in keys -out keys.enc
     
    # Configuring MariaDB with Keys
    echo "INFO: Setting keys for MariaDB 50-server.cnf file"
    echo "[mariadb]
# File Key Management
plugin_load_add = file_key_management
file_key_management_filename = /etc/mysql/encryption/keys.enc
file_key_management_filekey = FILE:/etc/mysql/encryption/password_file
file_key_management_encryption_algorithm = aes_cbc

# InnoDB/XtraDB Encryption Setup
innodb_default_encryption_key_id = 1
innodb_encrypt_tables = ON
innodb_encrypt_log = ON
innodb_encryption_threads = 4

# Aria Encryption Setup
aria_encrypt_tables = ON

# Temp & Log Encryption
encrypt-tmp-disk-tables = 1
encrypt-tmp-files = 1
encrypt_binlog = ON" > /etc/mysql/mariadb.conf.d/encryption.cnf
    cd /etc/mysql/
    sudo chown -R mysql:root ./encryption 
    sudo chmod 500 /etc/mysql/encryption/
    cd ./encryption
    chmod 400 keys.enc password_file 
    chmod 644 encryption.cnf
    sudo service mariadb restart
    echo "
# SSL Configuration
ssl_cert = /etc/mysql/certificates/server-cert.pem
ssl_key = /etc/mysql/certificates/server-key.pem
ssl_ca = /etc/mysql/certificates/ca-cert.pem" >> /etc/mysql/mariadb.conf.d/50-server.cnf
    echo "
# SSL Configuration
ssl_cert = /etc/mysql/certificates/client-cert.pem
ssl_key = /etc/mysql/certificates/client-key.pem
ssl_ca = /etc/mysql/certificates/ca-cert.pem" >> /etc/mysql/mariadb.conf.d/50-client.cnf
    sudo service mysql restart

    # Creating DB and Table
    sudo mysql -u root -p=pass -e "CREATE DATABASE testdb;"
    sudo mysql -u root -p=pass -e "use testdb; CREATE TABLE users ( \
        id INT NOT NULL PRIMARY KEY AUTO_INCREMENT, \
        username VARCHAR(50) NOT NULL UNIQUE, \
        password VARCHAR(255) NOT NULL, \
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP \
    );"
    # Creating User and Granting Permissions
    sudo mysql -u root -p=pass -D testdb -e "alter table users ENCRYPTED=Yes;"
    sudo mysql -u root -p=pass -e "CREATE USER 'test'@localhost IDENTIFIED BY 'pass';"
    sudo mysql -u root -p=pass -e "GRANT ALL ON testdb.* TO 'test'@localhost;"
    sudo mysql -u root -p=pass -e "FLUSH PRIVILEGES;"
    echo "
#####################
### Running Tests ###
#####################
"
openssl s_client -connect 127.0.0.1:3306 -tls1_2
sudo mysql -u root -p=pass -e "show variables like 'have_ssl';"
sudo mysql -u root -p=pass -D testdb -e "SELECT NAME, ENCRYPTION_SCHEME, CURRENT_KEY_ID FROM information_schema.INNODB_TABLESPACES_ENCRYPTION WHERE NAME='testdb/users';"
    echo "
Verify the above has SSL, encryption and tls1_2 available."
    echo "
################
### All Done ###
################
To enhance Nginx performance, add the below directives to the /etc/nginx/nginx.conf file, under the 'http' section:
        open_file_cache max=2048 inactive=20s;
        open_file_cache_valid 120s;
        client_body_buffer_size 10k;
        client_max_body_size 8m;
        large_client_header_buffers 4 4k;
        client_body_timeout 12;
        client_header_timeout 12;
        send_timeout 10;

Update your local machine /etc/hosts:
echo '${ip_addr} pe-demo.com www.pe-demo.com' >> /etc/hosts"
fi
