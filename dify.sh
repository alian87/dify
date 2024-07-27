#!/bin/bash

# Fazendo as perguntas e armazenando as respostas em variáveis
read -p "Me informe sua url de acesso web sem http:// ou https://? " web_url
read -p "Me informe a url de acesso a api sem http:// ou https://? " api_url
read -p "Me informe a senha de admin para o dify? " senha_dify
read -p "Me informe seu melhor e-mail? " email

# Atualizando e instalando pacotes necessários
apt update
apt upgrade -y
apt install -y nginx certbot python3-certbot-nginx ca-certificates curl

# Configurando Docker
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Configurando Nginx para a API
cat <<EOL > /etc/nginx/sites-available/dify-api
server {
  server_name $api_url;
  location / {
    proxy_pass http://127.0.0.1:5001;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
EOL

# Configurando Nginx para a Web
cat <<EOL > /etc/nginx/sites-available/dify-web
server {
  server_name $web_url;
  location / {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade \$http_upgrade;
    proxy_set_header Connection 'upgrade';
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
    proxy_set_header X-Forwarded-Proto \$scheme;
    proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    proxy_cache_bypass \$http_upgrade;
  }
}
EOL

# Ativando as configurações do nginx
ln -s /etc/nginx/sites-available/dify-api /etc/nginx/sites-enabled
ln -s /etc/nginx/sites-available/dify-web /etc/nginx/sites-enabled
service nginx restart

# Gerando os certificados SSL
certbot --nginx --email $email --redirect --agree-tos --non-interactive -d $api_url -d $web_url

# Criando o diretório e o arquivo docker-compose.yml
mkdir -p /opt/dify
cat <<EOL > /opt/dify/docker-compose.yml
services:
  api:
    image: 'langgenius/dify-api:latest'
    restart: always
    ports:
      - '5001:5001'
    environment:
      MODE: api
      LOG_LEVEL: INFO
      SECRET_KEY: sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U
      CONSOLE_WEB_URL: \$CONSOLE_WEB_URL
      INIT_PASSWORD: \$INIT_PASSWORD
      CONSOLE_API_URL: \$CONSOLE_API_URL
      SERVICE_API_URL: \$CONSOLE_API_URL
      APP_WEB_URL: \$CONSOLE_WEB_URL
      FILES_URL: ''
      MIGRATION_ENABLED: 'true'
      DB_USERNAME: postgres
      DB_PASSWORD: difyai123456
      DB_HOST: db
      DB_PORT: 5432
      DB_DATABASE: dify
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_USERNAME: ''
      REDIS_PASSWORD: difyai123456
      REDIS_USE_SSL: 'false'
      REDIS_DB: 0
      CELERY_BROKER_URL: 'redis://:difyai123456@redis:6379/1'
      WEB_API_CORS_ALLOW_ORIGINS: '*'
      CONSOLE_CORS_ALLOW_ORIGINS: '*'
      STORAGE_TYPE: local
      STORAGE_LOCAL_PATH: storage
      S3_ENDPOINT: dify
      S3_BUCKET_NAME: dify
      S3_ACCESS_KEY: 12345
      S3_SECRET_KEY: 12345
      AZURE_BLOB_ACCOUNT_NAME: difyai
      AZURE_BLOB_ACCOUNT_KEY: difyai
      AZURE_BLOB_CONTAINER_NAME: difyai-container
      AZURE_BLOB_ACCOUNT_URL: 'https://<your_account_name>.blob.core.windows.net'
      VECTOR_STORE: weaviate
      WEAVIATE_ENDPOINT: 'http://weaviate:8080'
      WEAVIATE_API_KEY: WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih
      QDRANT_URL: 'http://qdrant:6333'
      QDRANT_API_KEY: difyai123456
      QDRANT_CLIENT_TIMEOUT: 20
      MILVUS_HOST: 127.0.0.1
      MILVUS_PORT: 19530
      MILVUS_USER: root
      MILVUS_PASSWORD: Milvus
      MILVUS_SECURE: 'false'
      MAIL_TYPE: ''
      MAIL_DEFAULT_SEND_FROM: 'YOUR EMAIL FROM (eg: no-reply <no-reply@dify.ai>)'
      SMTP_SERVER: ''
      SMTP_PORT: 587
      SMTP_USERNAME: ''
      SMTP_PASSWORD: ''
      SMTP_USE_TLS: 'true'
      RESEND_API_KEY: ''
      RESEND_API_URL: 'https://api.resend.com'
      SENTRY_DSN: ''
      SENTRY_TRACES_SAMPLE_RATE: 1.0
      SENTRY_PROFILES_SAMPLE_RATE: 1.0
      CODE_EXECUTION_ENDPOINT: 'http://sandbox:8194'
      CODE_EXECUTION_API_KEY: dify-sandbox
      CODE_MAX_NUMBER: 9223372036854775807
      CODE_MIN_NUMBER: -9223372036854775808
      CODE_MAX_STRING_LENGTH: 80000
      TEMPLATE_TRANSFORM_MAX_LENGTH: 80000
      CODE_MAX_STRING_ARRAY_LENGTH: 30
      CODE_MAX_OBJECT_ARRAY_LENGTH: 30
      CODE_MAX_NUMBER_ARRAY_LENGTH: 1000
    depends_on:
      - db
      - redis
    volumes:
      - './volumes/app/storage:/app/api/storage'

  worker:
    image: 'langgenius/dify-api:latest'
    restart: always
    environment:
      MODE: worker
      LOG_LEVEL: INFO
      SECRET_KEY: sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U
      DB_USERNAME: postgres
      DB_PASSWORD: difyai123456
      DB_HOST: db
      DB_PORT: 5432
      DB_DATABASE: dify
      REDIS_HOST: redis
      REDIS_PORT: 6379
      REDIS_USERNAME: ''
      REDIS_PASSWORD: difyai123456
      REDIS_USE_SSL: 'false'
      REDIS_DB: 0
      CELERY_BROKER_URL: 'redis://:difyai123456@redis:6379/1'
      VECTOR_STORE: weaviate
      WEAVIATE_ENDPOINT: 'http://weaviate:8080'
      WEAVIATE_API_KEY: WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih
      QDRANT_URL: 'http://qdrant:6333'
      QDRANT_API_KEY: difyai123456
      QDRANT_CLIENT_TIMEOUT: 20
      MILVUS_HOST: 127.0.0.1
      MILVUS_PORT: 19530
      MILVUS_USER: root
      MILVUS_PASSWORD: Milvus
      MILVUS_SECURE: 'false'
      MAIL_TYPE: ''
      MAIL_DEFAULT SEND_FROM: 'YOUR EMAIL FROM (eg: no-reply <no-reply@dify.ai>)'
      SMTP_SERVER: ''
      SMTP_PORT: 587
      SMTP_USERNAME: ''
      SMTP_PASSWORD: ''
      SMTP_USE_TLS: 'true'
      RESEND_API_KEY: ''
      RESEND_API_URL: 'https://api.resend.com'
    depends_on:
      - db
      - redis
    volumes:
      - './volumes/app/storage:/app/api/storage'

  web:
    image: 'langgenius/dify-web:latest'
    restart: always
    ports:
      - '3000:3000'
    environment:
      EDITION: SELF_HOSTED
      CONSOLE_API_URL: \$CONSOLE_API_URL
      APP_API_URL: \$CONSOLE_API_URL
      SENTRY_DSN: ''
  db:
    image: 'postgres:15-alpine'
    restart: always
    environment:
      PGUSER: postgres
      POSTGRES_PASSWORD: difyai123456
      POSTGRES_DB: dify
      PGDATA: /var/lib/postgresql/data/pgdata
    volumes:
      - './volumes/db/data:/var/lib/postgresql/data'
    healthcheck:
      test:
        - CMD
        - pg_isready
      interval: 1s
      timeout: 3s
      retries: 30
  redis:
    image: 'redis:6-alpine'
    restart: always
    volumes:
      - './volumes/redis/data:/data'
    command: 'redis-server --requirepass difyai123456'
    healthcheck:
      test:
        - CMD
        - redis-cli
        - ping
  weaviate:
    image: 'semitechnologies/weaviate:1.19.0'
    restart: always
    volumes:
      - './volumes/weaviate:/var/lib/weaviate'
    environment:
      QUERY_DEFAULTS_LIMIT: 25
      AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED: 'false'
      PERSISTENCE_DATA_PATH: /var/lib/weaviate
      DEFAULT VECTORIZER_MODULE: none
      CLUSTER_HOSTNAME: node1
      AUTHENTICATION_APIKEY_ENABLED: 'true'
      AUTHENTICATION_APIKEY_ALLOWED_KEYS: WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih
      AUTHENTICATION_APIKEY_USERS: hello@dify.ai
      AUTHORIZATION_ADMINLIST_ENABLED: 'true'
      AUTHORIZATION_ADMINLIST_USERS: hello@dify.ai
  sandbox:
    image: 'langgenius/dify-sandbox:latest'
    restart: always
    cap_add:
      - SYS_ADMIN
    environment:
      API_KEY: dify-sandbox
      GIN_MODE: release
      WORKER_TIMEOUT: 15
EOL

# Criando o arquivo .env
cat <<EOL > /opt/dify/.env
CONSOLE_WEB_URL=https://$web_url
CONSOLE_API_URL=https://$api_url
INIT_PASSWORD=$senha_dify
EOL

# Executando os comandos docker
cd /opt/dify
docker compose pull
docker compose up -d

# Imprimindo os dados de acesso
echo "***********************************************************************************************"
echo "Instalação concluída"
echo "Aguarde ao menos 1 minuto antes de acessar o sistema para dar tempo dos serviços inicializarem."
echo ""
echo "Seus dados de acesso são:"
echo "URL de acesso web: https://$web_url"
echo "Senha: $senha_dify"
