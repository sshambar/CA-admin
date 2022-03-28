#
# CA Admin - OpenSSL Certificate Authority Administration
#
# Version: 1.0.0
# Author: Scott Shambarger <devel@shambarger.net>
#
# Copyright (C) 2018 Scott Shambarger
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
#  Inspired by: https://gist.github.com/ab/4570034
#  Good CA howto: https://jamielinux.com/docs/openssl-certificate-authority/
#
space := $(NULL) $(NULL)
myescape = $(subst $(space),\$(space),$(1))
# CATOP must be an absolute path
CATOP = $(call myescape,$(PWD))
CACONF = $(CATOP)/openssl-ca.conf
CASTATE = $(CATOP)/state

KEYOPTS = -newkey ec -pkeyopt ec_paramgen_curve:prime256v1
#KEYOPTS = -newkey rsa:2048

OPENSSL = openssl
DAYS = -days 3650
CADAYS = -days 3650
CRLDAYS = -crldays 3650
REQ = $(OPENSSL) req -config $(CACONF)
REQ_DEPS = $(CATOP)/reqs $(CATOP)/private $(CACONF)
CA = $(OPENSSL) ca -config $(CACONF)
# these should match $(CACONF) entries
CA_DEPS = $(CATOP)/certs $(CATOP)/crl $(CATOP)/private $(CATOP)/newcerts
CA_DEPS += $(CASTATE)/serial $(CASTATE)/index.txt $(CACONF)
VERIFY = $(OPENSSL) verify
X509 = $(OPENSSL) x509

CA_CERT_REQ_FILE = $(CATOP)/reqs/ca.csr
CA_CERT_KEY_FILE = $(CATOP)/private/ca.key
CA_CERT_FILE = $(CATOP)/certs/ca.crt

CRL_LINK = $(CATOP)/crl/crl.pem

CERT_USAGE = serverAuth, clientAuth

ifneq '$(NAME)' ''
	CERT_REQ_FILE = $(CATOP)/reqs/$(NAME).csr
	CERT_KEY_FILE = $(CATOP)/private/$(NAME).key
	CERT_FILE = $(CATOP)/certs/$(NAME).crt
else
	CERT_REQ_FILE = $(CATOP)/reqs/new.csr
	CERT_KEY_FILE = $(CATOP)/private/new.key
	CERT_FILE = $(CATOP)/certs/new.crt
endif

.SUFFIXES: .pem .crt .p12
.PHONY: help debug init careq cacert req cert verify revoke crl clean
.PHONY: client server mixed print new_ext server_ext revoke_cert

help:
	@echo 'CA-admin manages your OpenSSL CA'
	@echo ''
	@echo 'init   - Create & initialize ca directory.'
	@echo 'careq  - Create certificate request of CA.'
	@echo 'cacert - Sign certificate request of CA.'
	@echo 'req    - Create certificate request.'
	@echo 'cert   - Sign certificate request.'
	@echo 'server - Sign certificate request as server cert.'
	@echo 'client - Sign certificate request as client cert.'
	@echo 'mixed  - Sign certificate request as client/server.'
	@echo 'verify - Verify certificate.'
	@echo 'revoke - Revoke certificate.'
	@echo 'crl    - Generate CRL.'
	@echo 'print  - Print a ceritificate.'
	@echo ''
	@echo 'Configuration:'
	@echo 'CATOP:  $(CATOP)'
	@echo 'CACONF: $(CACONF)'
	@echo 'CASTATE: $(CASTATE)'

debug:
	@echo 'CATOP:  $(CATOP)'
	@echo 'CACONF: $(CACONF)'
	@echo 'CASTATE: $(CASTATE)'
	@echo 'NAME: $(NAME)'
	@echo 'CERT_REQ_FILE: $(CERT_REQ_FILE)'
	@echo 'CERT_KEY_FILE: $(CERT_KEY_FILE)'
	@echo 'CERT_FILE:     $(CERT_FILE)'

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
	echo 01 > '$@'

$(CASTATE)/serial: | $(CASTATE)
	$(OPENSSL) rand -hex 8 > '$@'

## Creating new CA
$(CATOP):
	@echo 'Creating new CA directory'
	mkdir -p -m 755 '$@'

$(CATOP)/reqs $(CATOP)/certs $(CATOP)/crl $(CATOP)/newcerts: | $(CATOP)
	mkdir -p -m 755 '$@'

$(CATOP)/private: | $(CATOP)
	mkdir -p -m 700 '$@'

careq: $(CA_CERT_KEY_FILE) $(CA_CERT_REQ_FILE)

