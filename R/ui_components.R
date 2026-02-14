# --- UI COMPONENTS ---

#' Create a styled KPI box for the dashboard
#' @param title The title of the KPI
#' @param output_id The Shiny output ID to display
#' @param bg_color Background color (hex)
#' @return A Shiny column with styled div
create_kpi_box <- function(title, output_id, bg_color = "#f5f5f5") {
    shiny::column(
        3,
        shiny::div(
            style = sprintf(
                "background-color: %s; color: #333333; padding: 10px; border-radius: 5px; text-align: center;",
                bg_color
            ),
            shiny::h4(title),
            shiny::textOutput(output_id)
        )
    )
}

#' Build the sidebar panel with filters
#' @param sensor_choices Vector of sensor IDs
#' @return sidebarPanel element
build_sidebar <- function(sensor_choices) {
    shiny::sidebarPanel(
        shiny::h4("Filters"),
        shiny::uiOutput("dateRangeUI"),
        shiny::selectInput("variable", "Select Variable to Visualize:",
            choices = CONFIG$variable_choices,
            selected = "PM25"
        ),
        shiny::selectInput("sensor", "Select Sensor ID:",
            choices = c("All", sensor_choices),
            selected = "All"
        ),
        shiny::hr(),
        shiny::helpText("Data source: Atmotube Pro Export"),
        shiny::textOutput("debugMsg")
    )
}

#' Build the main dashboard tab
#' @return tabPanel element
build_dashboard_tab <- function() {
    shiny::tabPanel(
        "Dashboard",
        shiny::br(),
        shiny::fluidRow(
            create_kpi_box("Total Readings", "total_readings", "#f5f5f5"),
            create_kpi_box("Avg Value", "avg_value", "#e6f3ff"),
            create_kpi_box("Date Start", "date_start", "#fff0db"),
            create_kpi_box("Date End", "date_end", "#e8f5e9")
        ),
        shiny::br(),
        shiny::h3("Sensor Locations"),
        leaflet::leafletOutput("map", height = CONFIG$ui$map_height),
        shiny::br(),
        shiny::h3("Time Series Trends"),
        shiny::plotOutput("trendPlot")
    )
}

#' Build the QA/QC tab
#' @return tabPanel element
build_qaqc_tab <- function() {
    shiny::tabPanel(
        "QA/QC",
        shiny::br(),
        shiny::h3("Quality Assurance Checks"),
        shiny::h4(sprintf("1. Low Battery Warnings (< %d%%)", CONFIG$qaqc$battery_threshold)),
        DT::DTOutput("batteryTable"),
        shiny::br(),
        shiny::h4(sprintf("2. High Position Error (> %dm)", CONFIG$qaqc$gps_error_threshold)),
        DT::DTOutput("gpsTable"),
        shiny::br(),
        shiny::h4("3. Missing Data Check"),
        DT::DTOutput("missingDataTable"),
        shiny::textOutput("missingDataSummary")
    )
}
