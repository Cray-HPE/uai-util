@Library("dst-shared@master") _
dockerBuildPipeline {
    repository="cray"
    imagePrefix="cray"
    app="uai-sles15sp2"
    name="cray-uai-sles15sp2"
    description="Cray User Access Instance SLES15SP2"
    includeCharts=false
    slackNotification = ["#casm-cloud-alerts", "", false, false, true, false]
    product = "csm"
    githubPushRepo = "Cray-HPE/uai-util"
}
