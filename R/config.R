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
        "thanhnguyn1304@gmail.com",
        "tung.pt@vinuni.edu.vn",
        "gillott.s@vinuni.edu.vn",
        "linh.bp@vinuni.edu.vn",
        "vy.ntt@vinuni.edu.vn",
        "tho.nta@vinuni.edu.vn",
        "thao.ttp@vinuni.edu.vn"
        # Add more emails here
    ),

    # Map Settings
    # Map Settings
    map = list(
        provider = "CartoDB.Positron",
        marker_radius = 5, # Increased to 5 for easier clicking
        marker_opacity = 0.8,
        color_palette = "RdYlGn", # Base Palette: Red -> Yellow -> Green
        line_weight = 4, # Increased to 4 for balance
        line_opacity = 0.8,

        # Standard Health Thresholds for Color Scale
        # domain: c(min, max) for the color mapping
        # reverse: TRUE means Low=Green (Good), High=Red (Bad)
        # reverse: FALSE means Low=Red (Bad), High=Green (Good)
        variable_settings = list(
            "PM1" = list(domain = c(0, 50), reverse = TRUE),
            "PM25" = list(domain = c(0, 50), reverse = TRUE), # Good < 12, Unhealthy > 35
            "PM10" = list(domain = c(0, 100), reverse = TRUE), # Good < 50
            "TVOC" = list(domain = c(0, 1.0), reverse = TRUE), # Good < 0.5 ppm
            "TVOC_Index" = list(domain = c(0, 500), reverse = TRUE), # Index usually 0-500
            "CO2" = list(domain = c(400, 2000), reverse = TRUE), # Good < 1000 ppm
            "AQS" = list(domain = c(0, 100), reverse = FALSE), # 100 is Best (Green)
            "Temperature" = list(domain = c(0, 40), reverse = TRUE), # Hotter = Redder
            "Humidity" = list(domain = c(0, 100), reverse = TRUE), # Wet = Blue/Green? Just standard 0-100
            "Pressure" = list(domain = c(950, 1050), reverse = FALSE)
        )
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
