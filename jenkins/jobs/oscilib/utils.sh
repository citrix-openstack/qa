#!/bin/bash

function get_ready_node() {
    grep ready | head -1 | tr -d " "
}


function get_node_id() {
    cut -d "|" -f 2
}


function get_node_ip() {
    cut -d "|" -f 10
}
