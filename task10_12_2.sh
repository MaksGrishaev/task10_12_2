#!/bin/bash

dir=$(dirname $0)

source $dir/config

cd $dir
mkdir -p $dir/etc
mkdir -p $dir/certs

#installing docker
apt-get install -y curl
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y docker-ce docker-compose
##################

###SSL
#CA
openssl genrsa -out $dir/certs/root-ca.key 4096
openssl req -x509 -new -nodes -key $dir/certs/root-ca.key -days 365 \
	-out $dir/certs/root-ca.crt -subj "/C=UA/L=Kharkiv/O=HW/OU=task6_7/CN=root_cert"
#WEB
openssl genrsa -out $dir/certs/web.key 4096
openssl req -new -key $dir/certs/web.key -out $dir/certs/web.csr \
	-subj "/C=UA/L=Kharkiv/O=HW/OU=task6_7/CN=$HOST_NAME" \
	-reqexts SAN -config <(cat $dir/certs/openssl.cnf <(printf "\n[SAN]\nsubjectAltName=IP:$EXTERNAL_IP")) 
openssl x509 -req -days 365 -in $dir/certs/web.csr -CA $dir/certs/root-ca.crt \
	-CAkey $dir/certs/root-ca.key -CAcreateserial -out $dir/certs/web.crt \
	-extfile <(printf "subjectAltName=IP:$EXTERNAL_IP")
cat $dir/certs/root-ca.crt >> $dir/certs/web.crt
##################

###NGINX
echo "
server {
listen  $NGINX_PORT;
ssl on;
ssl_certificate /etc/ssl/certs/web.crt;
ssl_certificate_key /etc/ssl/certs/web.key;
 location / {
    	    proxy_pass http://apache;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
    }
} " >> $dir/etc/nginx.conf
###################

###YML CONF
echo "version: '2'
services:
  nginx:
    image: $NGINX_IMAGE
    ports:
      - '$NGINX_PORT:$NGINX_PORT'
    volumes:
      - $dir/etc/nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - $NGINX_LOG_DIR:/var/log/nginx
      - $dir/certs:/etc/ssl/certs
  apache:
    image: $APACHE_IMAGE" > docker-compose.yml
###################

docker-compose up -d
