#!/bin/bash
set -eux

git diff --name-only --diff-filter=U | while read conflicting_filename; do
    if [ "`basename $conflicting_filename`" == "nova_plugin_version" ]; then

	# Delete all lines starting with a version number
	sed -i '/# [0-9]*[.][0-9]*/d' $conflicting_filename
	# Set version number to a dev plugin number
	sed -i -e 's/PLUGIN_VERSION = "[0-9.]*"/PLUGIN_VERSION = "999.999"/' $conflicting_filename
        sed -i '/\(<<<<<<<\|=======\|>>>>>>>\)/d' $conflicting_filename

	# Make sure only 1 added line (all #s were deleted) - and add it if this is the case
	git add $conflicting_filename
	added=$(git diff --cached --numstat $conflicting_filename | cut -f 1)
	if [ $added -ne 1 ]; then
	    echo "Changes for $conflicting_filename not expected"
	    exit 1
	fi

	# And set the expected version number to a dev plugin number
	sed -i -e 's/PLUGIN_REQUIRED_VERSION = .*/PLUGIN_REQUIRED_VERSION = "999.999"/' nova/virt/xenapi/client/session.py
        sed -i '/\(<<<<<<<\|=======\|>>>>>>>\)/d' nova/virt/xenapi/client/session.py

	# Make sure only 1 added line and 1 deleted line - and add it if this is the case
	git add nova/virt/xenapi/client/session.py
	added=$(git diff --cached --numstat $conflicting_filename | cut -f 1)
	deleted=$(git diff --cached --numstat $conflicting_filename | cut -f 2)
	if [ $added -eq 1 -a $deleted -eq 1 ]; then
	    echo "Changes for $conflicting_filename not expected"
	    exit 1
	fi
    fi
done

if [ -z "`git diff --name-only --diff-filter=U`" ]; then
    echo "No more unmerged changes - comitting"
    git commit --no-edit --allow-empty
fi

