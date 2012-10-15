WGET = wget
PERL = ./perl
PROVE = ./prove
GIT = git

all:

## ------ Setup ------

deps: git-submodules pmbp-install cinnamon

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://github.com/wakaba/perl-setupenv/raw/master/bin/pmbp.pl

pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl

pmbp-update: pmbp-upgrade
	perl local/bin/pmbp.pl --update

pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install \
	    --create-perl-command-shortcut perl \
	    --create-perl-command-shortcut prove

CINNAMON_GIT_REPOSITORY = git://github.com/wakaba/cinnamon.git

cinnamon:
	mkdir -p local
	cd local && (($(GIT) clone $(CINNAMON_GIT_REPOSITORY)) || (cd cinnamon && $(GIT) pull)) && cd cinnamon && $(MAKE) deps
	echo "#!/bin/sh" > ./cin
	echo "$(abspath local/cinnamon/perl) $(abspath local/cinnamon/bin/cinnamon) \"\$$@\"" >> ./cin
	chmod ugo+x ./cin

## ------ Tests ------

test: test-deps test-main

test-deps: deps
	cd modules/rdb-utils && $(MAKE) deps

test-main:
	$(PROVE) t/integrated/*.t

always:
