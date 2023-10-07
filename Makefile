# Makefile

# Please note: this is NOT the best example of usage of dmakelib.mk

VERSION_SCRIPT   = /usr/local/lib/dmakelib.mk
VERSION_VARIABLE = _DMAKE_VERS

_DMAKE_FILE := $(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
_DMAKE_DIR  := $(dir $(_DMAKE_FILE))

include $(_DMAKE_DIR)/src$(VERSION_SCRIPT)

