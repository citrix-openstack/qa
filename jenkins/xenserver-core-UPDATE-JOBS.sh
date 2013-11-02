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

cli get-job "TEMPLATE-run-infinite-migration" > "$TEMPLATEJOB"

function generate_job() {
    cat "$TEMPLATEJOB"
}

for name in 1 2 3; do
    jobname="infinite-migration-DEMO-$name"
    generate_job | cli update-job "$jobname"\
      || generate_job | cli create-job "$jobname"
done

rm -f $TEMPLATEJOB jenkins-cli.jar
