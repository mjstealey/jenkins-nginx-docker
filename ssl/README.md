# SSL - certificates for development

SSL development certificates are included in this repository for demonstration purposes and should be replaced with genuine certificates in production.

- `privkey.pem`  : the private key for your certificate.
- `fullchain.pem`: the certificate file used in most server software (copy of chain.pem for development purposes).
- `chain.pem`    : used for OCSP stapling in Nginx >=1.3.7.
- `pubkey.pem`   : public key derived from privkey.pem for JWT work

These certificates are self signed, and as such not reckognized by any CA. Do not use this for anything beyond local development (Never use in production)

### Generate `privkey.pem`, `fullchain.pem`, `chain.pem`

Certificate generation based on Let's Encrypt [certificates for localhost](https://letsencrypt.org/docs/certificates-for-localhost/).

```
openssl req -x509 -outform pem -out chain.pem -keyout privkey.pem \
  -newkey rsa:4096 -nodes -sha256 -days 3650 \
  -subj '/CN=localhost' -extensions EXT -config <( \
   printf "[dn]\nCN=localhost\n[req]\ndistinguished_name = dn\n[EXT]\nsubjectAltName=DNS:localhost\nkeyUsage=digitalSignature\nextendedKeyUsage=serverAuth")
cat chain.pem > fullchain.pem
```

### Generate `pubkey.pem`

JWT's are signed using the private key `privkey.pem`. The public key `pubkey.pem` is used to verify the signature.

```
openssl rsa -in privkey.pem -outform pem -pubout -out pubkey.pem
```

### Reference

Nginx configuration reference: [https://www.nginx.com/blog/using-free-ssltls-certificates-from-lets-encrypt-with-nginx/](https://www.nginx.com/blog/using-free-ssltls-certificates-from-lets-encrypt-with-nginx/)
