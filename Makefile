#
# CA Admin - OpenSSL Certificate Authority Administration
#
# Version: 2.0.0
# Author: Scott Shambarger <devel@shambarger.net>
#
# Copyright (C) 2018-2022 Scott Shambarger
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# Refs:
#  Good CA howto: https://jamielinux.com/docs/openssl-certificate-authority/
#
space := $(NULL) $(NULL)
myescape = $(subst $(space),\$(space),$(1))

# RSA defaults
override DEF_RSA_KEY_OPTS = -newkey rsa:2048
# EC defaults
override DEF_EC_KEY_OPTS = -newkey ec -pkeyopt ec_paramgen_curve:prime256v1

# param defaults:
override DEF_KEYTYPE = ec
override DEF_KEYOPTS := $(DEF_RSA_KEYOPTS)
override DEF_NAME = new
# CAROOT must be an absolute path
CAROOT := $(call myescape,$(PWD))

override DEF_CACONF = $(CAROOT)/openssl-ca.conf
override DEF_CATOP = $(CAROOT)/$(KEYTYPE)
override DEF_CASTATE = $(CATOP)/state

# validate NAME
NAME := $(DEF_NAME)
ifeq '$(NAME)' ''
$(error 'NAME cannot be empty')
endif

# validate KEYTYPE
KEYTYPE := $(DEF_KEYTYPE)
ifeq '$(KEYTYPE)' 'rsa'
	KEY_OPTS := $(DEF_RSA_KEY_OPTS)
else ifeq '$(KEYTYPE)' 'ec'
	KEY_OPTS := $(DEF_EC_KEY_OPTS)
else ifeq '$(KEYTYPE)' ''
$(error 'KEYTYPE cannot be empty')
else
$(error 'Unknown KEYTYPE $(KEYTYPE) (try "make help")')
endif

# validate KEY_OPTS
ifeq '$(KEY_OPTS)' ''
$(error 'KEY_OPTS cannot be empty')
endif

CACONF := $(DEF_CACONF)
CATOP := $(DEF_CATOP)
CASTATE := $(DEF_CASTATE)

# the rest are relative to $(CATOP)

# these should match entries in $(CACONF)
REQS_DIR = $(CATOP)/reqs
PRIV_DIR = $(CATOP)/private
CERTS_DIR = $(CATOP)/certs

CA_CERT_REQ_FILE = $(REQS_DIR)/ca.csr
CA_CERT_KEY_FILE = $(PRIV_DIR)/ca.key
CA_CERT_FILE = $(CERTS_DIR)/ca.crt

CERT_REQ_FILE = $(REQS_DIR)/$(NAME).csr
CERT_KEY_FILE = $(PRIV_DIR)/$(NAME).key
CERT_FILE = $(CERTS_DIR)/$(NAME).crt

override EXT_FILE = $(CATOP)/tmp.conf
REQ_OPTS = subjectKeyIdentifier=hash 
REQ_OPTS += keyUsage=critical,digitalSignature,keyEncipherment

CRL_LINK = $(CATOP)/crl/crl.pem

# prob shouldn't be overridden
override OPENSSL = openssl
override REQ = $(OPENSSL) req
override CA = $(OPENSSL) ca -config $(CACONF) -name CA_$(KEYTYPE)
override VERIFY = $(OPENSSL) verify
override X509 = $(OPENSSL) x509

override REQ_DEPS = $(CACONF) $(REQS_DIR) $(PRIV_DIR)
override CA_DEPS = $(REQ_DEPS) $(CERTS_DIR) $(CATOP)/crl $(CATOP)/newcerts
override CA_DEPS += $(CASTATE)/serial $(CASTATE)/index.txt

.SUFFIXES: .pem .crt .p12
.PHONY: help debug init careq signca sign verify revoke revoke_cert crl remove
.PHONY: hasca hascert hasreq client server mixed print printr 

