#!/bin/bash

# Paths to the files
mode_file="/home/pi/data/mode.txt"
last_config_file="/home/pi/data/last_config.txt"

# Read the mode from the mode.txt file
mode=$(awk 'NR==1{print $1}' "$mode_file")

# Check if the last_config.txt file exists
if [ -f "$last_config_file" ]; then
    # Read the stored date from the file
    last_time=$(stat -c %Y "$last_config_file")
    echo "$last_time"
else
    # If the file does not exist, initialize last_time to 0
    last_time=0
fi

# Get the current date in seconds since Unix epoch
current_time=$(date +%s)

# Calculate the difference in seconds
time_diff=$((current_time - last_time))

# Calculate the absolute value of time_diff
if [ "$time_diff" -lt 0 ]; then
    time_diff=$((time_diff * -1))
fi

# Display the mode
echo "Mode: $mode"
# Check if the mode is different from "sleepy"
if [ "$mode" != "sleepy" ]; then
    echo "The mode is not 'sleepy'. Launching the script..."
    # Launch the config.sh script
    sudo /home/pi/scripts/config.sh
elif [ $time_diff -gt 540 ]; then
    echo "More than 9 minutes have passed since the last configuration. Launching the script..."
    sudo /home/pi/scripts/config.sh
fi
