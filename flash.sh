#!/bin/bash

# Developed by Elizabeth Mills - liz@feliz.one
# Revision date: 9th November 2017

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or (at
# your option) any later version.

# This program is distributed in the hope that it will be useful, but
#      WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#            General Public License for more details.

# A copy of the GNU General Public License is available from the Feliz2
#        page at http://sourceforge.net/projects/feliz2/files
#        or https://github.com/angeltoast/feliz2, or write to:
#                 The Free Software Foundation, Inc.
#                  51 Franklin Street, Fifth Floor
#                    Boston, MA 02110-1301 USA

function main
{
  while true
  do
    PrepareDeviceList # ${LongList} is set
    Result=$(yad --form \
      --window-icon=flash.png \
      --width=600 \
      --height=75 \
      --center \
      --title "Flash Your Flash" \
      --text-align=center \
      --buttons-layout=center \
      --text="\nPlease select the usb storage device to use, and choose an action\n" \
      --field="Device:CB" "$LongList" \
      --field="Action:CB" "Burn iso image!Format device" \
      --button=Continue:0 \
      --button=Quit:1)
      exitstatus=$? # Exit status is numeric, 0 to 255
    if [ $exitstatus -ne 0 ]; then exit; fi

    SelectedDevice=$(echo $Result | cut  -d':' -f1)                   # eg: sdc
    Remainder=$(echo $Result | sed -n -e "s/^${SelectedDevice}://p")  # eg: SanDisk Corp. Cruzer Blade|Burn iso image|
    DeviceName=$(echo $Remainder | cut  -d'|' -f1)                    # eg: SanDisk Corp. Cruzer Blade
    Action=$(echo $Remainder | cut  -d'|' -f2)                        # eg: Burn iso image
    Device="${SelectedDevice}:${DeviceName}"                          # eg: sdc:SanDisk Corp. Cruzer Blade

    case $Action in
    "Burn iso image") BurnISO
    ;;
    "Format device") FormatDevice
    esac
  done
} # main

