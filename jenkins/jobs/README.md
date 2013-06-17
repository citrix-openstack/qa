# Jobs

## Generic Jobs

 - [Create a Devbox](./create-devbox.sh) Configure a slave to become a devbox.
   A devbox is connected to two networks. Getting IP with DHCP on `eth0` and
   serving DHCP/DNS requests on `eth1` (lab network). This is useful to create
   an isolated environment.

## SmokeStack Related

 - [Setup Lab](./setup-lab.sh) Setup a small lab environment: a devbox, and a
   virtual xenserver on the lab network.
 - [Setup a Smokestack node](./lab-setup-smoke.sh) Setup a SmokeStack worker
   inside your lab setup.
