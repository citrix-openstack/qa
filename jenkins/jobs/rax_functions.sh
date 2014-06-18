JESSIE_IMAGE_NAME=8025a161-aaaf-4568-a014-408d6aed00ba

function setup_venv() {
    if [ -z ${BUILD_NUMBER+BUILD_NUMBER_unset} ]; then
	tmpdir_name=${1:-rax_venv}
	# Assume we're not running in jenkins - move to a scratch location
	[ -e /tmp/rax_venv ] &&  rm -rf /tmp/$tmpdir_name/*
	mkdir -p /tmp/$tmpdir_name
	cd /tmp/$tmpdir_name
    fi

    # Pip doesn't like some bash flags..
    restore_flags=$-
    set +eux
    [ -e .env ] || virtualenv .env
    . .env/bin/activate
    set -$restore_flags

    pip install --upgrade pip
}

function setup_openrc() {
    cat > $1 << BASH_PROFILE
export OS_AUTH_URL=https://identity.api.rackspacecloud.com/v2.0/
export OS_REGION_NAME=IAD
export OS_AUTH_SYSTEM=keystone
export OS_USERNAME=$2
export OS_PROJECT_ID=$3
export OS_TENANT_NAME=$3
export OS_PASSWORD=$4
export OS_NO_CACHE=1
BASH_PROFILE
    restore_flags=$-
    set +x # Ensure the openrc is not traced
    source $1
    set -$restore_flags
}

function verify_image_exists() {
    IMAGE_NAME=$1
    restore_flags=$-
    set +e
    nova image-show $IMAGE_NAME > /dev/null 2>&1
    if [ $? -ne 0 ]; then
	echo "Image $IMAGE_NAME not seen in region $OS_REGION_NAME"
	exit 1
    fi
    set -$restore_flags
}

function create_vm() {
    REBUILD_VM=$1
    BUILD_VM=$2
    IMAGE_NAME=$3
    KEY_NAME=$4

    if [ $REBUILD_VM -gt 0 ]; then
	verify_image_exists $IMAGE_NAME

	restore_flags=$-
	set +e # Tolerate failures in nova show
	nova show $BUILD_VM
	if [ $? -eq 0 ]; then
	    nova delete $BUILD_VM
	    COUNTER=0
	    while `nova show $BUILD_VM > /dev/null 2>&1`; do
		echo "Waiting for $BUILD_VM to be destroyed..."
		sleep 10
		let COUNTER=COUNTER+1
		if [ $COUNTER -gt 20 ]; then
		    echo "Timed out waiting for VM $BUILD_VM to be destroyed"
		    exit 1
		fi
	    done
	fi
	set -$restore_flags
    fi

    set +e
    nova show $BUILD_VM || nova boot --poll --flavor performance1-8 \
	    --image $IMAGE_NAME \
	    --key-name $KEY_NAME $BUILD_VM
    set -$restore_flags
}
