#!/bin/bash
#
# Function to download and extract the source code from the release
download_and_update() {
    DOWNLOAD_URL=$1
    TARGET_DIR=$2
    REPO_API=$3

    # Create the target directory if it does not exist
    mkdir -p $TARGET_DIR
    
    # Remove existing files in the target directory if any
    if [ "$(ls -A "$TARGET_DIR")" ]; then
        rm -r "$TARGET_DIR"/*
    fi
    cd "$TARGET_DIR" || { echo "Error: Unable to change directory to $TARGET_DIR"; return; }

    # Retrieve the latest release information
    release_info=$(curl -s -H "Authorization: token $TOKEN" "$REPO_API")

    # Extract asset URLs and filenames
    asset_urls=($(echo "$release_info" | jq -r '.assets[].url'))
    asset_names=($(echo "$release_info" | jq -r '.assets[].name'))

    # Download each asset
    for i in "${!asset_urls[@]}"; do
        url="${asset_urls[$i]}"
        name="${asset_names[$i]}"
        echo "Downloading $name..."

        if [ "$name" = "release.zip" ]; then
            echo "Downloading $name..."

            # Download the asset with curl
            curl -L -H "Authorization: token $TOKEN" -H "Accept: application/octet-stream" "$url" -o "$name"

            echo "$name successfully downloaded."
        fi  
    done

    # Unzip the downloaded release.zip file
    unzip release.zip
    cd release

    # Check if install.sh exists and run it
    if [ -f "install.sh" ]; then
        echo "install.sh found, executing..."
        chmod +x "install.sh"  # Make the script executable
        ./install.sh           # Run the script
    fi
}

check_update_software() {
    # Directory to store the current software version information
    VERSION_FILE_SOFTWARE="/home/pi/update_box/current_software_version.txt"
    # GitHub API URL to get the latest release information
    REPO_API_SOFTWARE="https://api.github.com/repos/TimeLapseGo/V10_Software/releases/latest"
    # Target directory where the software should be updated
    TARGET_DIR_SOFTWARE="/home/pi/V10_Software"
    # Fetch the latest release information from GitHub API
    RESPONSE=$(curl -H "Authorization: token $TOKEN" -s -w "%{http_code}" -o /tmp/github_response_software.json $REPO_API_SOFTWARE)
    HTTP_CODE=$(tail -n1 <<< "$RESPONSE")

    # Check if the request was successful
    if [ "$HTTP_CODE" -ne 200 ]; then
        echo "Error: Unable to retrieve release information. HTTP Code: $HTTP_CODE or no Release check git "
        return
    fi

    # Extract the latest version (tag) and the ZIP file URL
    LATEST_VERSION_SOFTWARE=$(jq -r '.tag_name' /tmp/github_response_software.json)
    ZIP_URL_SOFTWARE=$(jq -r '.zipball_url' /tmp/github_response_software.json)

    # Check if the information is correct
    if [ -z "$LATEST_VERSION_SOFTWARE" ] || [ -z "$ZIP_URL_SOFTWARE" ]; then
        echo "Error: Missing release information."
        return
    fi

    # Read the current stored version
    CURRENT_SOFTWARE=$(cat $VERSION_FILE_SOFTWARE 2>/dev/null)

    # Check if the latest version is different from the current version
    if [ "$LATEST_VERSION_SOFTWARE" != "$CURRENT_SOFTWARE" ]; then
        echo "New version available: $LATEST_VERSION_SOFTWARE. Update required."

        # Download and extract the new version
        download_and_update $ZIP_URL_SOFTWARE $TARGET_DIR_SOFTWARE $REPO_API_SOFTWARE  
        echo $LATEST_VERSION_SOFTWARE > $VERSION_FILE_SOFTWARE
    else
        echo "No new version available. Current version: $CURRENT_SOFTWARE."
    fi
}



#############################################################################################
#                                    FUNCTION
#############################################################################################
check_update_utilitie() {
    # Directory to store the current utilities version information
    VERSION_FILE_UTILITIE="/home/pi/update_box/current_utilitie_version.txt"
    # GitHub API URL to get the latest release information
    REPO_API_UTILITIE="https://api.github.com/repos/TimeLapseGo/V10_Utilities/releases/latest"
    # Target directory where the utilities should be updated
    TARGET_DIR_UTILITIE="/home/pi/V10_utilitie"
    # Fetch the latest release information from GitHub API
    RESPONSE=$(curl -H "Authorization: token $TOKEN" -s -w "%{http_code}" -o /tmp/github_response_utilitie.json $REPO_API_UTILITIE)
    HTTP_CODE=$(tail -n1 <<< "$RESPONSE")

    # Check if the request was successful
    if [ "$HTTP_CODE" -ne 200 ]; then
        echo "Error: Unable to retrieve release information. HTTP Code: $HTTP_CODE or no Release check git"
        return
    fi

    # Extract the latest version (tag) and the ZIP file URL
    LATEST_VERSION_UTILITIE=$(jq -r '.tag_name' /tmp/github_response_utilitie.json)
    ZIP_URL_UTILITIE=$(jq -r '.zipball_url' /tmp/github_response_utilitie.json)

    # Check if the information is correct
    if [ -z "$LATEST_VERSION_UTILITIE" ] || [ -z "$ZIP_URL_UTILITIE" ]; then
        echo "Error: Missing release information."
        return
    fi

    # Read the current stored version
    CURRENT_UTILITIE=$(cat $VERSION_FILE_UTILITIE 2>/dev/null)

    # Check if the latest version is different from the current version
    if [ "$LATEST_VERSION_UTILITIE" != "$CURRENT_UTILITIE" ]; then
        echo "New version available: $LATEST_VERSION_UTILITIE. Update required."

        # Download and extract the new version
        download_and_update $ZIP_URL_UTILITIE $TARGET_DIR_UTILITIE $REPO_API_UTILITIE

        # Update the current version stored
        echo $LATEST_VERSION_UTILITIE > $VERSION_FILE_UTILITIE

        # Remove the temporary file
        rm /tmp/github_response_utilitie.json
    else
        echo "No new version available. Current version: $CURRENT_UTILITIE."
    fi
}


#############################################################################################
#                                    FUNCTION
#############################################################################################
check_update_firmware() {
    # Directory where the current firmware version information will be stored
    VERSION_FILE_FIRMWARE="/home/pi/update_box/current_firmware_version.txt"
    # GitHub API URL to get the latest release information
    REPO_API_FIRMWARE="https://api.github.com/repos/TimeLapseGo/V10_Firmware/releases/latest"
    # Target directory where the firmware should be updated
    TARGET_DIR_FIRMWARE="/home/pi/firmware"
    # Fetch the latest release information from GitHub API
    RESPONSE=$(curl -H "Authorization: token $TOKEN" -s -w "%{http_code}" -o /tmp/github_response_firmware.json $REPO_API_FIRMWARE)
    HTTP_CODE=$(tail -n1 <<< "$RESPONSE")

    # Check if the request was successful
    if [ "$HTTP_CODE" -ne 200 ]; then
        echo "Error: Unable to retrieve release information. HTTP Code: $HTTP_CODE or no Release check git"
        return
    fi

    # Extract the latest version (tag) and the ZIP file URL
    LATEST_VERSION_FIRMWARE=$(jq -r '.tag_name' /tmp/github_response_firmware.json)
    ZIP_URL_FIRMWARE=$(jq -r '.zipball_url' /tmp/github_response_firmware.json)

    # Check if the information is correct
    if [ -z "$LATEST_VERSION_FIRMWARE" ] || [ -z "$ZIP_URL_FIRMWARE" ]; then
        echo "Error: Release information is missing."
        return
    fi

    # Read the current stored version
    CURRENT_FIRMWARE=$(cat $VERSION_FILE_FIRMWARE 2>/dev/null)

    # Check if the latest version is different from the current version
    if [ "$LATEST_VERSION_FIRMWARE" != "$CURRENT_FIRMWARE" ]; then
        echo "New version available: $LATEST_VERSION_FIRMWARE. Update required."

        # Download and extract the new version
        download_and_update $ZIP_URL_FIRMWARE $TARGET_DIR_FIRMWARE $REPO_API_FIRMWARE

        # Update the current version stored
        echo $LATEST_VERSION_FIRMWARE > $VERSION_FILE_FIRMWARE

        # Remove the temporary file
        rm /tmp/github_response_firmware.json
    else
        echo "No new version available. Current version: $CURRENT_FIRMWARE."
    fi
}


#############################################################################################
#                                      MAIN
#############################################################################################
sleep 20 ## wait after reboot

# Authentication Token
TOKEN="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"

# Maximum number of retries
retries=20

# Attempts to synchronize the time with the NTP server
for ((attempt=1; attempt<=$retries; attempt++)); do
    # Check if internet access is available by trying to connect to an NTP server
    if ping -q -c 1 -W 1 pool.ntp.org >/dev/null; then
        # Fetch time from an NTP server and update the system clock
        sudo ntpdate -u pool.ntp.org 
        echo "The system date is now synchronized with NTP."
        # Exit the loop if synchronization is successful
        break
    else
        echo "Attempt $attempt: Internet connection not available. Cannot synchronize time." 
    fi
    sleep 2
done

# Check if all attempts have failed
if [ $attempt -gt $retries ]; then
    echo "All attempts to synchronize time have failed. Exiting."
    # Add additional actions if necessary
    exit 1
fi


# Update directory
UPDATE_DIR="/home/pi/update_box"
mkdir -p "$UPDATE_DIR"

# Last update file
last_update_file="$UPDATE_DIR/last_update.txt"

# Check if the last update file exists
if [ -f "$last_update_file" ]; then
    # Read the last modification time of the file in seconds since Unix epoch
    last_time=$(stat -c %Y "$last_update_file")   
else
    # If the file doesn't exist, initialize last_time to 0
    last_time=0
fi

# Get the current time in seconds since Unix epoch
current_time=$(date +%s)

# Calculate the time difference in seconds
time_diff=$((current_time - last_time))

# Calculate the absolute value of time_diff
if [ "$time_diff" -lt 0 ]; then
    time_diff=$((time_diff * -1))
fi

# Check if time_diff is less than 24 hours (86400 seconds)
if [ "$time_diff" -lt 86400 ]; then
    echo "The last update was performed less than 24 hours ago."
    exit
fi

# Create the lock file (stop check mode, SMS and check send)
touch /tmp/update.lock

while [ -f "/tmp/send_picture.lock" ]; do
        echo "Sending in progress"        
        sleep 1
done

while pgrep -f "/home/pi/scripts/take_picture.sh" >/dev/null; do
    sleep 1
done

while pgrep -f "/home/pi/scripts/config.sh" >/dev/null; do
    sleep 1
done
# Create a log file with the current date and time
now="$(date +"%Y_%m_%d_%H_%M_%S")"
log="/tmp/${now}_update.txt"

# Define the number of retry attempts and the delay between them
max_retries=5
retry_delay=5 # seconds

# Function to check internet connection
check_internet_connection() {
    ping -c 1 -W 5 8.8.8.8 > /dev/null 2>&1
}

# Attempt to check the internet connection with retries
for ((i = 1; i <= max_retries; i++)); do
    if check_internet_connection; then
        echo "Internet connection detected."

        # Log the actions
        {
            echo "+--------------------------------------------------------------------------+"
            echo "|                         CHECK UPDATE SOFTWARE                            |"
            echo "+--------------------------------------------------------------------------+"
            check_update_software
            echo "+--------------------------------------------------------------------------+"
            echo "|                         CHECK UPDATE UTILITIES                           |"
            echo "+--------------------------------------------------------------------------+"
            check_update_utilitie
            echo "+--------------------------------------------------------------------------+"
            echo "|                         CHECK UPDATE FIRMWARE                            |"
            echo "+--------------------------------------------------------------------------+"
            check_update_firmware
        } >> "$log"

        # Upload the log file to the S3 server
        UDID=$(sed -n '1p' "/home/pi/data/UDID.txt")
        S3_BUCKET="timelapsestorage"
        S3_BUCKET_BLUR="timelapseblur"
        S3_ENDPOINT_UPDATE="s3://$S3_BUCKET/$UDID/UPDATE"

        sudo s3cmd put "$log" "$S3_ENDPOINT_UPDATE/"

        # Update the last update file timestamp
        touch "$last_update_file"
        rm "$log"

        sudo reboot
    else
        echo "Internet connection not detected. Attempt $i of $max_retries."
        if [ $i -lt $max_retries ]; then
            sleep $retry_delay
        else
            echo "Failed to detect internet connection after $max_retries attempts."
            echo "Unable to check for updates."
            exit 1
        fi
    fi
done
