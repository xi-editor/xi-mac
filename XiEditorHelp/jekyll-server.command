#!/bin/bash

set -eux

BASE=$(dirname "$0")
SITE=$(basename "$BASE")
URL=http://127.0.0.1:4000/
SITEROOT=_site

cd "$BASE"

# Title the window
echo -n -e "\033]0;$SITE Jekyll Server\007"

# Auto-refresh using fswatch, if available...
if which fswatch
then
	fswatch -o _site | xargs -n1 -I{} osascript -e "tell application \"Safari\" to do JavaScript \"location.reload(true)\" in documents whose URL starts with \"$URL\"" > /dev/null &
else
	echo "NOTE: Install fswatch (e.g. brew install fswatch) to allow auto-refresh"
fi

# Open a window, if one isn't found
osascript -e "tell application \"Safari\" to if ((documents whose URL starts with \"$URL\") = {}) then open location \"$URL\""

jekyll serve --watch
