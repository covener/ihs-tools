#!/bin/sh

# Certs extracted from a GSKIT trace cannot be directly parsed by 'openssl x509'
# Author: covener

CERT=$1

sed -i -re 's/^\s+//g' $CERT
sed -i -re 's/^-+BEGIN Certificate Data-+/-----BEGIN CERTIFICATE-----/g' $CERT
sed -i -re 's/^-+END Certificate Data-+/-----END CERTIFICATE-----/g' $CERT

