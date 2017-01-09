#!/bin/bash
set -ex
export LC_ALL=C
pwd

function generate_new_layoutfile() {
    TARGET_FILE=zuul/layout.yaml
    TMP_DIR=/tmp/$$
    rm -rf $TMP_DIR
    mkdir -p $TMP_DIR
    BKUP_FILE=$TMP_DIR/$(basename $TARGET_FILE).old
    cp $TARGET_FILE $BKUP_FILE

    # get upstream projects.yaml to get new project list.
    wget https://raw.githubusercontent.com/openstack-infra/project-config/master/gerrit/projects.yaml
    grep '^- project:' projects.yaml | sed 's/^- project: /  - name: /g' | sort > $TMP_DIR/projects.list
    
    # we put the tested projects at the beginning and shouldn't be impacted by upstream update,
    # so we should filter out these projects.
    filter_pattern=$(sed '/^projects:$/,/# Start for Other pojects #/!d' $BKUP_FILE | grep '^  - name:' | cut -d: -f2 | xargs | tr ' ' '|')
    egrep -v "$filter_pattern" $TMP_DIR/projects.list > $TMP_DIR/appending_projects.list
    base_end_line=$(grep -n '# Start for Other pojects #' $BKUP_FILE | cut -d: -f1)
    head -$base_end_line $BKUP_FILE > $TMP_DIR/layout.yaml.base
    cat $TMP_DIR/layout.yaml.base $TMP_DIR/appending_projects.list > $TARGET_FILE
}


NEW_FILE=$(pwd)/layout.yaml.new
####################
# propose a change
PROJECT=${PROJECT:-"citrix-openstack/os-ext-testing"}
BRANCH=${BRANCH:-"master"}
INITIAL_COMMIT_MSG="Normalize layout.yaml"
TOPIC="zuul-layout-yaml-update"

git config user.name "OpenStack Proposal Bot"
git config user.email "openstack@citrix.com"
git config gitreview.username "citrix-openstack-ci"

TARGET_PATH=$(basename $PROJECT)
rm -rf $TARGET_PATH
git clone https://github.com/$PROJECT -b $BRANCH $TARGET_PATH
# Initial state of repository is detached, create a branch to work
# from. Otherwise git review will complain.
cd $TARGET_PATH

git checkout -B proposals

change_id=""
# See if there is an open change in the openstack/requirements topic
# If so, get the change id for the existing change for use in the
# commit msg.
change_info=$(ssh -p 29418 $USERNAME@review.openstack.org gerrit query --current-patch-set status:open project:$PROJECT topic:$TOPIC owner:$USERNAME)
previous=$(echo "$change_info" | grep "^  number:" | awk '{print $2}')
if [ -n "$previous" ]; then
    change_id=$(echo "$change_info" | grep "^change" | awk '{print $2}')
    # read return a non zero value when it reaches EOF. Because we use a
    # heredoc here it will always reach EOF and return a nonzero value.
    # Disable -e temporarily to get around the read.
    # The reason we use read is to allow for multiline variable content
    # and variable interpolation. Simply double quoting a string across
    # multiple lines removes the newlines.
    set +e
    read -d '' COMMIT_MSG <<EOF
$INITIAL_COMMIT_MSG

Change-Id: $change_id
EOF
    set -e
else
    COMMIT_MSG=$INITIAL_COMMIT_MSG
fi

git review -s
generate_new_layoutfile

SUCCESS=0
if ! git diff --stat --exit-code HEAD ; then
    # Commit and review
    git_args="-a -F-"
    git commit $git_args <<EOF
$COMMIT_MSG
EOF
    # Do error checking manually to ignore one class of failure.
    set +e
    OUTPUT=$(git review -t $TOPIC)
    RET=$?
    [[ "$RET" -eq "0" || "$OUTPUT" =~ "no new changes" || "$OUTPUT" =~ "no changes made" ]]
    SUCCESS=$?
fi

exit $SUCCESS
