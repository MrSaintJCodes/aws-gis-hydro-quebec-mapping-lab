openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout terraform/certs/lab.key \
  -out terraform/certs/lab.crt \
  -subj "/C=CA/ST=Quebec/L=Montreal/O=Lab/CN=localhost"
