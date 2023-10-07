# Makefile

_DMAKE_VERS := 2.16
_DMAKE_FILE := $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
_DMAKE_DIR   = $(dir $(_DMAKE_FILE))

CFILES = \
	/etc/dmake.cf \
	$(HOME)/.config/dmake.cf \
	$(CURDIR)/../.dmake.cf \
	$(CURDIR)/../dmake.cf \
	$(CURDIR)/.dmake.cf \
	$(CURDIR)/dmake.cf
CFILE :=
$(foreach f,$(CFILES),$(if $(wildcard $(f)),$(eval CFILE:=$(realpath $(f))),))
ifneq ($(CFILE),)
include $(CFILE)
endif

RELEASE_default := $(awk -F= '/^VERSION_CODENAME=/ {print $2}' /etc/os-release)
DISTRO_default  := $(awk -F= '/^ID=/ {print $2}' /etc/os-release)
$(if $(DISTRO_default),,          $(eval DISTRO_default:=debian))
$(if $(RELEASE_default),,         $(eval RELEASE_default:=bullseye))
ifneq ($(wildcard /usr/bin/git),)
$(if $(MAINTAINER_USER_default),, $(eval MAINTAINER_USER_default:=$(shell id -nu)))
$(if $(MAINTAINER_NAME_default),, $(eval MAINTAINER_NAME_default:=$(shell git config --get user.name)))
$(if $(MAINTAINER_MAIL_default),, $(eval MAINTAINER_MAIL_default:=$(shell git config --get user.email)))
endif
$(if $(MAINTAINER_USER_default),, $(eval MAINTAINER_USER_default:=$(shell id -nu)))
$(if $(MAINTAINER_NAME_default),, $(eval MAINTAINER_NAME_default:=$(shell getent passwd $(MAINTAINER_USER_default) | awk -F: '{print $$5}' | awk -F, '{print $$1}')))
$(if $(MAINTAINER_MAIL_default),, $(eval MAINTAINER_MAIL_default:=$(MAINTAINER_USER_default)@localhost))

$(if $(UPLOADER_USER_default),,   $(eval UPLOADER_USER_default:=$(MAINTAINER_USER_default)))
$(if $(UPLOADER_NAME_default),,   $(eval UPLOADER_NAME_default:=$(MAINTAINER_NAME_default)))
$(if $(UPLOADER_MAIL_default),,   $(eval UPLOADER_MAIL_default:=$(MAINTAINER_MAIL_default)))

$(if $(DISTRO),,          $(eval DISTRO:=$(DISTRO_default)))
$(if $(RELEASE),,         $(eval RELEASE:=$(RELEASE_default)))
$(if $(COMPONENT),,       $(eval COMPONENT:=main))
$(if $(REPONAME),,        $(eval REPONAME:=dmake))
$(if $(SOURCES_FILE),,    $(eval SOURCES_FILE:=$(REPONAME)-local.list))
$(if $(MAINTAINER_USER),, $(eval MAINTAINER_USER:=$(MAINTAINER_USER_default)))
$(if $(MAINTAINER_NAME),, $(eval MAINTAINER_NAME:=$(MAINTAINER_NAME_default)))
$(if $(MAINTAINER_MAIL),, $(eval MAINTAINER_MAIL:=$(or $(MAINTAINER_EMAIL),$(MAINTAINER_MAIL_default))))
$(if $(UPLOADER_USER),,   $(eval UPLOADER_USER:=$(UPLOADER_USER_default)))
$(if $(UPLOADER_NAME),,   $(eval UPLOADER_NAME:=$(UPLOADER_NAME_default)))
$(if $(UPLOADER_MAIL),,   $(eval UPLOADER_MAIL:=$(or $(UPLOADER_EMAIL),$(UPLOADER_MAIL_default))))

