# [CA Admin](https://github.com/sshambar/CA-admin)
*OpenSSL Certificate Authority Administration*

## Description

CA Admin is a Makefile based openssl Certificate Authority.  It's released
under the GNU GPL v3 (see LICENSE), and requires openssl and GNU make.

~~~~
make help

CA-admin manages your OpenSSL CA

make <cmd> [ NAME=<certname> ] [ KEYTYPE=rsa|ec ]...

Defaults:
  NAME = new
  KEYTYPE = ec
  KEY_OPTS(rsa) = -newkey rsa:2048
  KEY_OPTS(ec) = -newkey ec -pkeyopt ec_paramgen_curve:prime256v1
  CAROOT = /opt/devel/work/CA-admin
  CACONF = $(CAROOT)/openssl-ca.conf
  CATOP = $(CAROOT)/$(KEYTYPE)
  CASTATE = $(CATOP)/state

Optional parameters:
  REQ_SUBJ = ( <commanName> or CN=<name>,O=<org>,... )
  REQ_ALT_NAMES = ( <hostname> or DNS:<hostname>,IP:<ip>,... )
  CA_OPTS = ( extra options for ca command )

<cmd> can be:
  init   - Create & initialize ca directory.
  careq  - Create certificate request of CA.
  signca - Sign certificate request of CA.
  sign   - Sign certificate request.
  server - Create certificate request for server cert.
  client - Create certificate request for client cert.
  mixed  - Create certificate request for client/server.
  verify - Verify certificate.
  revoke - Revoke certificate.
  remove - Remove certificate, request and/or key.
  crl    - Generate CRL.
  print  - Print a ceritificate.
  printr - Print a request.CA-admin manages your OpenSSL CA
~~~~

Default keytype is prime256v1 elliptical curve, if `KEYTYPE=rsa` then
it's a 2048 RSA key.

Default expiration is year 2100 (set in `openssl-ca.conf`)

## Setup

### Inititalize the current directory as a Certificate Authority

~~~~
make init - initialize directories, db files
~~~~

Creates $(KEYTYPE) directory containing:
 - `certs` - signed certificates
 - `private` - keys (protected)
 - `crl` - revokation lists
 - `reqs` - certificate requests
 - `newcerts` - all certificates created (serial based)
 - `state` - contains serial, index.txt

### Create your new Certificate Authority certificate and key

~~~~
make signca - will prompt for CA name, and key passphase
~~~~

Creates in $(KEYTYPE):
 - `certs/ca.crt` - CA certificate
 - `private/ca.key` - CA key
 - `reqs/ca.csr` - CA request (created before self-sign)

Updates:
 - `state/index.txt` - CA added
 - `state/serial` - create random serial #
 - `newcerts/{SERIAL}.pem` - CA certificate (archive)

## Basic Usage

### Create a new certificate/key for a webserver (default NAME is *new*)

~~~~
make NAME=mycert server - will prompt for "CN"
~~~~

Creates in $(KEYTYPE):
 - `reqs/mycert.csr` - new certificate request
 - `private/mycert.key` - new key   

### Sign the certicate using the CA for webserver use

~~~~
make NAME=mycert sign - will prompt for CA key passphase
~~~~

Creates in $(KEYTYPE):
 - `certs/mycert.crt` - new signed certificate

Updates:
 - `state/index.txt` - mycert added
 - `state/serial` - updates serial #
 - `newcerts/{SERIAL}.pem` - mycert certificate (archive)

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

Creates in $(KEYTYPE):
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
