@Library("dst-shared@release/shasta-1.4") _
dockerBuildPipeline {
    repository="cray"
    imagePrefix="cray"
    app="uai-sles15sp1"
    name="cray-uai-sles15sp1"
    description="Cray User Access Instance SLES15SP1"
    includeCharts=false
    slackNotification = ["#casm-cloud-alerts", "", false, false, true, false]
    product = "csm"
    githubPushRepo = "Cray-HPE/uai-util"
}