ifneq ($(DISTRO_DIR),)
$(if $(SHARE_MOUNT),,  $(eval SHARE_MOUNT:=$(shell dirname $(DISTRO_DIR))))
$(if $(APTLY_DIR),,APTLY_DIR:=$(SHARE_MOUNT)/apt)
else
$(if $(SHARE_MOUNT),,  $(eval SHARE_MOUNT:=$(shell dirname $(_DMAKE_DIR))))
$(if $(DISTRO_DIR),,   $(eval DISTRO_DIR:=$(SHARE_MOUNT)/apt/$(DISTRO)))
endif

$(if $(SHARE_NAME),,   $(eval SHARE_NAME:=$(notdir $(SHARE_MOUNT))))
$(if $(APTLY_DIR),,    $(eval APTLY_DIR:=$(SHARE_MOUNT)/apt))
$(if $(APTLY_CONF),,   $(eval APTLY_CONF:=$(APTLY_DIR)/aptly.conf))

ifneq ($(filter src/usr/local /usr/local,$(SHARE_MOUNT)),)
SHARE_MOUNT := /var/cache/dmake
SHARE_NAME  := hardcoded
DISTRO_DIR  := $(SHARE_MOUNT)/$(DISTRO)
APTLY_DIR   := $(SHARE_MOUNT)/aptly
APTLY_CONF  := $(APTLY_DIR)/aptly.conf
endif

FS_NAME      = $(SHARE_NAME)-apt-$(DISTRO)
ifneq ($(wildcard src/DEBIAN/control),)
DEBPKGNAME_default  := $(shell awk -F': ' '/^Package: / {print $$2}' src/DEBIAN/control)
DEBPKGVERS_default  := $(shell awk -F': ' '/^Version: / {print $$2}' src/DEBIAN/control)
DEBPKGARCH_default  := $(shell awk -F': ' '/^Architecture: / {print $$2}' src/DEBIAN/control)
endif
$(if $(DEBPKGNAME_default),,   $(eval DEBPKGNAME_default:=mypackage))
$(if $(DEBPKGVERS_default),,   $(eval DEBPKGVERS_default:=0.0.1))
$(if $(DEBPKGARCH_default),,   $(eval DEBPKGARCH_default:=all))
$(if $(DEBPKGNAME),,   $(eval DEBPKGNAME:=$(DEBPKGNAME_default)))
$(if $(DEBPKGVERS),,   $(eval DEBPKGVERS:=$(DEBPKGVERS_default)))
$(if $(DEBPKGARCH),,   $(eval DEBPKGARCH:=$(DEBPKGARCH_default)))

ifneq ($(VERSION_SCRIPT),)
ifneq ($(VERSION_VARIABLE),)
ifeq ($(VERSION),)
VERSION     := $(shell eval echo $$(awk -F'=' '/$(VERSION_VARIABLE)/{print $$2}' ./src/$(VERSION_SCRIPT)))
endif
endif
endif

REPOPKGVERS := $(shell \
	awk -F': ' '/^Package: /{p=0} /^Package: $(DEBPKGNAME)$$/{p=1;next} /^Version: /{p==1 && !v && v=$$2} END{print v}' \
	$(DISTRO_DIR)/$(REPONAME)/dists/$(RELEASE)/$(COMPONENT)/binary-$(DEBPKGARCH)/Packages 2>/dev/null)
