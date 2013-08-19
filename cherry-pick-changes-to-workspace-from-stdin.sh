#!/bin/bash

set -eu

function print_usage_and_die
{
cat >&2 << EOF
usage: $0 [CONFLICT_SCRIPT_DIR]

Cherry-pick citrix changes with additional conflict resolution.

positional arguments:
 CONFLICT_SCRIPT_DIR  Directory, where conflict resolution scripts live

EOF
exit 1
}


. lib/functions

THIS_DIR="$(cd $(dirname $(readlink -f $0)) && pwd)"
CONFLICT_PATCHES_DIR="${1:-}"

echo "Working directory   : [$THIS_DIR]"
echo "Conflict patches dir: [$CONFLICT_PATCHES_DIR]"

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
    change_number=$(echo "$change" | cut -d" " -f 2 | cut -d"/" -f 4)
    changeref=$(echo "$change" | cut -d" " -f 2)
    if grep -q "$user $repo" "$tmpfile"; then
        echo "[CHERRY-PICK-START] $change"
        repo_record=$(grep "$user $repo" "$tmpfile")
        cd $(var_name "$repo_record")
            if git fetch $(source_repo "$repo_record") $changeref && git cherry-pick FETCH_HEAD; then
                echo "[CHERRY-PICK-OK]"
            else
                if [ -z "$CONFLICT_PATCHES_DIR" ]; then
                    echo "There are no conflict-resolvers."
                    exit 1
                fi
                echo "[CHERRY-PICK-FAIL] Printing diff"
                git diff
                resolution_script="$CONFLICT_PATCHES_DIR/$change_number"
                echo "[CHERRY-PICK-FAIL] looking for resolution script as $resolution_script"
                if [ -x  "$resolution_script" ]; then
                    echo "[CHERRY-PICK-FAIL] Applying script $resolution_script"
                    $resolution_script
                    echo "[CHERRY-PICK-FAIL] script done"
                else
                    echo "[CHERRY-PICK-FAIL] No resolution found"
                    exit 1
                fi
            fi
        cd ..
    else
        echo "[SKIPPING] $change"
    fi
done
rm "$tmpfile"
)

