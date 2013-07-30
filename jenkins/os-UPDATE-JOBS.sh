#!/bin/bash
set -exu

JENKINS_URL="http://bronze.eng.hq.xensource.com:8080"

[ -e jenkins-cli.jar ] || wget "$JENKINS_URL/jnlpJars/jenkins-cli.jar"

function cli
{
    java -jar jenkins-cli.jar  -s "$JENKINS_URL" "$@"
}

TEMPLATEJOB=`tempfile`

cli get-job "os-TEMPLATE_JOB" > "$TEMPLATEJOB"

function generate_job() {
    sed -e "s/TEST_TYPE_DEFAULT/$1/g" -e "s/SETUP_TYPE_DEFAULT/$2/g" "$TEMPLATEJOB"
}

for branch in trunk ctx; do
    for test_type in smoke full; do
      for setup_type in nova-network neutron; do
        jobname="os-$branch-$setup_type-$test_type"
        generate_job $test_type $setup_type | cli update-job "$jobname"\
          || generate_job $test_type $setup_type | cli create-job "$jobname"
      done
    done
done


 rm -f $TEMPLATEJOB jenkins-cli.jar
