# For command-line debugging, use the Jekyll default destination
TARGET_BUILD_DIR ?= _site

HELP := $(TARGET_BUILD_DIR)/$(UNLOCALIZED_RESOURCES_FOLDER_PATH)

# Xcode shells have a default environment with no locale settings, so set if undefined (needed by Jekyll to process UTF-8 SCSS)
export LANG ?= en_US.UTF-8

$(HELP) : * **/*
	[[ -s "$(HOME)/.rvm/environments/default" ]] && source "$(HOME)/.rvm/environments/default" ; \
	(which -s jekyll || (echo "error: Jekyll not found - check setup requirements" ; false )) \
	&& jekyll build --destination "$(HELP)"
	for LPROJ in "$(HELP)"/*.lproj ; do \
		LOCALE=$$(basename "$$LPROJ" .lproj) ; \
		echo "Indexing: $$LPROJ" ; \
		hiutil -1 -vv --create --anchors --locale=$$LOCALE --file "$$LPROJ/search.helpindex" "$$LPROJ" 2>&1 | \
		awk "{ if (/error:/) {printf \"error: \" ; err = 1} else {printf \"warning: \"} ; print} END {exit err}" ; \
	done