help:
	@echo 'CA-admin manages your OpenSSL CA'
	@echo
	@echo 'make <cmd> [ NAME=<certname> ] [ KEYTYPE=rsa|ec ]'
	@echo
	@echo 'Defaults:'
	@echo '  NAME = $(value DEF_NAME)'
	@echo '  KEYTYPE = $(value DEF_KEYTYPE)'
	@echo '  KEY_OPTS = $(value DEF_KEY_OPTS)'
	@echo '  CAROOT = $(value CAROOT)'
	@echo '  CACONF = $(value DEF_CACONF)'
	@echo '  CATOP = $(value DEF_CATOP)'
	@echo '  CASTATE = $(value DEF_CASTATE)'
	@echo
	@echo '<cmd> can be:'
	@echo '  init   - Create & initialize ca directory.'
	@echo '  careq  - Create certificate request of CA.'
	@echo '  signca - Sign certificate request of CA.'
	@echo '  sign   - Sign certificate request.'
	@echo '  server - Create certificate request for server cert.'
	@echo '  client - Create certificate request for client cert.'
	@echo '  mixed  - Create certificate request for client/server.'
	@echo '  verify - Verify certificate.'
	@echo '  revoke - Revoke certificate.'
	@echo '  crl    - Generate CRL.'
	@echo '  print  - Print a ceritificate.'
	@echo '  printr - Print a request.'

debug:
	@echo 'NAME = $(NAME)'
	@echo 'KEYTYPE = $(KEYTYPE)'
	@echo 'KEY_OPTS = $(KEY_OPTS)'
	@echo 'CACONF = $(CACONF)'
	@echo 'CATOP = $(CATOP)'
	@echo 'CASTATE = $(CASTATE)'
	@echo 'CA_CERT_REQ_FILE = $(CA_CERT_REQ_FILE)'
	@echo 'CA_CERT_KEY_FILE = $(CA_CERT_KEY_FILE)'
	@echo 'CA_CERT_FILE = $(CA_CERT_FILE)'
	@echo 'CERT_REQ_FILE = $(CERT_REQ_FILE)'
	@echo 'CERT_KEY_FILE = $(CERT_KEY_FILE)'
	@echo 'CERT_FILE = $(CERT_FILE)'

.pem.crt:
	$(X509) -in $< -out '$@'

.pem.p12:
	$(OPENSSL) pkcs12 -export -clcerts -in '$<' -inkey $(CERT_KEY_FILE) -out '$@'

init: | $(CA_DEPS)

## CA config file
$(CACONF):
	@echo 'NOTE: You will need to create $(CACONF)'
	@false

$(CASTATE) $(CASTATE)/index.txt:
	mkdir -p -m 755 $(CASTATE)
	touch '$@'

$(CASTATE)/crlnumber: | $(CASTATE)
	@echo 01 > '$@'

$(CASTATE)/serial: | $(CASTATE)
	$(OPENSSL) rand -hex 8 > '$@'

## Creating new CA
$(CATOP):
	@echo 'Creating new CA directory'
	mkdir -p -m 755 '$@'

$(REQS_DIR) $(CERTS_DIR) $(CATOP)/crl $(CATOP)/newcerts: | $(CATOP)
	mkdir -p -m 755 '$@'

$(PRIV_DIR): | $(CATOP)
	mkdir -p -m 700 '$@'

careq: $(CA_CERT_KEY_FILE) $(CA_CERT_REQ_FILE)

$(CA_CERT_REQ_FILE) $(CA_CERT_KEY_FILE): | $(REQ_DEPS)
	$(REQ) -new -config $(CACONF) \
		$(KEY_OPTS) \
		-keyout $(CA_CERT_KEY_FILE) \
		-out $(CA_CERT_REQ_FILE)
	chmod 600 $(CA_CERT_KEY_FILE) $(CA_CERT_REQ_FILE)

signca: $(CA_CERT_FILE)

$(CA_CERT_FILE): $(CA_CERT_REQ_FILE) $(CA_CERT_KEY_FILE) | $(CA_DEPS)
	$(CA) -batch \
		-keyfile $(CA_CERT_KEY_FILE) \
		-selfsign \
		-extensions v3_ca \
		-out '$@' \
		-infiles $(CA_CERT_REQ_FILE)
	@chmod 644 '$@'

