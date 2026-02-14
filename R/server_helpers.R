# --- SERVER HELPERS ---

#' Filter data by date range and sensor
#' @param data The full dataset
#' @param date_range A vector of two dates (start, end)
#' @param sensor_id The selected sensor ID or "All"
#' @return Filtered dataframe
filter_data <- function(data, date_range, sensor_id) {
    start_date <- as.POSIXct(date_range[1])
    end_date <- as.POSIXct(date_range[2]) + lubridate::days(1) - lubridate::seconds(1)

    filtered <- data %>%
        dplyr::filter(Date >= start_date & Date <= end_date)

    if (sensor_id != "All") {
        filtered <- filtered %>% dplyr::filter(Sensor_ID == sensor_id)
    }

    return(filtered)
}

#' Get low battery readings
#' @param data The filtered dataset
#' @return Dataframe of low battery entries
get_low_battery <- function(data) {
    data %>%
        dplyr::filter(Battery < CONFIG$qaqc$battery_threshold) %>%
        dplyr::select(Date, Sensor_ID, Battery)
}

#' Get high GPS error readings
#' @param data The filtered dataset
#' @return Dataframe of high GPS error entries
get_high_gps_error <- function(data) {
    data %>%
        dplyr::filter(Position_Error > CONFIG$qaqc$gps_error_threshold) %>%
        dplyr::select(Date, Sensor_ID, Latitude, Longitude, Position_Error)
}

#' Count rows with missing values
#' @param data The filtered dataset
#' @return Integer count of incomplete rows
count_missing_values <- function(data) {
    sum(!complete.cases(data))
}

#' Get rows with missing values
#' @param data The filtered dataset
#' @return Dataframe of rows with missing data indicators
get_missing_data_rows <- function(data) {
    # Get rows that have any missing values
    incomplete_rows <- data[!complete.cases(data), ]

    if (nrow(incomplete_rows) == 0) {
        return(data.frame(
            Date = character(),
            Sensor_ID = character(),
            Missing_Columns = character()
        ))
    }

    # For each incomplete row, identify which columns have NA
    missing_info <- incomplete_rows %>%
        dplyr::mutate(
            Missing_Columns = apply(incomplete_rows, 1, function(row) {
                na_cols <- names(row)[is.na(row)]
                paste(na_cols, collapse = ", ")
            })
        ) %>%
        dplyr::select(Date, Sensor_ID, Missing_Columns)

    return(missing_info)
}

#' Render the leaflet map
#' @param data The filtered dataset
#' @param variable The selected variable to color by
#' @return A leaflet map object
render_sensor_map <- function(data, variable) {
    if (nrow(data) == 0) {
        return(NULL)
    }

    # Determine palette settings based on global config or data fallback
    var_conf <- CONFIG$map$variable_settings[[variable]]

    if (!is.null(var_conf)) {
        domain_range <- var_conf$domain
        reverse_pal <- var_conf$reverse
    } else {
        # Fallback: Use data range and default reverse setting
        domain_range <- range(data[[variable]], na.rm = TRUE, finite = TRUE)
        reverse_pal <- if (!is.null(CONFIG$map$palette_reverse)) CONFIG$map$palette_reverse else FALSE
    }

    pal <- leaflet::colorNumeric(
        palette = CONFIG$map$color_palette,
        domain = domain_range,
        reverse = reverse_pal,
        na.color = "transparent"
    )

    # Initialize map
    map <- leaflet::leaflet(data) %>%
        leaflet::addProviderTiles(CONFIG$map$provider)

    # Add polylines for each sensor's route (Gradient Segments)
    sensors <- unique(data$Sensor_ID)
    for (sensor in sensors) {
        sensor_data <- data[data$Sensor_ID == sensor, ]
        # Ensure data is sorted by time for correct path
        sensor_data <- sensor_data[order(sensor_data$Date), ]

        # Gradient Lines: Draw segments
        if (nrow(sensor_data) > 1) {
            for (i in 1:(nrow(sensor_data) - 1)) {
                # Segment coordinates
                lng <- c(sensor_data$Longitude[i], sensor_data$Longitude[i + 1])
                lat <- c(sensor_data$Latitude[i], sensor_data$Latitude[i + 1])
                # Value for color (use starting point value)
                val <- sensor_data[[variable]][i]
                # Skip NA values for color mapping to avoid errors
                if (!is.na(val)) {
                    map <- map %>% leaflet::addPolylines(
                        lng = lng, lat = lat,
                        color = pal(val),
                        weight = CONFIG$map$line_weight,
                        opacity = CONFIG$map$line_opacity,
                        group = "Routes"
                    )
                }
            }

            # Direction Indicators (Start/End)
            # Start: Green, distinct style
            map <- map %>% leaflet::addCircleMarkers(
                lng = sensor_data$Longitude[1],
                lat = sensor_data$Latitude[1],
                color = "green", opacity = 1, fillOpacity = 1,
                radius = 7, weight = 2,
                popup = paste("<strong>Start</strong><br>", sensor_data$Date[1])
            )

            # End: Red, distinct style
            map <- map %>% leaflet::addCircleMarkers(
                lng = tail(sensor_data$Longitude, 1),
                lat = tail(sensor_data$Latitude, 1),
                color = "red", opacity = 1, fillOpacity = 1,
                radius = 7, weight = 2,
                popup = paste("<strong>End</strong><br>", tail(sensor_data$Date, 1))
            )
        }
    }

    # Add regular markers and legend
    map %>%
        leaflet::addCircleMarkers(
            ~Longitude, ~Latitude,
            color = ~ pal(data[[variable]]),
            stroke = FALSE,
            fillOpacity = CONFIG$map$marker_opacity,
            radius = CONFIG$map$marker_radius,
            popup = ~ paste(
                "<strong>Sensor:</strong>", Sensor_ID, "<br>",
                "<strong>Participant:</strong>", Participant_ID, "<br>",
                "<strong>Time:</strong>", format(Date, "%H:%M:%S"), "<br>",
                "<strong>Battery:</strong>", Battery, "%<br>",
                "<strong>", variable, ":</strong>", data[[variable]]
            )
        ) %>%
        leaflet::addLegend(
            "bottomright",
            pal = pal,
            values = data[[variable]],
            title = variable,
            opacity = 1
        )
}

#' Render the time series trend plot
#' @param data The filtered dataset
#' @param variable The selected variable to plot
#' @return A ggplot object
render_trend_plot <- function(data, variable) {
    ggplot2::ggplot(data, ggplot2::aes(x = Date, y = .data[[variable]], color = Sensor_ID)) +
        ggplot2::geom_line(linewidth = 1) +
        ggplot2::theme_minimal() +
        ggplot2::labs(y = variable, title = paste(variable, "over Time"))
}
