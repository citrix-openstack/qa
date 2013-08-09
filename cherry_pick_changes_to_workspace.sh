#!/bin/bash

set -eu

. lib/functions

assert_no_new_repos

(
set -eu
cd .workspace
tmpfile=$(mktemp)
generate_repos > "$tmpfile"

# Cherry pick required changes
while read change; do
    set -e
    user=$(echo "$change" | cut -d"/" -f 1)
    repo=$(echo "$change" | cut -d" " -f 1 | cut -d"/" -f 2)
    changeref=$(echo "$change" | cut -d" " -f 2)
    repo_record=$(grep "$user $repo" "$tmpfile")
    [ -n "$repo_record" ]
    cd $(var_name "$repo_record")
        echo "[CHERRY-PICK] $change"
        git fetch $(source_repo "$repo_record") $changeref && git cherry-pick FETCH_HEAD
        [ "$?" == "0" ]
    cd ..
done
)
rm "$tmpfile"