$(CA_CERT_REQ_FILE): | $(CATOP)/reqs
$(CA_CERT_KEY_FILE): | $(CATOP)/private
$(CA_CERT_REQ_FILE) $(CA_CERT_KEY_FILE): | $(REQ_DEPS)
	$(REQ) -new \
		$(KEYOPTS) \
		-keyout $(CA_CERT_KEY_FILE) \
		-out $(CA_CERT_REQ_FILE)
	@chmod 600 $(CA_CERT_KEY_FILE) $(CA_CERT_REQ_FILE)

cacert: $(CA_CERT_FILE)

$(CA_CERT_FILE): $(CA_CERT_REQ_FILE) $(CA_CERT_KEY_FILE) | $(CA_DEPS)
	$(CA) $(CADAYS) -batch \
		-keyfile $(CA_CERT_KEY_FILE) -selfsign \
		-extensions v3_ca \
		-out '$@' \
		-infiles $(CA_CERT_REQ_FILE)
	@chmod 644 '$@'

req: $(CERT_KEY_FILE) $(CERT_REQ_FILE)

$(CERT_REQ_FILE): | $(CATOP)/reqs
$(CERT_KEY_FILE): | $(CATOP)/private
$(CERT_REQ_FILE) $(CERT_KEY_FILE): | $(REQ_DEPS)
	$(REQ) -new \
		$(KEYOPTS) \
		-nodes -keyout $(CERT_KEY_FILE) \
		-out $(CERT_REQ_FILE) $(DAYS)
	@chmod 600 $(CERT_KEY_FILE) $(CERT_REQ_FILE)

new_ext: cacert $(CERT_REQ_FILE) | $(CASTATE)
	$(eval EXT_OPTS = -extfile $(CASTATE)/exts.conf)
	@echo 'subjectKeyIdentifier = hash' > $(CASTATE)/exts.conf
	@echo 'authorityKeyIdentifier = keyid:always' >> $(CASTATE)/exts.conf
	@echo 'keyUsage = critical, digitalSignature, keyEncipherment' >> $(CASTATE)/exts.conf
	@echo 'extendedKeyUsage = $(CERT_USAGE)' >> $(CASTATE)/exts.conf

client: CERT_USAGE = clientAuth
client: new_ext cert

server_ext: new_ext
	$(eval CN := $(shell $(OPENSSL) req -in $(CERT_REQ_FILE) -noout -text | awk -e '/Subject: CN = / { sub(".* CN = ",""); sub(" ,.*", ""); print $0 }'))
	@{ [ -n '$(CN)' ] && [[ '$(CERT_USAGE)' =~ serverAuth ]]; } && echo 'subjectAltName = DNS:$(CN)' >> $(CASTATE)/exts.conf || :

server: CERT_USAGE = serverAuth
server: server_ext cert

mixed: CERT_USAGE = clientAuth, serverAuth
mixed: server_ext cert

cert: cacert $(CERT_FILE)

$(CERT_FILE): $(CERT_REQ_FILE) | $(CA_DEPS)
	$(CA) -out '$@' $(EXT_OPTS) -infiles $(CERT_REQ_FILE)
	@[ -s '$@' ] || { $(RM) '$@'; false; }
	@chmod 644 '$@'
	@echo -ne '\033[1;32m'
	@echo -n 'Certificate: $@'
	@echo -e '\033[0m'

verify: $(CERT_FILE) $(CA_CERT_FILE)
	$(VERIFY) -CAfile $(CA_CERT_FILE) $(CERT_FILE)

crl: $(CASTATE)/crlnumber | $(CA_DEPS) $(CATOP)/crl
	$(eval CRL_FILE := $(CATOP)/crl/crl$(shell cat $(CASTATE)/crlnumber).pem)
	$(CA) -gencrl $(CRLDAYS) \
		-out $(CRL_FILE)
	@chmod 644 $(CRL_FILE)
	@ln -sf $(CRL_FILE) $(CRL_LINK)
	@echo -ne '\033[1;32m'
	@echo -n 'CRL is in $(CRL_FILE)'
	@echo -e '\033[0m'

revoke_cert: $(CERT_FILE) | $(CA_DEPS)
	$(CA) -revoke $(CERT_FILE)

revoke: revoke_cert crl

print:
	@[ -r '$(CERT_FILE)' ] || { echo 'Unable to read $(CERT_FILE)!'; false; }
	@$(X509) -noout -text -in $(CERT_FILE)

clean:
	$(RM) \
		$(CERT_REQ_FILE) \
		$(CERT_KEY_FILE) \
		$(CERT_FILE)
