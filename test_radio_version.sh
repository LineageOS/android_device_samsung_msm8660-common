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

echo "test_radio_version.sh arguments: $@"

# Extract the firmware image
echo "Copying the radio to /tmp..."
mkdir $MOUNT_POINT
mount -r $RADIO_PARTITION $MOUNT_POINT
cp $MOUNT_POINT/$FILE_CONTAINING_VERSION $IMAGE_TO_CHECK
umount $MOUNT_POINT
rmdir $MOUNT_POINT

# Determine the radio model
#
# There is a string with "SGH-" followed by the model
#   Examples: SGH-I727 SGH-I727R SGH-T989D
echo "Searching radio image for model..." >&2
RADIO_MODEL=`strings $IMAGE_TO_CHECK | grep -E ^SGH- -m 1 | cut -d - -f 2`
if [ "$RADIO_MODEL" == "" ];then
    echo "ERROR: Could not determine the radio model."
    rm $IMAGE_TO_CHECK
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
RADIO_VERSION=`strings $IMAGE_TO_CHECK | grep -E ^$RADIO_MODEL[A-Z]{4,5}[A-Z1-9]$ -m 1`
if [ "$RADIO_VERSION" == "" ];then
    echo "ERROR: Could not determine the radio version."
    rm $IMAGE_TO_CHECK
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
        rm $IMAGE_TO_CHECK
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
rm $IMAGE_TO_CHECK
exit 0

