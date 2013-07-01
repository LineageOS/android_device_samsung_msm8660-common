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
BUSYBOX=/tmp/busybox

# Busybox needs its directory in PATH
export PATH=/tmp:$PATH

# ui_print by Chainfire
OUTFD=$($BUSYBOX ps | $BUSYBOX grep -v "grep" | $BUSYBOX grep -o -E "update_binary(.*)" | $BUSYBOX cut -d " " -f 3);
ui_print() {
  if [ $OUTFD != "" ]; then
    $BUSYBOX echo "ui_print ${1} " 1>&$OUTFD;
    $BUSYBOX echo "ui_print " 1>&$OUTFD;
  else
    $BUSYBOX echo "${1}";
  fi;
}

# Greetings - echo goes to recovery.log, ui_print goes to screen and recovery.log
$BUSYBOX echo "test_radio_version.sh starting with arguments: $@"
ui_print "Verifying that radio is Jellybean or newer..."

# Extract the firmware image
echo "Copying the radio to /tmp..."
$BUSYBOX mkdir $MOUNT_POINT
$BUSYBOX mount -r $RADIO_PARTITION $MOUNT_POINT
$BUSYBOX cp $MOUNT_POINT/$FILE_CONTAINING_VERSION $IMAGE_TO_CHECK
$BUSYBOX umount $MOUNT_POINT
$BUSYBOX rmdir $MOUNT_POINT

# Determine the radio model
#
# There is a string with "SGH-" followed by the model
#   Examples: SGH-I727 SGH-I727R SGH-T989D
$BUSYBOX echo "Searching radio image for model..."
RADIO_MODEL=`$BUSYBOX strings $IMAGE_TO_CHECK | $BUSYBOX grep -E ^SGH- -m 1 | $BUSYBOX cut -d - -f 2`
if [ "$RADIO_MODEL" == "" ];then
    ui_print "ERROR: Could not determine the radio model."
    $BUSYBOX rm $IMAGE_TO_CHECK
    exit 1
fi
ui_print "Found radio model: $RADIO_MODEL"

# Determine the radio version
#
# Grep out the firmware version based on the model.
# The version string is assumed to be in this format:
#   model name, followed by four or five capital letters,
#   followed by either a number (1-9) or a capital letter
#   Examples: I727UCMC1 I727UCLL3 I727UCLK4 I727RUXUMA7
#             T989UVLE1 I757MUGMC5
$BUSYBOX echo "Searching radio image for version..."
RADIO_VERSION=`$BUSYBOX strings $IMAGE_TO_CHECK | $BUSYBOX grep -E ^$RADIO_MODEL[A-Z]{4,5}[A-Z1-9]$ -m 1`
if [ "$RADIO_VERSION" == "" ];then
    ui_print "ERROR: Could not determine the radio version."
    $BUSYBOX rm $IMAGE_TO_CHECK
    exit 1
fi
ui_print "Found radio version: $RADIO_VERSION"

# Iterate through the possible model/minversion pairs
#   - compare to the specified minversion
for PAIR in "$@"; do
    MODEL=`$BUSYBOX echo $PAIR | $BUSYBOX cut -d : -f 1`
    MINVERSION=`$BUSYBOX echo $PAIR | $BUSYBOX cut -d : -f 2`
    if [ "$MODEL" == "$RADIO_MODEL" ]; then
        $BUSYBOX rm $IMAGE_TO_CHECK
        if [ "$RADIO_VERSION" \< "$MODEL$MINVERSION" ]; then
            ui_print "ERROR: Radio must be newer than $MINVERSION"
            exit 1
        fi
        ui_print "Radio is new enough, continuing install..."
        exit 0
    fi
done

# For the radio installed, there is no minimum version defined by the
# recovery script. Warn, but allow the install.
ui_print "WARNING: No minimum version defined for $RADIO_MODEL."
ui_print "MAKE SURE YOUR RADIO IS JELLYBEAN OR NEWER!"
$BUSYBOX rm $IMAGE_TO_CHECK
exit 0

