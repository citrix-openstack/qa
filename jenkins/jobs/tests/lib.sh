function extract_id {
    sed -e 's/^| //g' -e 's/ |.*$//g'
}

function sleepwhile {
    while $@
    do
        sleep 1
    done
}

function sleepwhilenot {
    while ! $@
    do
        sleep 1
    done
}

function volume_is_available {
    cinder list | grep $1 | grep available
}

function volume_exists {
    cinder list | grep $1
}

function instance_active {
    nova list | grep $1 | grep ACTIVE
}

function instance_exists {
    nova list | grep $1
}