NEXTPKGVERS := $(shell \
	X=$(DEBPKGVERS) ; \
	if [ -n "$(VERSION)" ] && dpkg --compare-versions "$(VERSION)" gt "$$X" ; then X="$(VERSION)" ; fi ;\
	if dpkg --compare-versions "$$X" lt "$(REPOPKGVERS)" ; then X=$(REPOPKGVERS) ; fi ;\
	V=$${X%-*} ; D=$${X##*-} ; [ "$${D}" != "$${X}" ] || unset D ;\
	while dpkg --compare-versions "$${V:-0.0.1}$${D+-}$${D}" le "$(REPOPKGVERS)" ; do\
	D=$$(( $${D}$${D++}1 )) ; done ;\
	[ -z "$${V}" ] || echo "$${V}$${D+-}$${D}")

NEXT_VERSION := $(shell V=$(NEXTPKGVERS) ; echo $${V%-*})

ifneq ($(V),)
#DEBPKGVERS   :=
REPOPKGVERS  :=
VERSION      := 
NEXTPKGVERS  := $(V)
NEXT_VERSION := $(V)
T_DEBPKGVERS := $(V)
endif
$(eval T_DEBPKGNAME:=$(if $(N),$(N),$(DEBPKGNAME)))
$(eval T_SECTION:=$(if $(S),$(S),utils))
$(eval T_PRIORITIY:=$(if $(P),$(P),optional))
$(eval T_DEBPKGARCH:=$(if $(A),$(A),all))

NEEDS_UPDATE := $(shell if dpkg --compare-versions "$(REPOPKGVERS)" lt "$(DEBPKGVERS)" ; then echo needed ; else echo no-need ; fi)

DEBPKGFILE   := $(DEBPKGNAME)_$(DEBPKGVERS)_$(DEBPKGARCH).deb
NEXTDEBFILE  := $(DEBPKGNAME)_$(NEXTPKGVERS)_$(DEBPKGARCH).deb

#DEBPKGNAME   := unknown
#DEBPKGVERS   := 0.0
#DEBPKGARCH   := all

#REPOPKGVERS  := 0.0
#VERSION      :=
#NEXTPKGVERS  := 0.0
#NEXT_VERION  := 0.0

#NEEDS_UPDATE := no-need
#DEBPKGFILE   :=
#NEXTDEBFILE  :=


define APTLY_CONFIG
{
  "rootDir": "$(APTLY_DIR)",
  "downloadConcurrency": 4,
  "downloadSpeedLimit": 0,
  "architectures": ["amd64", "all"],
  "dependencyFollowSuggests": false,
  "dependencyFollowRecommends": false,
  "dependencyFollowAllVariants": false,
  "dependencyFollowSource": false,
  "dependencyVerboseResolve": false,
  "gpgDisableSign": true,
  "gpgDisableVerify": true,
  "gpgProvider": "gpg",
  "downloadSourcePackages": false,
  "skipLegacyPool": true,
  "ppaDistributorID": "$(DISTRO)",
  "ppaCodename": "",
  "skipContentsPublishing": false,
  "FileSystemPublishEndpoints": {
    "$(FS_NAME)": {
      "rootDir": "$(DISTRO_DIR)",
      "linkMethod": "hardlink"
    }
  },
  "S3PublishEndpoints": {},
  "SwiftPublishEndpoints": {}
}
endef
export APTLY_CONFIG

define DEBIAN_CONTROL
Package: $(T_DEBPKGNAME)
Version: $(T_DEBPKGVERS)
Section: $(T_SECTION)
Priority: $(T_PRIORITIY)
Architecture: $(T_DEBPKGARCH)
Maintainer: $(MAINTAINER_NAME) <$(MAINTAINER_MAIL)>
Description: $(T_DEBPKGNAME) package.

endef
export DEBIAN_CONTROL

define SOURCES_LIST
deb [trusted=yes] file://$(DISTRO_DIR)/$(REPONAME) $(RELEASE) main
endef
export SOURCES_LIST

define MAKEFILE_TEMPLATE
# VERSION_SCRIPT   = /usr/local/bin/$(call lc,$(T_DEBPKGNAME))
# VERSION_VARIABLE = $(call uc,$(T_DEBPKGNAME))_VERSION
include /usr/local/lib/dmakelib.mk
endef
export MAKEFILE_TEMPLATE

define _DMAKE_USAGE
dmake ($(_DMAKE_VERS))
Copyright (C) 2023 Claudio Luck <claudio.luck@datact.ch>

Usage: make TARGET


TARGET is one of:

   init [{N,V,A,P,S}=.. ] Initialize package boiler-plate (makefile+control)
                          with optional values for Name, Version, Architecture,
                          Priority and Section
   build                  Build $(DEBPKGFILE)
   upload                 Upload $(DEBPKGFILE)
   next-version [V=<ver>] Increment Version in DEBIAN/control automatically

 Less often used:

   install-source         Create /etc/apt/sources.list.d/$(SOURCES_FILE)
   remove-source          Remove /etc/apt/sources.list.d/$(SOURCES_FILE)
   apt-update             apt-get update just for $(SOURCES_FILE)
   apt-install            apt-get install -y $(DEBPKGNAME)
   config                 Show config (valid {,.,../,../.,~/,~/.,/etc/}dmake.cf)
   info                   Show some package properties, incl. computed versions
   makefile               Create Makefile boilerplate
   control                Create src/DEBIAN/control boilerplate

 Break stuff:

   repo-init              Initialize aptly repository
   repo-show              Show aptly publish list


EXAMPLE ./Makefile:

   VERSION_SCRIPT   = /usr/local/bin/my_script
   VERSION_VARIABLE = MY_SCRIPT_VERSION
   include /usr/local/lib/dmakelib.mk

 .. then create:

   src/DEBIAN/control
   src/usr/local/bin/my_script

endef
export _DMAKE_USAGE

all: usage
help: usage
usage:
	@echo "$${_DMAKE_USAGE}"
	@echo ""
	@echo "EXAMPLE src/DEBIAN/control:"
	@echo ""
	@echo "$$DEBIAN_CONTROL" | sed 's/^/   /g'


info:
	@echo "Package: $(DEBPKGNAME)"
	@echo "Architecture: $(DEBPKGARCH)"
	@echo "Local-Version: $(DEBPKGVERS)"
	@echo "Script-Version: $(VERSION)"
	@echo "Repo-Version: $(REPOPKGVERS)"
	@echo "Next-Version: $(NEXTPKGVERS)"

config:
	@echo "# Config file: $(if $(CFILE),$(CFILE),(none))"
	@echo "MAINTAINER_USER := $(MAINTAINER_USER)"
	@echo "MAINTAINER_NAME := $(MAINTAINER_NAME)"
	@echo "MAINTAINER_MAIL := $(MAINTAINER_MAIL)"
	@echo "UPLOADER_USER   := $(UPLOADER_USER)"
	@echo "UPLOADER_NAME   := $(UPLOADER_NAME)"
	@echo "UPLOADER_MAIL   := $(UPLOADER_MAIL)"
	@echo "DISTRO          := $(DISTRO)"
	@echo "RELEASE         := $(RELEASE)"
	@echo "COMPONENT       := $(COMPONENT)"
	@echo "REPONAME        := $(REPONAME)"
	@echo "SOURCES_FILE    := $(SOURCES_FILE)"
	@echo "SHARE_MOUNT     := $(SHARE_MOUNT)"
	@echo "SHARE_NAME      := $(SHARE_NAME)"
	@echo "# FS_NAME       := $(FS_NAME)   # FileSystemPublishEndpoint"
	@echo "DISTRO_DIR      := $(DISTRO_DIR)"
	@echo "APTLY_DIR       := $(APTLY_DIR)"
	@echo "APTLY_CONF      := $(APTLY_CONF)"

repo-init:
	mkdir -p "$(SHARE_MOUNT)" "$(APTLY_DIR)" "$(DISTRO_DIR)"
	[ -r "$(APTLY_CONF)" ] || echo "$$APTLY_CONFIG" >$(APTLY_CONF)
	aptly -config="$(APTLY_CONF)" repo create $(REPONAME) || :
	aptly -config="$(APTLY_CONF)" -skip-signing -distribution=$(RELEASE) -architectures=amd64,all publish repo $(REPONAME) filesystem:$(FS_NAME):$(REPONAME) || :

/etc/apt/sources.list.d/$(SOURCES_FILE):
	echo "$(SOURCES_LIST)" >/etc/apt/sources.list.d/$(SOURCES_FILE)
install-source: /etc/apt/sources.list.d/$(SOURCES_FILE)

uninstall-source: remove-source
remove-source:
	rm -f /etc/apt/sources.list.d/$(SOURCES_FILE)
.PHONY: install-source remove-source

src/DEBIAN/control:
	mkdir -p src/DEBIAN
	[ -r src/DEBIAN/control ] || echo "$$DEBIAN_CONTROL" >src/DEBIAN/control
control: src/DEBIAN/control
.PHONY: src/DEBIAN/control

makefile:
	[ -r Makefile ] || echo "$$MAKEFILE_TEMPLATE" >Makefile
.PHONY: makefile

init: makefile control
.PHONY: init

do-update-debian-control-version:
	@[ -z "$(V)" -a "$(DEBPKGVERS)" = "$(NEXTPKGVERS)" ] || \
	    echo "Version: $(DEBPKGVERS) -> $(NEXTPKGVERS)" >&2 && \
	    sed -i "s/^Version: .*$$/Version: $(NEXTPKGVERS)/g" src/DEBIAN/control
#
do-update-script-version:
	@if [ -n "$(VERSION_SCRIPT)" -a -n "$(VERSION_VARIABLE)" ] ; then \
	    echo "Updating $(VERSION_VARIABLE)=$(NEXT_VERSION) in $(VERSION_SCRIPT)...">&2 ; \
	    sed -i 's/^$(VERSION_VARIABLE)\([[:space:]][^=]*\|\)=\([[:space:]]*\).*$$/$(VERSION_VARIABLE)\1=\2$(NEXT_VERSION)/g' "./src/$(VERSION_SCRIPT)" ; \
	fi
#
ifeq  ($(or $(if $(filter $(NEXTPKGVERS),$(DEBPKGVERS)),,y),$(V))),)
next-version: info
else
next-version: info do-update-debian-control-version do-update-script-version set-version
endif
#
.PHONY: do-update-debian-control-version do-update-script-version set-version

