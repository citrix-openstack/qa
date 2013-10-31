# Tunneling

    ssh -L 5454:instance_ip:80 devstack_ip

# The Movie

    mplayer http://localhost:5454/trailer_480p.mov

# The image

    http://copper.eng.hq.xensource.com/havana-demo/streamer.vhd.tgz

## To save it

    glance image-download --file streamer.vhd.tgz 068b1798-374f-452d-99e7-f8f7bf7b5d39
    scp streamer.vhd.tgz ubuntu@copper.eng.hq.xensource.com:/usr/share/nginx/www/havana-demo/

## To load it

    glance image-create \
        --disk-format=vhd \
        --container-format=ovf \
        --copy-from=http://copper.eng.hq.xensource.com/havana-demo/streamer-coalesced.vhd.tgz \
        --is-public=True \
        --name=streamer

## To start it

    nova boot --flavor m1.medium --image streamer bunnyvm

## Resize

    tar -xzf streamer.vhd.tgz
    vhd-util modify -n 0.vhd -p 1.vhd
    vhd-util modify -n 1.vhd -p 2.vhd
    vhd-util coalesce -n 0.vhd
    vhd-util resize -n 2.vhd -s $(vhd-util query -n 1.vhd -v) -j jounral
    vhd-util coalesce -n 1.vhd
    rm 0.vhd 1.vhd
    mv 2.vhd 0.vhd
    vhd-util set -f hidden -v 0 -n 0.vhd
    tar -czf streamer-coalesced.vhd.tgz 0.vhd
