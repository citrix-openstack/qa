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
    if grep -q "$user $repo" "$tmpfile"; then
        echo "[CHERRY-PICK-START] $change"
        repo_record=$(grep "$user $repo" "$tmpfile")
        cd $(var_name "$repo_record")
            if git fetch $(source_repo "$repo_record") $changeref && git cherry-pick FETCH_HEAD; then
                echo "[CHERRY-PICK-OK]"
            else
                echo "[CHERRY-PICK-FAIL]"
                git diff
                exit 1
            fi
        cd ..
    else
        echo "[SKIPPING] $change"
    fi
done
rm "$tmpfile"
)

