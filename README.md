# [CA Admin](https://github.com/sshambar/CA-admin)
*OpenSSL Certificate Authority Administration*

## Description

CA Admin is a Makefile based openssl Certificate Authority.  It's released
under the GNU GPL v3 (see LICENSE), and requires openssl and GNU make.

~~~~
make help

CA-admin manages your OpenSSL CA

init   - Create & initialize ca directory.
careq  - Create certificate request of CA.
cacert - Sign certificate request of CA.
req    - Create certificate request.
cert   - Sign certificate request.
server - Sign certificate request as server cert.
client - Sign certificate request as client cert.
mixed  - Sign certificate request as client/server.
verify - Verify certificate.
revoke - Revoke certificate.
crl    - Generate CRL.
print  - Print a ceritificate.
~~~~

By default, the CA will use the prime256v1 elliptical curve key type.
To use RSA, update Makefile with `KEYOPTS = -newkey rsa:2048`

## Setup

### Inititalize the current directory as a Certificate Authority

~~~~
make init - initialize directories, db files
~~~~

Creates:
 - `certs` - signed certificates
 - `private` - keys (protected)
 - `crl` - revokation lists
 - `reqs` - certificate requests
 - `newcerts` - all certificates created (hash based)
 - `state` - contains serial, index.txt

### Create your new Certificate Authority certificate and key

~~~~
make cacert - will prompt for CA name, and key passphase
~~~~

Creates:
 - `certs/ca.crt` - CA certificate
 - `private/ca.key` - CA key
 - `reqs/ca.csr` - CA request (created before self-sign)

Updates:
 - `state/index.txt` - CA added
 - `state/serial` - create random serial #
 - `newcerts/{HASH}.pem` - CA certificate (archive)

## Basic Usage

### Create a new certificate request and key

~~~~
make NAME=mycert req - will prompt for "CN"
~~~~

Creates:
 - `reqs/mycert.csr` - new certificate request
 - `private/mycert.key` - new key   

### Sign the certicate using the CA for webserver use

~~~~
make NAME=mycert server - will prompt for CA key passphase
~~~~

Creates:
 - `certs/mycert.crt` - new signed certificate

Updates:
 - `state/index.txt` - mycert added
 - `state/serial` - updates serial #
 - `newcerts/{HASH}.pem` - mycert certificate (archive)

### Display new certificate details

~~~~
make NAME=mycert print
~~~~
 
### Verify new certificate using CA

~~~~
make NAME=mycert verify
~~~~

### Revoke new certificate, and create a new CRL

~~~~
make NAME=mycert revoke - will prompt for CA key passphrase
~~~~

Creates:
 - `crt/crl01.pem` - creates new revokation list
 - `crt/crl.pem` - link to new crl01.pem

Updates:
 - `state/index.txt` - mycert marked revoked
 - `state/crlnumber` - updates crl #

Steps may be skipped, for example to create certificate request, and then
sign it with the CA for client use in one step, use:

~~~~
make NAME=mytest client
~~~~
