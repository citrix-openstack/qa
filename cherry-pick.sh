#!/bin/bash

set -eux

. lib/functions

CITRIX_BRANCH_NAME="$1"
LATEST_BRANCH=${2:-latest}

if [ "$LATEST_BRANCH" = "latest" ]; then
    LATEST_BRANCH=$(wget -qO - "http://gold.eng.hq.xensource.com/gitweb/?p=internal/builds/status.git;a=blob_plain;f=latest_branch;hb=HEAD")
fi

./create_workspace.sh
./with_all_repos.sh git fetch build
./with_all_repos.sh git reset --hard || true
./with_all_repos.sh git checkout "build/$LATEST_BRANCH" -B $CITRIX_BRANCH_NAME


cd .workspace

tmpfile=$(mktemp)
generate_repos > "$tmpfile"

# Cherry pick required changes
while read change; do
    user=$(echo "$change" | cut -d"/" -f 1)
    repo=$(echo "$change" | cut -d" " -f 1 | cut -d"/" -f 2)
    changeref=$(echo "$change" | cut -d" " -f 2)
    repo_record=$(grep "$user $repo" "$tmpfile")
    [ -n "$repo_record" ]
    cd $(var_name "$repo_record")
        git fetch $(source_repo "$repo_record") $changeref && git cherry-pick FETCH_HEAD
    cd ..
done

cd ..

./with_all_repos.sh git push --tags --quiet build "$CITRIX_BRANCH_NAME"

rm "$tmpfile"
