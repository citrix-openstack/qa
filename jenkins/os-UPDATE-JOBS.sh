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

TEMPLATEJOB=`tempfile`

cli get-job "os-TEMPLATE_JOB" > "$TEMPLATEJOB"

function generate_job() {
    sed -e "s/TEST_TYPE_DEFAULT/$1/g" -e "s/SETUP_TYPE_DEFAULT/$2/g" -e "s/BRANCH_TYPE/$3/g" "$TEMPLATEJOB"
}

for branch in trunk ctx havana; do
    for test_type in smoke full; do
      for setup_type in nova-network neutron; do
        jobname="os-$branch-$setup_type-$test_type"
        generate_job $test_type $setup_type $branch | cli update-job "$jobname"\
          || generate_job $test_type $setup_type $branch | cli create-job "$jobname"
      done
    done
done

cli get-job "os-ctx-test" |
    sed \
        -e "s,ADD_CITRIX_CHANGES=true,ADD_CITRIX_CHANGES=false,g" \
        -e "s,os-ctx-,os-trunk-,g" |
            cli update-job "os-trunk-test"

cli get-job "os-ctx-test" |
    sed \
        -e "s,ADD_CITRIX_CHANGES=true,ADD_CITRIX_CHANGES=false,g" \
        -e "s,os-ctx-,os-havana-,g" |
            cli update-job "os-havana-test"

rm -f $TEMPLATEJOB jenkins-cli.jar