hasca:
	@[[ -f $(CA_CERT_FILE) ]] || { echo 'Missing CA cert: $(CA_CERT_FILE)'; false; }

hascert:
	@[[ -f $(CERT_FILE) ]] || { echo 'Missing cert file: $(CERT_FILE)'; false; }

hasreq:
	@[[ -f $(CERT_REQ_FILE) ]] || { echo 'Missing request file: $(CERT_REQ_FILE)'; false; }


# as of openssl v1.1.1l, -addext doesn't work (adds randomly to -reqexts...)
# (also, -text prints something different that whats in req produced)
# so we create a temporary config
$(CERT_REQ_FILE) $(CERT_KEY_FILE): | hasca $(REQ_DEPS)
	@[[ $$REQ_CN ]] || read -p "Enter CommonName: " REQ_CN; \
	rm -f $(EXT_FILE); \
	echo "[ req ]" >> $(EXT_FILE) || exit; \
	echo "default_md = sha256" >> $(EXT_FILE); \
	echo "req_extensions = v3_req" >> $(EXT_FILE); \
	echo "distinguished_name = req_name" >> $(EXT_FILE); \
	echo "[ req_name ]" >> $(EXT_FILE); \
	echo "commonName = Common Name" >> $(EXT_FILE); \
	echo "[ v3_req ]" >> $(EXT_FILE); \
	for item in $(REQ_OPTS); do \
	  echo "$$item" >> $(EXT_FILE) || exit; \
	done; \
	$(REQ) -new -batch -config $(EXT_FILE) \
		$(KEY_OPTS) \
		-subj "/CN=$${REQ_CN}/" \
		-nodes \
		-keyout $(CERT_KEY_FILE) \
		-out $(CERT_REQ_FILE)
	@rm -f $(EXT_FILE)
	chmod 600 $(CERT_KEY_FILE) $(CERT_REQ_FILE)

client: REQ_OPTS += extendedKeyUsage=clientAuth
client: $(CERT_REQ_FILE) | printr

server: REQ_OPTS += extendedKeyUsage=serverAuth
server: REQ_OPTS += subjectAltName=DNS:$${REQ_CN}
server: $(CERT_REQ_FILE) | printr

mixed: REQ_OPTS += extendedKeyUsage=serverAuth,clientAuth
mixed: REQ_OPTS += subjectAltName=DNS:$${REQ_CN}
mixed: $(CERT_REQ_FILE) | printr

$(CERT_FILE): $(CERT_REQ_FILE) | $(CA_DEPS)
	$(CA) -out '$@' $(EXT_OPTS) -infiles $(CERT_REQ_FILE)
	@[[ -s $@ ]] || { $(RM) '$@'; false; }
	@chmod 644 '$@'
	@echo -ne '\033[1;32m'
	@echo -n 'Certificate: $@'
	@echo -e '\033[0m'

sign: $(CERT_FILE)

verify: hasca hascert
	$(VERIFY) -CAfile $(CA_CERT_FILE) $(CERT_FILE)

crl: $(CASTATE)/crlnumber | $(CA_DEPS) $(CATOP)/crl
	$(eval CRL_FILE := $(CATOP)/crl/crl$(shell cat $(CASTATE)/crlnumber).pem)
	$(CA) -gencrl -out $(CRL_FILE)
	chmod 644 $(CRL_FILE)
	ln -sf $(CRL_FILE) $(CRL_LINK)
	@echo -ne '\033[1;32m'
	@echo -n 'CRL is in $(CRL_FILE)'
	@echo -e '\033[0m'

revoke_cert: $(CERT_FILE) | $(CA_DEPS)
	$(CA) -revoke $(CERT_FILE)

revoke: revoke_cert crl

print: hascert
	@$(X509) -noout -text -in $(CERT_FILE)

printr: hasreq
	@$(REQ) -noout -text -in $(CERT_REQ_FILE)

remove:
	@read -p "Removing cert/req/key for $(NAME), are you sure? (y/N): "; \
	[[ $$REPLY =~ y|Y ]]
	$(RM) \
		$(CERT_REQ_FILE) \
		$(CERT_KEY_FILE) \
		$(CERT_FILE)