function PrepareDeviceList
{
  # Build an array of usb storage devices
  declare -A Devices
  Counter=0
  
  for device in /sys/block/*  # eg: /sys/block/sdb
  do
    if udevadm info --query=property --path=$device | grep -q ^ID_USB_DRIVER=usb-storage
    then
      # 1 - Isolate the device vendor code and device model (in hex)
      Vendor=$(udevadm info --query=property --path=$device | grep ID_VENDOR_ID=)
      Vendor=${Vendor: -4:4}  # eg: 0781
      Unit=$(udevadm info --query=property --path=$device | grep ID_MODEL_ID=)
      Unit=${Unit: -4:4}  # eg: 5567
      # 2 - After finding the /sys/block/* details, shorten $device
      device=${device: -3:3}  # eg: sdc
      # 3 - Using $Vendor and $Unit (eg: 0781:5567) use lsusb to find the name of the device
      DeviceName=$(lsusb | grep "$Vendor:$Unit")  # eg: Bus 002 Device 005: ID 0781:5567 SanDisk Corp. Cruzer Blade
      DeviceName=$(echo $DeviceName | sed -n -e "s/^.*${Vendor}:${Unit} //p")
      # 
      Devices[${Counter}]="$device:$DeviceName"  # eg: sdc:SanDisk Corp. Cruzer Blade
      ((Counter++))
    fi
  done
  
  # Now convert the array into a long string of options separated by a "!"
  LongList=""
  Counter=1
  for i in "${Devices[@]}"
  do
    if [ $Counter -gt 1 ]; then
      i="!${i}"
    fi
    LongList="${LongList}${i}"
    ((Counter++))
  done

} # PrepareList

function BurnISO
{
  ISOpath=$(yad --form \
      --window-icon=flash.png \
      --width=600 \
      --height=75 \
      --center \
      --title "$Action" \
      --text-align=center \
      --buttons-layout=center \
      --text="\nDevice = $Device\nPlease select an iso to burn" \
      --field="File to burn:FL" \
      --button=Continue:0 \
      --button=Back:2 \
      "/home/$USER")
  exitstatus=$? # Exit status is numeric, 0 to 255
  if [ $exitstatus -eq 2 ]; then return; fi
  
  # Validate ISOpath
  if [ $(file -k "$ISOpath" | grep 'CD-ROM filesystem data') = "" ]; then
    Title="$Action"
    Message="\n $ISOpath does not appear to be a valid image file.\n If you continue with this file, you may not get an installable system.\n Do you wish to continue with this file?"
    YesNo
    if [ $exitstatus -ne 0 ]; then return; fi
  fi
  
  ISOpath=$(echo $ISOpath | tr '|' ' ')
  ISOpath=${ISOpath%% }
  # Check and confirm
  Title="$Action"
  Message="\n$Action $ISOpath \n to /dev/${SelectedDevice}? \n WARNING: This will destroy any data on /dev/${SelectedDevice}"
  YesNo
  case $exitstatus in
  0) Message="Burning ... "
    gksu ls &>/dev/null
    gksu dd bs=4M if="$ISOpath" of="/dev/${SelectedDevice}" && sync &>flash.log &
    Progress 4
  ;;
  *) return
  esac
  
  Message="$ISOpath completed"
  Title="$Action"
  MsgBox
  
} # BurnISO

function FormatDevice
{
    
  Device="${SelectedDevice}:${DeviceName}"
  FormatResult=$(yad --form --separator='\t' \
      --window-icon=flash.png \
      --width=600 \
      --height=75 \
      --center \
      --title "$Action" \
      --text-align=center \
      --buttons-layout=center \
      --text="\nDevice = $Device\n" \
      --field="Choose filesystem:CB" "vfat!ext4" \
      --button=Continue:0 \
      --button=Back:2)
      exitstatus=$? # Exit status is numeric, 0 to 255

  if [ $exitstatus -eq 2 ]; then return; fi
  
  # Check and confirm
  Title="$Action"
  Message="\n $Action /dev/${SelectedDevice} to ${FormatResult}?\n WARNING: This will destroy any data on /dev/${SelectedDevice}"
  YesNo
  case $exitstatus in
  0) Message="$Action /dev/${SelectedDevice} to ${FormatResult}"
    umount /dev/${SelectedDevice}1 &>/dev/null
    gksu "mke2fs -F -t ${FormatResult} /dev/${SelectedDevice}" &>/dev/null &
    Progress 1
  ;;
  *) return
  esac
  
  Message="$ISOpath completed"
  Title="$Action"
  MsgBox
  
} # FormatDevice

function Progress # Displays a progress guage
{
    case $1 in
  1) Timer=0.2
  ;;
  2) Timer=0.4
  ;;
  3) Timer=0.6
  ;;
  4) Timer=0.8
  ;;
  *) Timer=0.1
  esac
  
  (
    for (( i=0; i<101; i++ ));
    do
       echo "# \n $Message ${i}% \n" ; sleep ${Timer} ;
    done
  ) | yad --progress --pulsate \
        --window-icon=flash.png \
        --width=600 \
        --height=75 \
        --center \
        --title "Flash Your Flash" \
        --text-align=center \
        --no-buttons --auto-close --percentage=0
}

function MsgBox
{
  yad --form \
      --window-icon=flash.png \
      --width=600 \
      --height=20 \
      --center \
      --title "Alert" \
      --text-align=center \
      --buttons-layout=center \
      --button=Ok:0 \
      --text "\n$Message\n"
} # MsgBox

function YesNo # Displays $Message and Yes/No buttons. Sets $exitstatus
{
  yad --image "dialog-question" \
      --window-icon=flash.png \
      --center \
      --title "$Title" \
      --text-align=center \
      --width=600 \
      --height=30 \
      --buttons-layout=center \
      --button=Yes:0 \
      --button=No:1 \
      --text "$Message"

    exitstatus=$?                            # Exit status is numeric, 0 to 255
} # YesNo


function Dial
{
  if [ -z "$(whereis yad | cut -d':' -f2)" ]; then
    while true
    do
      print_heading
      echo "  FlasUSB needs the 'Yad' program installed, in order to display"
      echo "  correctly. You should find it in your distro's package manager."
      echo "  However, if you wish, it may be possible to install it now."
      read -p "  Would you like to try? (y/N): " Response
      case $Response in
      "y" | "Y") # First make a reasoned guess of the install command based on distro
        distro="${Distro,,}"                # Convert to all lower case for matching
        case $distro in                     # Try to prepare install command
        "arch*" | "antergos" | "Manjaro") Installer="pacman -S"
          Updater="pacman -Syu"
        ;;
        "centos" | "red hat") Installer="yum install"
          Updater="yum -y update && yum -y upgrade"
        ;;
        "debian" | "ubuntu" | "knoppix" | "*mint" | "sparky*") Installer="apt-get install"
          Updater="apt-get update && apt-get upgrade"
        ;;
        "fedora") Installer="dnf install"
          Updater="dnf update"
        ;;
        "mageia") Installer="urpmi"
          Updater="urpmi --auto-update"
        ;;
        "suse" | "opensuse") Installer="zypper install"
          Updater="zypper update"
        ;;
        *) Installer=""
          Updater=""
        esac
        print_heading
        if [ "$Installer" = "" ]; then
          echo "   FlashUSB has been unable to determine the install command for your system."
          echo "        This may be something like 'apt-get install' or 'yum install'"
          echo "           or 'rpm -i' or 'pacman -S' - depending on your system."
          echo "  If in doubt, you should not proceed (press [Enter] without typing anything)"
          echo
          read -p "  Please enter the installation command to use: " Installer
          if [ "$Installer" = "" ]; then
            echo
            echo "Sorry to see you go"
            exit
          fi
        fi
        echo "      It appears that your system is $Distro"
        echo "     In which case, your installation command"
        echo "              is probably: $Installer"
        echo
        echo "    Would you like to proceed with installation"
        echo "              using: $Installer?"
        echo
        echo "  Please choose:"
        echo "   1 to install using using: ${Installer};"
        echo "   2 for an opportunity to enter a different install command;"
        echo "   3 to quit FlashUSB"
        echo
        read -p "   Enter a number: " Response
        case $Response in
          1) gksu "${Installer}" dialog
            break
          ;;
          2) print_heading
            read -p "  Please enter the installation command to use: " Installer
            if [ "$Installer" = "" ]; then
              echo; echo "Sorry to see you go"; echo
              exit
            fi
            echo; echo "  Would you like to proceed with installation"; echo
            read -p "  using: $Installer? (y/N): " Response
            case $Response in
              "y" | "Y") gksu "${Installer}" yad
                break
              ;;
              *) echo; echo "Sorry to see you go"; echo
                exit
            esac
          ;;
          3) echo; echo "Sorry to see you go"; echo
              exit
          ;;
          *) echo "  Invalid entry. Please try again."
            read -p "  Press [Enter] to continue"
        esac
      ;;
      "n" | "N" | "") echo; echo "  Sorry to see you go"; echo
          exit
      ;;
      *) echo; echo "  Invalid entry. Please try again."
        read -p "  Press [Enter] to continue"
      esac
    done
  fi
} # Dial

function print_heading                   # Always use this function to clear the screen in text mode
{
  clear
  T_COLS=$(tput cols)                    # Get width of terminal
  LenBT=${#Backtitle}                    # Length of backtitle
  HalfBT=$((LenBT/2))
  tput cup 0 $(((T_COLS/2)-HalfBT))      # Move the cursor to left of center
  tput bold
  printf "%-s\n" "$Backtitle"            # Display backtitle
  tput sgr0
  cursor_row=3                           # Save cursor row after heading
} # print_heading

main
