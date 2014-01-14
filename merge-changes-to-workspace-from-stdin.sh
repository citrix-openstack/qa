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

if [ -n "$CONFLICT_PATCHES_DIR" ]; then
CONFLICT_PATCHES_DIR="$(cd $CONFLICT_PATCHES_DIR && pwd)"
fi

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

    if [ -z "$change" ]; then
        echo "Skipping empty line"
        continue
    fi
    user=$(echo "$change" | cut -d"/" -f 1)
    repo=$(echo "$change" | cut -d" " -f 1 | cut -d"/" -f 2)
    change_number=$(echo "$change" | cut -d" " -f 2 | cut -d"/" -f 4)
    changeref=$(echo "$change" | cut -d" " -f 2)

    if [ -z "$user" ] || [ -z "$repo" ] || [ -z "$change_number" ] || [ -z "$changeref" ]; then
        echo "Failed to get all parameters"
        exit 1
    fi
    if grep -q "$user $repo" "$tmpfile"; then
        echo "[MERGE-START] $change"
        repo_record=$(grep "$user $repo" "$tmpfile")
        cd $(var_name "$repo_record")
            if git fetch $(source_repo "$repo_record") $changeref && git merge FETCH_HEAD; then
                echo "[MERGE-OK]"
            else
                if [ -z "$CONFLICT_PATCHES_DIR" ]; then
                    echo "There are no conflict-resolvers."
                    exit 1
                fi
                echo "[MERGE-CONFLICT] Removing commit ids from conflicting files"
                git diff --name-only --diff-filter=U | while read conflicting_filename; do
                    sed -ie 's/^\(>\+\) \([^ ]\+\) \(.*\)$/\1 \3/g' \
                      "$conflicting_filename"
                done
                echo "[MERGE-CONFLICT] Printing diff to standard output"
                git --no-pager diff
                resolution_script="$CONFLICT_PATCHES_DIR/$change_number"
                diff_script="$CONFLICT_PATCHES_DIR/$change_number.diff"
                echo "[MERGE-CONFLICT] looking for resolution script as $resolution_script"
                if [ -x  "$resolution_script" ]; then
                    echo "[MERGE-CONFLICT] Applying script $resolution_script"
                    $resolution_script
                    echo "[MERGE-CONFLICT] script done"
                else
                    echo "[MERGE-CONFLICT] looking for diff as $diff_script"
                    if [ -e "$diff_script" ]; then
                        echo "[MERGE-CONFLICT] applying diff $diff_script"
                        git apply "$diff_script"

                        git diff --name-only --diff-filter=U | while read conflicting_filename; do
                            git add "$conflicting_filename"
                        done

                        git commit --no-edit --allow-empty
                        echo "[MERGE-CONFLICT] applied diff $diff_script"
                    else
                        echo "[MERGE-FAIL] No resolution found"
                        exit 1
                    fi
                fi
            fi
        cd ..
    else
        echo "[SKIPPING] $change"
    fi
done
rm "$tmpfile"
)

