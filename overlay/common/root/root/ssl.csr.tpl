[req]
default_bits = 4096
default_md = sha256
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no
[req_distinguished_name]
C = US
ST = VA
L = SomeCity
O = MyCompany
OU = MyDivision
CN = $SERVER_DOMAIN
[v3_req]
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
IP.1 = $SERVER_DOMAIN