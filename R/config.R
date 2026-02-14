# --- CONFIGURATION ---
# Central configuration for thresholds, settings, and magic numbers.
# Edit these values to customize the dashboard behavior.

CONFIG <- list(
    # Data source
    csv_file = "atmotube_pro2_export_sample_default.csv",


    # QA/QC Thresholds
    qaqc = list(
        battery_threshold = 20,
        gps_error_threshold = 20
    ),

    # Access Control (Whitelist)
    # Only emails in this list can log in.
    allowed_emails = c(
        "test@example.com", # For testing
        "admin@gmail.com", # Example admin
        "phamquangd9@gmail.com",
        "jackdaboiiii@gmail.com"
        # Add more emails here
    ),

    # Map Settings
    # Map Settings
    map = list(
        provider = "CartoDB.Positron", # Reverting to original light map
        marker_radius = 6,
        marker_opacity = 0.8,
        color_palette = "RdYlGn", # Red-Yellow-Green for gradient
        palette_reverse = TRUE, # Reverse so Green is Low (Good) and Red is High (Bad)
        line_weight = 5,
        line_opacity = 0.8
    ),

    # UI Settings
    ui = list(
        table_page_length = 10,
        qaqc_table_page_length = 5,
        map_height = "550px"
    ),

    # Variable choices for dropdown
    variable_choices = c(
        "PM 2.5" = "PM25",
        "PM 10" = "PM10",
        "PM 1.0" = "PM1",
        "AQS" = "AQS",
        "Temperature" = "Temperature",
        "Humidity" = "Humidity",
        "TVOC" = "TVOC",
        "CO2" = "CO2"
    ),

    # Column name mapping (CSV header -> clean R name)
    column_map = c(
        "Date (UTC+00:00)" = "Date",
        "AQS" = "AQS",
        "PM1.0 (\u00b5g/m\u00b3)" = "PM1",
        "PM2.5 (\u00b5g/m\u00b3)" = "PM25",
        "PM10 (\u00b5g/m\u00b3)" = "PM10",
        "Temperature (\u00b0C)" = "Temperature",
        "Humidity (%)" = "Humidity",
        "Pressure (hPa)" = "Pressure",
        "TVOC Index" = "TVOC_Index",
        "TVOC (ppm)" = "TVOC",
        "NOx Index" = "NOx_Index",
        "CO2 (ppm)" = "CO2",
        "Latitude" = "Latitude",
        "Longitude" = "Longitude",
        "Altitude (m)" = "Altitude",
        "Position Error (m)" = "Position_Error",
        "Battery (%)" = "Battery"
    )
)
