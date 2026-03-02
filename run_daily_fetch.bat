@echo off
REM Batch script to run the Atmotube API daily fetch script
REM You can double-click this to run it manually,
REM or add this file to Windows Task Scheduler to run daily at midnight.

echo [%date% %time%] Running Atmotube Daily Fetch...
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" fetch_daily_data.R

echo.
echo [%date% %time%] Pushing updated data to shinyapps.io...
"C:\Program Files\R\R-4.5.2\bin\Rscript.exe" auto_deploy_app.R

echo.
echo [%date% %time%] Process Complete.
IF "%1"=="--pause" pause
