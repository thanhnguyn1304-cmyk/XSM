# fetch_daily_data.R
# Script to fetch Atmotube data from API and append to the main CSV file.
# This script is designed to be run via a task scheduler (e.g., Windows Task Scheduler or cron) daily.

library(httr)
library(jsonlite)
library(dplyr)
library(lubridate)

# --- Configuration ---
API_KEY <- Sys.getenv("ATMOTUBE_API_KEY")
if (API_KEY == "") {
    # Fallback to hardcoded key if env var not set
    API_KEY <- "1m8HlFCnBHuxQcW5cW8i98Z4DYOchmxCSLb3P06DrFFQ3THSmtSEW5Qc80Y52rVY"
}
CSV_FILE <- "atmotube_pro2_export_sample_default.csv"

# Time window: past 7 days (to ensure we don't miss days if the PC is off)
end_time <- Sys.time()
start_time <- end_time - days(7)

# Format for API: "2026-03-01T23:56:03Z"
fmt_time <- function(t) {
    format(with_tz(t, "UTC"), "%Y-%m-%dT%H:%M:%SZ")
}

start_date_str <- fmt_time(start_time)
end_date_str <- fmt_time(end_time)

cat(sprintf("[%s] Starting Atmotube daily data fetch...\n", Sys.time()))
cat(sprintf("Fetching data from %s to %s\n", start_date_str, end_date_str))

# 1. Fetch devices
res <- GET("https://api2.atmotube.com/api/v1/devices", add_headers(`X-Api-Key` = API_KEY))
if (status_code(res) != 200) {
    stop("Error fetching devices. Status code: ", status_code(res))
}
devices <- fromJSON(content(res, "text", encoding = "UTF-8"))

if (length(devices$mac) == 0) {
    stop("No devices found for this API key.")
}

all_new_data <- list()

# 2. Fetch measurements for each device (with Pagination)
for (mac in devices$mac) {
    cat(sprintf("Fetching data for MAC: %s\n", mac))

    # Initialize variables for parsing
    cursor <- ""
    device_data_list <- list()
    page <- 1

    while (TRUE) {
        cat(sprintf("  -> Fetching page %d...\n", page))

        # Build URL with cursor if it exists
        cursor_param <- if (nchar(cursor) > 0) sprintf("&cursor=%s", cursor) else ""
        url <- sprintf(
            "https://api2.atmotube.com/api/v1/measurements?mac=%s&start_date=%s&end_date=%s&limit=1440&order=ASC%s",
            mac, start_date_str, end_date_str, cursor_param
        )

        res_meas <- GET(url, add_headers(`X-Api-Key` = API_KEY))

        if (status_code(res_meas) == 200) {
            measurements <- fromJSON(content(res_meas, "text", encoding = "UTF-8"))

            if (is.data.frame(measurements$items) && nrow(measurements$items) > 0) {
                df <- measurements$items
                df$MAC <- mac
                device_data_list[[page]] <- df
                cat(sprintf("     ...downloaded %d rows.\n", nrow(df)))

                # Check for next page
                if (!is.null(measurements$next_cursor) && nchar(measurements$next_cursor) > 0) {
                    cursor <- measurements$next_cursor
                    page <- page + 1
                    # Small delay to respect rate limits
                    Sys.sleep(1)
                } else {
                    cat("     ...Reached end of data for this device.\n")
                    break
                }
            } else {
                cat("     ...No (more) data found in this time window.\n")
                break
            }
        } else {
            cat(sprintf("  -> Error fetching data on page %d for %s: %s\n", page, mac, status_code(res_meas)))
            break
        }
    }

    # Combine all pages for this MAC
    if (length(device_data_list) > 0) {
        all_new_data[[mac]] <- bind_rows(device_data_list)
        cat(sprintf("  -> Total rows downloaded for MAC %s: %d\n", mac, nrow(all_new_data[[mac]])))
    }
}

# 3. Process and append data
if (length(all_new_data) > 0) {
    # Combine all devices
    combined_new <- bind_rows(all_new_data)

    # Ensure all columns exist to avoid errors (fill with NA if missing)
    expected_api_cols <- c(
        "date", "aqs", "pm1", "pm25", "pm10", "t", "h", "p",
        "voc_index", "voc", "nox_index", "co2", "lat", "lon",
        "altitude", "position_error", "battery", "charging", "motion", "recently_charged"
    )

    for (col in expected_api_cols) {
        if (!(col %in% colnames(combined_new))) {
            combined_new[[col]] <- NA
        }
    }

    # Format date to match the CSV's general YYYY-MM-DD HH:MM:SS layout
    combined_new$date <- ymd_hms(combined_new$date)
    combined_new$date <- format(combined_new$date, "%Y-%m-%d %H:%M:%S")

    # Map variables to the CSV Headers so `data_loader.R` can read them
    new_rows <- combined_new %>%
        select(
            `Date (UTC+00:00)` = date,
            `AQS` = aqs,
            `PM1.0 (µg/m³)` = pm1,
            `PM2.5 (µg/m³)` = pm25,
            `PM10 (µg/m³)` = pm10,
            `Temperature (°C)` = t,
            `Humidity (%)` = h,
            `Pressure (hPa)` = p,
            `TVOC Index` = voc_index,
            `TVOC (ppm)` = voc,
            `NOx Index` = nox_index,
            `CO2 (ppm)` = co2,
            `Latitude` = lat,
            `Longitude` = lon,
            `Altitude (m)` = altitude,
            `Position Error (m)` = position_error,
            `Battery (%)` = battery,
            `Charging` = charging,
            `Motion` = motion,
            `Recently Charged` = recently_charged
        )

    # Read existing data (if exists) and append
    if (file.exists(CSV_FILE)) {
        # Check if we are duplicating data
        existing_data <- tryCatch(
            read.csv(CSV_FILE, stringsAsFactors = FALSE, check.names = FALSE),
            error = function(e) data.frame()
        )

        if (nrow(existing_data) > 0 && "Date (UTC+00:00)" %in% colnames(existing_data)) {
            # Filter out rows that are already in the existing data (by date)
            existing_dates <- existing_data$`Date (UTC+00:00)`
            new_rows <- new_rows %>% filter(!(`Date (UTC+00:00)` %in% existing_dates))
        }

        if (nrow(new_rows) > 0) {
            write.table(new_rows,
                file = CSV_FILE, append = TRUE, sep = ",",
                row.names = FALSE, col.names = FALSE
            )
            cat(sprintf("Successfully appended %d new rows to %s.\n", nrow(new_rows), CSV_FILE))
        } else {
            cat("Data already up to date. No new rows appended.\n")
        }
    } else {
        # File doesn't exist, create it
        write.csv(new_rows, CSV_FILE, row.names = FALSE)
        cat(sprintf("Created %s with %d rows.\n", CSV_FILE, nrow(new_rows)))
    }
} else {
    cat("No new data to append.\n")
}

cat("Pipeline finished successfully.\n")
