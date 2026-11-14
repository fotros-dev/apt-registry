VERSION := $(shell cat VERSION)
PREFIX ?= /usr/local
DESTDIR ?=
BINDIR := $(PREFIX)/bin
COMPLETIONSDIR := $(PREFIX)/share/bash-completion/completions
SHELLCHECK ?= shellcheck

DEB_NAME := apt-registry_$(VERSION)_all
DEB_ROOT := dist/$(DEB_NAME)
DEB_FILE := dist/$(DEB_NAME).deb
DEB_DOCDIR := $(DEB_ROOT)/usr/share/doc/apt-registry

.PHONY: all install uninstall lint check-version deb clean

all: lint

install:
	install -d -m 0755 $(DESTDIR)$(BINDIR) $(DESTDIR)$(COMPLETIONSDIR)
	install -m 0755 apt-registry $(DESTDIR)$(BINDIR)/apt-registry
	install -m 0644 completions/apt-registry.bash $(DESTDIR)$(COMPLETIONSDIR)/apt-registry

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/apt-registry $(DESTDIR)$(COMPLETIONSDIR)/apt-registry

lint: check-version
	$(SHELLCHECK) apt-registry install.sh packaging/debian/prerm packaging/debian/postrm
	$(SHELLCHECK) --shell=bash completions/apt-registry.bash
	sh -n install.sh

check-version:
	@grep -q '^readonly APT_REGISTRY_VERSION="$(VERSION)"$$' apt-registry || \
		{ echo "apt-registry does not declare version $(VERSION) from VERSION" >&2; exit 1; }

deb: check-version
	rm -rf dist/$(DEB_NAME) dist/$(DEB_NAME).deb
	install -d -m 0755 $(DEB_ROOT)/DEBIAN $(DEB_ROOT)/usr/bin \
		$(DEB_ROOT)/usr/share/bash-completion/completions $(DEB_DOCDIR)
	install -m 0755 apt-registry $(DEB_ROOT)/usr/bin/apt-registry
	install -m 0644 completions/apt-registry.bash $(DEB_ROOT)/usr/share/bash-completion/completions/apt-registry
	install -m 0644 README.md CHANGELOG.md $(DEB_DOCDIR)/
	install -m 0644 LICENSE $(DEB_DOCDIR)/copyright
	install -m 0755 packaging/debian/prerm packaging/debian/postrm $(DEB_ROOT)/DEBIAN/
	sed -e 's/@VERSION@/$(VERSION)/' \
		-e "s/@INSTALLED_SIZE@/$$(du -sk --exclude=DEBIAN $(DEB_ROOT) | cut -f1)/" \
		packaging/debian/control > $(DEB_ROOT)/DEBIAN/control
	chmod -R u+rwX,go+rX,go-w $(DEB_ROOT)
	dpkg-deb --root-owner-group --build $(DEB_ROOT) $(DEB_FILE)

clean:
	rm -rf dist
