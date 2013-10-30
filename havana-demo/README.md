# Tunneling

    ssh -L 5454:instance_ip:80 devstack_ip

# The Movie

    mplayer http://localhost:5454/trailer_480p.mov

# The image

    http://copper.eng.hq.xensource.com/havana-demo/streamer.vhd.tgz

## To save it

    glance image-download --file streamer.vhd.tgz 068b1798-374f-452d-99e7-f8f7bf7b5d39

## To load it

    TODO
