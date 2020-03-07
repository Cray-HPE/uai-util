@Library("dst-shared") _
rpmBuild (
    channel: "casm-user",
    slack_notify: ['FAILURE'],
    product: "shasta-premium",
    target_node: "cn,ncn",
    fanout_params: ["sle15", "sle15sp1"],
    unitTestScript: "./test/runUnitTests.sh"
)
