WGET = wget
PERL = perl
GIT = git
PERL_VERSION = 5.16.1
PERL_ENV = PATH="$(abspath local/perlbrew/perls/perl-$(PERL_VERSION)/bin):$(abspath local/perl-$(PERL_VERSION)/pm/bin):$(PATH)"

all:

deps: git-submodules local-perl pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl: always
	mkdir -p local/bin
	$(WGET) -O $@ https://github.com/wakaba/perl-setupenv/raw/master/bin/pmbp.pl

local-perl: local/bin/pmbp.pl
	$(PERL_ENV) $(PERL) local/bin/pmbp.pl --perl-version $(PERL_VERSION) --install-perl

pmbp-update: local/bin/pmbp.pl
	$(PERL_ENV) $(PERL) local/bin/pmbp.pl --update

pmbp-install: local/bin/pmbp.pl
	$(PERL_ENV) $(PERL) local/bin/pmbp.pl --install

always:
