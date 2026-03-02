# auto_deploy_app.R
# This script is meant to be run automatically by the Task Scheduler
# It deploys the app to shinyapps.io without prompting for confirmation.

library(rsconnect)

# Explicitly list the files to include .Renviron (which contains secrets)
files_to_deploy <- c(
    "app.R",
    ".Renviron",
    "atmotube_pro2_export_sample_default.csv",
    list.files("R", full.names = TRUE)
)

message(sprintf("[%s] Starting automatic deployment to shinyapps.io...", Sys.time()))
tryCatch(
    {
        deployApp(appFiles = files_to_deploy, forceUpdate = TRUE)
        message(sprintf("[%s] Deployment successful!", Sys.time()))
    },
    error = function(e) {
        message(sprintf("[%s] Deployment failed: %s", Sys.time(), e$message))
        quit(status = 1)
    }
)
