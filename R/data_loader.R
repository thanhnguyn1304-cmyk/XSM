# --- DATA LOADING & MOCK DATA GENERATION ---

#' Load and clean sensor data from CSV
#' @return A cleaned dataframe with standardized column names
load_data <- function() {
    message("Attempting to read CSV...")

    # Try reading with UTF-8 encoding first

    data <- tryCatch(
        {
            read.csv(CONFIG$csv_file,
                stringsAsFactors = FALSE,
                check.names = FALSE,
                fileEncoding = "UTF-8"
            )
        },
        error = function(e) {
            message("Error reading with UTF-8, trying default encoding...")
            read.csv(CONFIG$csv_file,
                stringsAsFactors = FALSE,
                check.names = FALSE
            )
        }
    )

    message(sprintf("CSV Read Successful. Rows: %d, Columns: %d", nrow(data), ncol(data)))

    # Rename columns using config map
    data <- rename_columns(data, CONFIG$column_map)

    # Parse dates
    data$Date <- lubridate::ymd_hms(data$Date)
    if (all(is.na(data$Date))) {
        warning("Date parsing failed. All dates are NA.")
    }

    # Add default sensor/participant IDs
    data$Sensor_ID <- "Sensor_A"
    data$Participant_ID <- "A001"

    return(data)
}

#' Rename columns based on a mapping
#' @param data Dataframe to rename
#' @param name_map Named vector: original_name = new_name
#' @return Dataframe with renamed columns
rename_columns <- function(data, name_map) {
    # Check for missing columns and attempt fuzzy matching
    missing_cols <- setdiff(names(name_map), colnames(data))

    if (length(missing_cols) > 0) {
        message("Some expected columns not found. Attempting partial matching...")
        # Fuzzy match for common encoding issues
        for (pattern in c("PM2.5", "PM1.0", "PM10", "Temperature")) {
            matches <- grep(pattern, colnames(data), value = TRUE)
            if (length(matches) > 0) {
                target_name <- names(name_map)[grep(pattern, names(name_map))[1]]
                if (!is.na(target_name)) {
                    colnames(data)[colnames(data) == matches[1]] <- target_name
                }
            }
        }
    }

    # Apply direct renaming
    rename_list <- setNames(names(name_map), name_map)
    for (new_name in names(rename_list)) {
        old_name <- rename_list[[new_name]]
        if (old_name %in% colnames(data)) {
            colnames(data)[colnames(data) == old_name] <- new_name
        }
    }

    return(data)
}

#' Create mock sensor data with optional errors for QA/QC testing
#' @param base_data The original dataframe to duplicate
#' @param sensor_id New sensor ID
#' @param participant_id New participant ID
#' @param lat_offset Latitude offset
#' @param lon_offset Longitude offset
#' @param pm25_multiplier PM2.5 value multiplier
#' @param error_type One of: "none", "low_battery", "high_gps_error", "missing_values"
#' @return Mock sensor dataframe
create_mock_sensor <- function(base_data,
                               sensor_id,
                               participant_id,
                               lat_offset = 0,
                               lon_offset = 0,
                               pm25_multiplier = 1,
                               error_type = "none") {
    mock_data <- base_data %>%
        dplyr::mutate(
            Sensor_ID = sensor_id,
            Participant_ID = participant_id,
            Latitude = Latitude + lat_offset,
            Longitude = Longitude + lon_offset,
            PM25 = PM25 * pm25_multiplier
        )

    # Inject specific errors based on type
    if (error_type == "low_battery") {
        mock_data <- mock_data %>%
            dplyr::mutate(Battery = sample(c(5, 10, 15, 18), dplyr::n(), replace = TRUE))
    } else if (error_type == "high_gps_error") {
        mock_data <- mock_data %>%
            dplyr::mutate(Position_Error = sample(c(25, 35, 50, 100), dplyr::n(), replace = TRUE))
    } else if (error_type == "missing_values") {
        mock_data <- mock_data %>%
            dplyr::mutate(
                PM25 = ifelse(dplyr::row_number() %% 3 == 0, NA, PM25),
                Temperature = ifelse(dplyr::row_number() %% 5 == 0, NA, Temperature)
            )
    }

    return(mock_data)
}

#' Load all sensor data (real + mock)
#' @return Combined dataframe with all sensors
load_all_sensors <- function() {
    raw_data <- load_data()

    # Generate mock sensors
    sensor_b <- create_mock_sensor(raw_data, "Sensor_B", "A002",
        lat_offset = 0.001, lon_offset = 0.001,
        pm25_multiplier = 1.1
    )

    sensor_c <- create_mock_sensor(raw_data, "Sensor_C", "A003",
        lat_offset = 0.002, lon_offset = -0.001,
        pm25_multiplier = 0.9, error_type = "low_battery"
    )

    sensor_d <- create_mock_sensor(raw_data, "Sensor_D", "A004",
        lat_offset = -0.001, lon_offset = 0.002,
        pm25_multiplier = 1.2, error_type = "high_gps_error"
    )

    sensor_e <- create_mock_sensor(raw_data, "Sensor_E", "A005",
        lat_offset = -0.002, lon_offset = -0.002,
        pm25_multiplier = 1.0, error_type = "missing_values"
    )

    combined <- dplyr::bind_rows(raw_data, sensor_b, sensor_c, sensor_d, sensor_e)
    message(sprintf("Combined Data Rows: %d", nrow(combined)))

    return(combined)
}