repo-list: $(APTLY_CONF)
	aptly -config="$(APTLY_CONF)" publish list
repo-show: repo-list

$(DEBPKGFILE):
	SOURCE_DATE_EPOCH=$$(stat -c %Y src/DEBIAN/control) \
	dpkg-deb --root-owner-group --build src $(DEBPKGFILE)
.PHONY: $(DEBPKGFILE)
ifneq ($(DEBPKGFILE), $(NEXTDEBFILE))
$(NEXTDEBFILE):
	@echo "|" >&2
	@echo "| Error: version was not incremented, use \`make next-version' to do so" >&2
	@echo "|" >&2
	@exit 1
endif
build-needed: $(NEXTDEBFILE)
build-no-need: $(DEBPKGFILE)
build: build-$(NEEDS_UPDATE)

upload-needed: $(DEBPKGFILE) $(APTLY_CONF)
	aptly -config="$(APTLY_CONF)" repo add $(REPONAME) $(DEBPKGFILE)
	aptly -config="$(APTLY_CONF)" publish update $(RELEASE) filesystem:$(FS_NAME):$(REPONAME)
upload-no-need:
	@echo "|" >&2
	@echo "| Local version $(DEBPKGVERS) is not newer than version $(REPOPKGVERS) in repository." >&2
	@echo "| If you have changes, use \`make next-version' to increment local version" >&2
	@echo "|" >&2
	@exit 1
upload: upload-$(NEEDS_UPDATE)

upload-force: $(DEBPKGFILE) $(APTLY_CONF)
	aptly -config="$(APTLY_CONF)" -force-replace repo add $(REPONAME) $(DEBPKGFILE)
	aptly -config="$(APTLY_CONF)" -force-overwrite publish update $(RELEASE) filesystem:$(FS_NAME):$(REPONAME)

apt-update: /etc/apt/sources.list.d/$(SOURCES_FILE)
	apt-get update -o Dir::Etc::sourcelist="sources.list.d/$(SOURCES_FILE)" \
	               -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"

apt-install:
	apt-get install --reinstall -y $(DEBPKGNAME)

local-install: $(DEBPKGFILE)
	dpkg -i $(DEBPKGFILE)

