#!/bin/bash

# Define configuration files and the binary file to flash
CONFIG_RPI="/home/pi/stm32/raspberrypi.cfg"
CONFIG_TARGET="target/stm32g0x.cfg"
BIN_FILE="/home/pi/stm32/TLGO_STM32_v8.bin"
FLASH_ADDRESS="0x08000000"

# Maximum number of attempts
MAX_ATTEMPTS=3
ATTEMPT=1

# Function to flash the firmware using OpenOCD
flash_firmware() {
    sudo openocd -f "$CONFIG_RPI" \
                 -c "transport select swd" \
                 -f "$CONFIG_TARGET" \
                 -c init \
                 -c "reset halt" \
                 -c "flash write_image erase $BIN_FILE $FLASH_ADDRESS" \
                 -c "reset" \
                 -c "exit"
    return $?
}

# Loop to retry flashing if it fails
while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    echo "Attempt $ATTEMPT to flash the firmware..."

    flash_firmware

    if [ $? -eq 0 ]; then
        echo "Firmware flash succeeded on attempt $ATTEMPT."
        exit 0
    else
        echo "Firmware flash failed on attempt $ATTEMPT."
    fi
    sleep 1
    ATTEMPT=$((ATTEMPT+1))
done

# If all attempts fail
echo "Firmware flash failed after $MAX_ATTEMPTS attempts."
exit 1
