# --- AUTHENTICATION HELPERS ---

#' Generate a 6-digit OTP
#' @return String
generate_otp <- function() {
    paste0(sample(0:9, 6, replace = TRUE), collapse = "")
}

#' Send Email with OTP
#' Uses blastula if available and configured, otherwise prints to console
#' @param to_email String
#' @param otp_code String
#' @return Boolean (Success/Fail)
send_otp_email <- function(to_email, otp_code) {
    # Check for SMTP credentials
    smtp_user <- Sys.getenv("SMTP_USER")
    smtp_pass <- Sys.getenv("SMTP_PASS")
    smtp_host <- Sys.getenv("SMTP_HOST")

    # Check if blastula is installed
    has_blastula <- requireNamespace("blastula", quietly = TRUE)

    if (has_blastula && nzchar(smtp_user) && nzchar(smtp_pass) && nzchar(smtp_host)) {
        tryCatch(
            {
                email <- blastula::compose_email(
                    body = blastula::md(glue::glue("
          ## Atmotube Dashboard Verification

          Your verification code is: **{otp_code}**

          This code will expire in 10 minutes.
        "))
                )

                blastula::smtp_send(
                    email = email,
                    to = to_email,
                    from = smtp_user,
                    subject = "Your Verification Code",
                    credentials = blastula::creds_envvar(
                        user = smtp_user,
                        pass_envvar = "SMTP_PASS",
                        provider = NULL,
                        host = "smtp.gmail.com",
                        port = 465, # SSL connection required
                        use_ssl = TRUE
                    )
                )
                return(TRUE)
            },
            error = function(e) {
                warning("Email sending failed: ", e$message)
                return(FALSE)
            }
        )
    } else {
        warning("Email sending skipped: SMTP credentials missing or blastula not installed.")
        return(FALSE)
    }
}

#' Login UI
login_ui <- function() {
    shiny::div(
        style = "max-width: 400px; margin: 100px auto; padding: 20px; background: #fff; border-radius: 5px; box-shadow: 0 0 10px rgba(0,0,0,0.1);",
        shiny::h2("Login", style = "text-align: center;"),
        shiny::textInput("auth_email", "Email Address", placeholder = "user@example.com", width = "100%"),
        shiny::actionButton("auth_send_code", "Send Verification Code", class = "btn-primary btn-block", width = "100%")
    )
}

#' Verify UI
verify_ui <- function(email) {
    shiny::div(
        style = "max-width: 400px; margin: 100px auto; padding: 20px; background: #fff; border-radius: 5px; box-shadow: 0 0 10px rgba(0,0,0,0.1);",
        shiny::h2("Verification", style = "text-align: center;"),
        shiny::p(paste("Enter the code sent to", email), style = "text-align: center; color: #666;"),
        shiny::textInput("auth_otp_input", "Verification Code", placeholder = "123456", width = "100%"),
        shiny::actionButton("auth_verify_code", "Verify & Login", class = "btn-success btn-block", width = "100%"),
        shiny::br(), shiny::br(),
        shiny::actionLink("auth_back_login", "Back to Login")
    )
}
