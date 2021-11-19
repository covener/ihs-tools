#!/bin/sh -x

# This script copies a letencrypt-downloaded certificate, chain, and key into a 
# GSKit-compatible CMS file.

DOMAIN=www.example.com
IHSROOT=$HOME/ihs90

cd /etc/letsencrypt/live/$DOMAIN
echo "Fetching root letsencrypt CA"
wget -q https://letsencrypt.org/certs/isrgrootx1.pem -O $PWD/isrgrootx1.pem

ls -lart
for ext in rdb kdb crl sth; do
  rm -f $DOMAIN.$ext
done
ls -lart

echo "Convert letsencrypt files to GSKit-compatible P12"
openssl pkcs12 -export -inkey privkey.pem -in cert.pem  -out $DOMAIN.p12 -certfile chain.pem -name "$DOMAIN" 

echo "Converting p12->cms"
ls -lart
$IHSROOT/bin/gskcapicmd -keydb -convert -db $DOMAIN.p12 -new_db $DOMAIN.kdb -new_format cms
ls -lart
echo "Stashing password"
$IHSROOT/bin/gskcapicmd -keydb -stashpw -db $DOMAIN.kdb

echo "Adding root letsencrypt CA"
$IHSROOT/bin/gskcapicmd -cert -add -db $DOMAIN.kdb -stashed -file /etc/letsencrypt/live/$DOMAIN/isrgrootx1.pem -label isrgrootx1

$IHSROOT/bin/gskcapicmd -cert -validate -db $DOMAIN.kdb -stashed  -label "$DOMAIN"
$IHSROOT/bin/gskcapicmd -cert -list -db $DOMAIN.kdb -stashed 

rm -f $DOMAIN.p12

