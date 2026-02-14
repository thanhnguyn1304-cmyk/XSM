# ============================================================================
# Atmotube Pro Dashboard
# Main entry point - sources modular helpers and runs the Shiny app
# ============================================================================

# --- LIBRARIES ---
library(shiny)
library(leaflet)
library(dplyr)
library(ggplot2)
library(lubridate)
library(DT)

# --- SOURCE MODULES ---
source("R/config.R")
source("R/data_loader.R")
source("R/ui_components.R")
source("R/server_helpers.R")
source("R/auth_helpers.R") # New Auth Module

# --- LOAD DATA ---
combined_data <- load_all_sensors()

# --- UI ---
ui <- shiny::fluidPage(
  shiny::titlePanel("Atmotube Pro Dashboard"),
  # Container for dynamic content (Login -> Verify -> Dashboard)
  shiny::uiOutput("page_content")
)

# --- SERVER ---
server <- function(input, output, session) {
  # Reactive Values for Auth State
  user_auth <- shiny::reactiveValues(
    state = "login", # "login", "verify", "dashboard"
    email = NULL,
    otp = NULL,
    otp_expiry = NULL
  )

  # --- UI RENDERER ---
  output$page_content <- shiny::renderUI({
    if (user_auth$state == "login") {
      login_ui()
    } else if (user_auth$state == "verify") {
      verify_ui(user_auth$email)
    } else if (user_auth$state == "dashboard") {
      # Render the main dashboard UI
      shiny::sidebarLayout(
        build_sidebar(unique(combined_data$Sensor_ID)),
        shiny::mainPanel(
          shiny::tabsetPanel(
            build_dashboard_tab(),
            shiny::tabPanel("Data", shiny::br(), DT::DTOutput("dataTable")),
            build_qaqc_tab()
          )
        )
      )
    }
  })

  # --- AUTH LOGIC ---

  # 1. Send Code
  shiny::observeEvent(input$auth_send_code, {
    email <- input$auth_email
    # Basic validation
    if (is.null(email) || !nzchar(email) || !grepl("@", email)) {
      shiny::showNotification("Please enter a valid email address.", type = "error")
      return()
    }

    # Access Control Check
    if (!email %in% CONFIG$allowed_emails) {
      shiny::showNotification("Access Denied: This email is not authorized.", type = "error")
      return()
    }

    # Generate OTP
    otp <- generate_otp()
    user_auth$otp <- otp
    user_auth$email <- email
    user_auth$otp_expiry <- Sys.time() + 600 # 10 mins expiry

    # Send Email (Mock or Real)
    success <- send_otp_email(email, otp)

    if (success) {
      user_auth$state <- "verify"
      shiny::showNotification("Verification code sent! Check your email (or console).", type = "message")
    } else {
      shiny::showNotification("Failed to send email. Check logs.", type = "error")
    }
  })

  # 2. Verify Code
  shiny::observeEvent(input$auth_verify_code, {
    input_otp <- input$auth_otp_input

    if (is.null(input_otp) || !nzchar(input_otp)) {
      shiny::showNotification("Please enter the code.", type = "warning")
      return()
    }

    if (input_otp == user_auth$otp) {
      # Success
      user_auth$state <- "dashboard"
      shiny::showNotification("Login Successful!", type = "message")
    } else {
      # Failure
      shiny::showNotification("Invalid code. Please try again.", type = "error")
    }
  })

  # 3. Back to Login
  shiny::observeEvent(input$auth_back_login, {
    user_auth$state <- "login"
    user_auth$otp <- NULL
  })

  # --- DASHBOARD LOGIC (Runs only when needed, but server code loads globally) ---
  # Note: Observers for dashboard inputs will just be idle until UI elements exist.

  # Dynamic date range picker
  output$dateRangeUI <- shiny::renderUI({
    if (nrow(combined_data) > 0 && !all(is.na(combined_data$Date))) {
      shiny::dateRangeInput("dateRange", "Select Date Range:",
        start = min(combined_data$Date, na.rm = TRUE),
        end = max(combined_data$Date, na.rm = TRUE),
        min = min(combined_data$Date, na.rm = TRUE),
        max = max(combined_data$Date, na.rm = TRUE)
      )
    } else {
      shiny::helpText("No valid date data found.")
    }
  })

  # Reactive filtered data
  filtered_data <- shiny::reactive({
    shiny::req(input$dateRange)
    filter_data(combined_data, input$dateRange, input$sensor)
  })

  # --- KPI Outputs ---
  output$total_readings <- shiny::renderText({
    nrow(filtered_data())
  })

  output$avg_value <- shiny::renderText({
    val <- filtered_data()[[input$variable]]
    if (length(val) > 0) round(mean(val, na.rm = TRUE), 2) else "N/A"
  })

  output$date_start <- shiny::renderText({
    if (nrow(filtered_data()) > 0) as.character(min(filtered_data()$Date)) else "N/A"
  })

  output$date_end <- shiny::renderText({
    if (nrow(filtered_data()) > 0) as.character(max(filtered_data()$Date)) else "N/A"
  })

  # --- Map ---
  output$map <- leaflet::renderLeaflet({
    render_sensor_map(filtered_data(), input$variable)
  })

  # --- Trend Plot ---
  output$trendPlot <- shiny::renderPlot({
    shiny::req(nrow(filtered_data()) > 0)
    render_trend_plot(filtered_data(), input$variable)
  })

  # --- Data Table ---
  output$dataTable <- DT::renderDT({
    DT::datatable(filtered_data(), options = list(
      pageLength = CONFIG$ui$table_page_length,
      scrollX = TRUE
    ))
  })

  # --- QA/QC Tables ---
  output$batteryTable <- DT::renderDT({
    low_batt <- get_low_battery(filtered_data())
    DT::datatable(low_batt,
      options = list(pageLength = CONFIG$ui$qaqc_table_page_length),
      caption = "Sensors with low battery"
    )
  })

  output$gpsTable <- DT::renderDT({
    bad_gps <- get_high_gps_error(filtered_data())
    DT::datatable(bad_gps,
      options = list(pageLength = CONFIG$ui$qaqc_table_page_length),
      caption = "Readings with high GPS error"
    )
  })

  output$missingDataTable <- DT::renderDT({
    missing_rows <- get_missing_data_rows(filtered_data())
    DT::datatable(missing_rows,
      options = list(pageLength = CONFIG$ui$qaqc_table_page_length),
      caption = "Rows with missing values"
    )
  })

  output$missingDataSummary <- shiny::renderText({
    missing_count <- count_missing_values(filtered_data())
    if (missing_count > 0) {
      paste("Found", missing_count, "rows with missing values.")
    } else {
      "No missing values found."
    }
  })

  # --- Debug Output ---
  output$debugMsg <- shiny::renderText({
    paste(
      "Debug: Loaded", nrow(combined_data), "rows. Date range:",
      min(combined_data$Date, na.rm = TRUE), "to",
      max(combined_data$Date, na.rm = TRUE)
    )
  })
}

# --- RUN APP ---
shiny::shinyApp(ui = ui, server = server)
