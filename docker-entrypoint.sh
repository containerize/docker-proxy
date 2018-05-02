#!/bin/bash

set -x 

DOCKER_TLS_TEMP_PATH=/tmp/docker-tls

if [ ! -d "$DOCKER_TLS_TEMP_PATH" ]; then
    
    mkdir -p "$DOCKER_TLS_TEMP_PATH"
    echo "$DOCKER_TLS_PASSPHRASE" > "$DOCKER_TLS_TEMP_PATH/passphrasefile.txt"
    
    echo "generate ca"
    openssl genrsa -aes256 -passout file:"$DOCKER_TLS_TEMP_PATH/passphrasefile.txt" \
        -out "$DOCKER_TLS_TEMP_PATH/ca-key.pem" 4096
        
    openssl req -new -x509 -days 365 \
        -subj "/C=$DOCKER_TLS_COUNTRY/O=$DOCKER_TLS_ORG/CN=$DOCKER_TLS_HOST" \
        -passin file:"$DOCKER_TLS_TEMP_PATH/passphrasefile.txt" \
        -key "$DOCKER_TLS_TEMP_PATH/ca-key.pem" \
        -sha256 -out "$DOCKER_TLS_TEMP_PATH/ca.pem"
    
    echo "generate server certs"
    openssl genrsa -out "$DOCKER_TLS_TEMP_PATH/server-key.pem" 4096
    openssl req -subj "/CN=$DOCKER_TLS_HOST" -sha256 -new \
        -key "$DOCKER_TLS_TEMP_PATH/server-key.pem" \
        -out "$DOCKER_TLS_TEMP_PATH/server.csr"

    echo "subjectAltName = DNS:$DOCKER_TLS_DNS,IP:$DOCKER_TLS_HOST" >> "$DOCKER_TLS_TEMP_PATH/extfile.cnf"
    echo "extendedKeyUsage = serverAuth" >> "$DOCKER_TLS_TEMP_PATH/extfile.cnf"

    openssl x509 -req -days 365 \
        -passin file:"$DOCKER_TLS_TEMP_PATH/passphrasefile.txt" \
        -sha256 -in "$DOCKER_TLS_TEMP_PATH/server.csr" \
        -CA "$DOCKER_TLS_TEMP_PATH/ca.pem" \
        -CAkey "$DOCKER_TLS_TEMP_PATH/ca-key.pem" \
        -CAcreateserial \
        -out "$DOCKER_TLS_TEMP_PATH/server-cert.pem" \
        -extfile "$DOCKER_TLS_TEMP_PATH/extfile.cnf"

    echo "generate client certs"
    openssl genrsa -out "$DOCKER_TLS_TEMP_PATH/key.pem" 4096
    openssl req -subj "/CN=client" -new \
        -key "$DOCKER_TLS_TEMP_PATH/key.pem" \
        -out "$DOCKER_TLS_TEMP_PATH/client.csr"

    echo "extendedKeyUsage = clientAuth" >> "$DOCKER_TLS_TEMP_PATH/extfile.cnf"

    openssl x509 -req -days 365 \
        -passin file:"$DOCKER_TLS_TEMP_PATH/passphrasefile.txt" \
        -sha256 -in "$DOCKER_TLS_TEMP_PATH/client.csr" \
        -CA "$DOCKER_TLS_TEMP_PATH/ca.pem" \
        -CAkey "$DOCKER_TLS_TEMP_PATH/ca-key.pem" \
        -CAcreateserial \
        -out "$DOCKER_TLS_TEMP_PATH/cert.pem" \
        -extfile "$DOCKER_TLS_TEMP_PATH/extfile.cnf"
    
    rm -v "$DOCKER_TLS_TEMP_PATH/client.csr"
    rm -v "$DOCKER_TLS_TEMP_PATH/server.csr"
    
fi

DOCKER_TLS_SERVER_PATH=/etc/nginx/docker
if [ ! -d "$DOCKER_TLS_SERVER_PATH/tls" ]; then
    mkdir -p "$DOCKER_TLS_SERVER_PATH/tls"
    cp "$DOCKER_TLS_TEMP_PATH/ca.pem" "$DOCKER_TLS_SERVER_PATH/tls/ca.pem"
    cp "$DOCKER_TLS_TEMP_PATH/server-cert.pem" "$DOCKER_TLS_SERVER_PATH/tls/server-cert.pem"
    cp "$DOCKER_TLS_TEMP_PATH/server-key.pem" "$DOCKER_TLS_SERVER_PATH/tls/server-key.pem"

    chmod 0400 "$DOCKER_TLS_SERVER_PATH/tls/ca.pem"
    chmod 0400 "$DOCKER_TLS_SERVER_PATH/tls/server-cert.pem"
    chmod 0400 "$DOCKER_TLS_SERVER_PATH/tls/server-key.pem"
fi

DOCKER_TLS_CLIENT_PATH=/home/docker
if [ ! -d "$DOCKER_TLS_CLIENT_PATH/.docker" ]; then
    mkdir -p "$DOCKER_TLS_CLIENT_PATH/.docker"
    cp "$DOCKER_TLS_TEMP_PATH/ca.pem" "$DOCKER_TLS_CLIENT_PATH/.docker/ca.pem"
    cp "$DOCKER_TLS_TEMP_PATH/cert.pem" "$DOCKER_TLS_CLIENT_PATH/.docker/cert.pem"
    cp "$DOCKER_TLS_TEMP_PATH/key.pem" "$DOCKER_TLS_CLIENT_PATH/.docker/key.pem"

    chmod 0400 "$DOCKER_TLS_CLIENT_PATH/.docker/ca.pem"
    chmod 0400 "$DOCKER_TLS_CLIENT_PATH/.docker/cert.pem"
    chmod 0400 "$DOCKER_TLS_CLIENT_PATH/.docker/key.pem"
fi

exec $@