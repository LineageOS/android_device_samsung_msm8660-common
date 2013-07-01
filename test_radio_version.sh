#!/sbin/sh

# Script to verify that the radio is at least newer than a specified minimum.
#
# Usage
#   arguments are in the form MODEL:MINVERSION (e.g. "I727:UCMC1 I727R:UXUMA7")
#   result 0: radio is equal to or newer than the minimum radio version
#   result 1: radio is older than the minimum radio version

# Variables
RADIO_PARTITION=/dev/block/mmcblk0p17
MOUNT_POINT=/tmp/radio_partition
FILE_CONTAINING_VERSION=image/DSP2.MBN
IMAGE_TO_CHECK=/tmp/radio_image_to_check

# Extract the firmware image
echo "Copying the radio to /tmp..."
mkdir $MOUNT_POINT
mount -r $RADIO_PARTITION $MOUNT_POINT
cp $MOUNT_POINT/$FILE_CONTAINING_VERSION $IMAGE_TO_CHECK
umount $MOUNT_POINT
rmdir $MOUNT_POINT

# Determine the radio model
#
# There is a string with model followed by ".001"
#   Examples: I727.001 I727R.001 T989D.001
echo "Searching radio image for model..."
RADIO_MODEL=`grep -E \\.001$ -m 1 $IMAGE_TO_CHECK | cut -d . -f 1`
if [ "$RADIO_MODEL" == "" ];then
    echo "ERROR: Could not determine the radio model."
    exit 1
fi
echo "Found radio model: $RADIO_MODEL"

# Determine the radio version
#
# The string string is assumed to be in this format:
#   model name, followed by four or five capital letters,
#   followed by either a number (1-9) or a capital letter
#   Examples: I727UCMC1 I727UCLL3 I727UCLK4 I727RUXUMA7
#             T989UVLE1 I757MUGMC5
echo "Searching radio image for version..."
RADIO_VERSION=`grep -E ^$RADIO_MODEL[A-Z]{4,5}[A-Z1-9]$ -m 1 $IMAGE_TO_CHECK`
if [ "$RADIO_VERSION" == "" ];then
    echo "ERROR: Could not determine the radio version."
    exit 1
fi
echo "Found radio version: $RADIO_VERSION"

# Iterate through the possible model/minversion pairs
#   - grep out the firmware version based on the model
#   - compare to the specified minversion
for PAIR in "$@"; do
    MODEL=`echo $PAIR | cut -d : -f 1`
    MINVERSION=`echo $PAIR | cut -d : -f 2`
    if [ "$MODEL" == "$RADIO_MODEL" ]; then
        if [ "$RADIO_VERSION" \< "$MODEL$MINVERSION" ]; then
            echo "Radio must be newer than $MINVERSION"
            exit 1
        fi
        echo "Radio is new enough."
        exit 0
    fi
done

# For the radio installed, there is no minimum version defined by the
# recovery script. Warn, but allow the install.
echo "WARNING: There is no minimum version defined for $RADIO_MODEL."
exit 0

