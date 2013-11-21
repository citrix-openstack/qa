#!/bin/bash
set -exu

JENKINS_URL="http://bronze.eng.hq.xensource.com:8080"

USERNAME="$1"
PASSWORD="$2"

[ -e jenkins-cli.jar ] || wget "$JENKINS_URL/jnlpJars/jenkins-cli.jar"

function cli
{
    java -jar jenkins-cli.jar  -s "$JENKINS_URL" "$@" --username "$USERNAME" --password "$PASSWORD"
}

function generate_job() {
    sed -e "s/TEST_TYPE_DEFAULT/$1/g" -e "s/SETUP_TYPE_DEFAULT/$2/g" -e "s/BRANCH_TYPE/$3/g" "$TEMPLATEJOB"
}

function generate_xenserver_core_test_job() {
    sed -e "s/@DISTRO@/$1/g" -e "s/@TEST_TYPE@/$2/g" "$TEMPLATEJOB"
}

function generate_os_test_jobs() {
    cli get-job "os-TEMPLATE_JOB" > "$TEMPLATEJOB"

    for branch in trunk ctx havana; do
        for test_type in smoke full; do
          for setup_type in nova-network neutron; do
            jobname="os-$branch-$setup_type-$test_type"
            generate_job $test_type $setup_type $branch | cli update-job "$jobname"\
              || generate_job $test_type $setup_type $branch | cli create-job "$jobname"
          done
        done
    done
}

function generate_os_high_level_jobs() {
    cli get-job "os-ctx-test" |
        sed \
            -e "s,ADD_CITRIX_CHANGES=true,ADD_CITRIX_CHANGES=false,g" \
            -e "s,os-ctx-,os-trunk-,g" |
                cli update-job "os-trunk-test"
}

function generate_os_high_level_branch_jobs() {
    cli get-job "os-ctx-test" |
        sed \
            -e "s,ADD_CITRIX_CHANGES=true,ADD_CITRIX_CHANGES=false,g" \
            -e "s,os-ctx-,os-havana-,g" \
            -e "s,BASE_BRANCH=origin/master,BASE_BRANCH=stable/havana,g" |
                cli update-job "os-havana-test"
}

function generate_xenserver_core_test_jobs() {
    cli get-job "TEMPLATE-test-xenserver-core-with-os" > "$TEMPLATEJOB"

    for distro in ubuntu centos; do
        for test_type in exercise smoke none; do
            jobname="xenserver-core-$distro-os-$test_type"
            generate_xenserver_core_test_job $distro $test_type | cli update-job "$jobname"\
              || generate_xenserver_core_test_job $distro $test_type | cli create-job "$jobname"
        done
    done
}


TEMPLATEJOB=`tempfile`

if [ -z "${3:-}" ]; then
    generate_os_test_jobs
    generate_os_high_level_jobs
    generate_os_high_level_branch_jobs
    generate_xenserver_core_test_jobs
else
    $3
fi

rm -f $TEMPLATEJOB jenkins-cli.jar
