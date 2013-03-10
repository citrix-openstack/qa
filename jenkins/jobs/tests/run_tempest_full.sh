set -exu

cd /opt/stack/tempest

nosetests --with-xunit -sv --nologcapture \
-I test_ec2_volumes.py \
-I test_ec2_instance_run.py \
tempest
