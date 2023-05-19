# Raspberry Pi 2B Imager
Install 32bit Rasperry Pi OS Lite to two devices with additional mount points.

Ex:
```
      .~~.   .~~.
     '. \ ' ' / .'
      .~ .~~~..~.
     : .~.'~'.~. :
    ~ (   ) (   ) ~
   ( : '~'.~.'~' : )
    ~ .~ (   ) ~. ~
     (  : '~' :  )i
      '~ .~~~. ~'
          '~'

# # # # WARNING # # # #
This script:
* downloads and writes a 32bit Raspberry Pi OS Lite image to your MicroSD
* creates the root partition on a 64G USB device with these partitions:
  /home, /tmp, /mnt, /var, /var/log, /var/tmp

By continuing you understand this will DESTRUCTIVELY modify the device.
This Software is provided “AS IS” and without warranty of any kind.

Usage: script.sh [boot MicroSD] [root USB]
```
