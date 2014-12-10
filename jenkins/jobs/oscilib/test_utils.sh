set -eux

. utils.sh

function main() {
    test_get_ready_node_empty_output
    test_get_ready_node_one_node_is_ready
    test_get_ready_node_one_node_is_ready_ip
    test_get_ready_node_multiple_ready_nodes
}


function test_get_ready_node_empty_output() {
    RESULT=$(get_ready_node << EOF
EOF
)

    [ -z "$RESULT" ]
}


function test_get_ready_node_one_node_is_ready() {
    NODEID=$(get_ready_node << EOF | get_node_id
+----+----------+------+-------+--------------+-------------------------------------+-----------------+--------------------------------------+----------------+-------+-------------+
| ID | Provider | AZ   | Label | Target       | Hostname                            | NodeName        | Server ID                            | IP             | State | Age (hours) |
+----+----------+------+-------+--------------+-------------------------------------+-----------------+--------------------------------------+----------------+-------+-------------+
| 3  | rax-dfw  | None | DEVCI | fake-jenkins | DEVCI-rax-dfw-3.slave.openstack.org | DEVCI-rax-dfw-3 | a58308e4-d764-44ac-a925-d5f6b7c8d788 | 23.253.109.154 | ready | 0.93        |
+----+----------+------+-------+--------------+-------------------------------------+-----------------+--------------------------------------+----------------+-------+-------------+
EOF
)

    [ "3" = "$NODEID" ]
}


function test_get_ready_node_one_node_is_ready_ip() {
    NODEIP=$(get_ready_node << EOF | get_node_ip
+----+----------+------+-------+--------------+-------------------------------------+-----------------+--------------------------------------+----------------+-------+-------------+
| ID | Provider | AZ   | Label | Target       | Hostname                            | NodeName        | Server ID                            | IP             | State | Age (hours) |
+----+----------+------+-------+--------------+-------------------------------------+-----------------+--------------------------------------+----------------+-------+-------------+
| 3  | rax-dfw  | None | DEVCI | fake-jenkins | DEVCI-rax-dfw-3.slave.openstack.org | DEVCI-rax-dfw-3 | a58308e4-d764-44ac-a925-d5f6b7c8d788 | 23.253.109.154 | ready | 0.93        |
+----+----------+------+-------+--------------+-------------------------------------+-----------------+--------------------------------------+----------------+-------+-------------+
EOF
)

    [ "23.253.109.154" = "$NODEIP" ]
}


function test_get_ready_node_multiple_ready_nodes() {
    NODEID=$(get_ready_node << EOF | get_node_id
+----+----------+------+-------+--------------+-------------------------------------+-----------------+--------------------------------------+----------------+-------+-------------+
| ID | Provider | AZ   | Label | Target       | Hostname                            | NodeName        | Server ID                            | IP             | State | Age (hours) |
+----+----------+------+-------+--------------+-------------------------------------+-----------------+--------------------------------------+----------------+-------+-------------+
| 3  | rax-dfw  | None | DEVCI | fake-jenkins | DEVCI-rax-dfw-3.slave.openstack.org | DEVCI-rax-dfw-3 | a58308e4-d764-44ac-a925-d5f6b7c8d788 | 23.253.109.154 | ready | 0.93        |
| 4  | rax-dfw  | None | DEVCI | fake-jenkins | DEVCI-rax-dfw-4.slave.openstack.org | DEVCI-rax-dfw-3 | a58308e4-d764-44ac-a925-d5f6b7c8d788 | 23.253.109.155 | ready | 0.93        |
+----+----------+------+-------+--------------+-------------------------------------+-----------------+--------------------------------------+----------------+-------+-------------+
EOF
)

    [ "3" = "$NODEID" ]
}


main
