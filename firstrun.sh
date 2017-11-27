#!/bin/bash

# Developed by Elizabeth Mills - liz@feliz.one
# Revision date: 25th November 2017

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

# Functions in this module are used only once, on first use of FlashUSB
# The main flash.sh script checks to see if Yad is installed
# If not, function Dial is called from this module to install it.
# After Yad is installed, this module is deleted

function Dial
{
  local distro
  local Installer
  local Updater
  local Response

  while true
  do
    print_heading
    echo "  FlasUSB needs the 'Yad' program installed, in order to display"
    echo "  correctly. You should find it in your distro's package manager."
    echo "  However, if you wish, it may be possible to install it now."
    read -p "  Would you like to try? (y/N): " Response
    case $Response in
    "y" | "Y")# First make a reasoned guess of the install command based on distro
      distro=$(grep "^NAME" /etc/*-release | cut -d'"' -f2 | cut -d' ' -f1 | tr '[:upper:]' '[:lower:]')
      case $distro in                     # Try to prepare install command
        "arch" | "archlinux" | "antergos" | "Manjaro") PackageManager="pacman"
          Installer="pacman -S"
          Updater="pacman -Syu"
        ;;
        "centos" | "red hat")  PackageManager="yum"
          Installer="yum install"
          Updater="yum -y update && yum -y upgrade"
        ;;
        "debian" | "ubuntu" | "knoppix" | "*mint" | "sparky*") PackageManager="apt-get"
          Installer="apt-get install"
          Updater="apt-get update && apt-get upgrade"
        ;;
        "fedora")  PackageManager="dnf"
          Installer="dnf install"
          Updater="dnf update"
        ;;
        "mageia") PackageManager="urpmi"
          Installer="urpmi"
          Updater="urpmi --auto-update"
        ;;
        "suse" | "opensuse") PackageManager="zypper"
          Installer="zypper install"
          Updater="zypper update"
        ;;
        *) PackageManager=""; Installer=""; Updater=""
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
      echo "      It appears that your system is $(echo "${distro}" | sed 's/.*/\L&/; s/[a-z]*/\u&/g')"
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
        1) sudo "${Installer}" yad gksu
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
            "y" | "Y") sudo "${Installer}" yad gksu
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
  
} # Dial

function print_heading                   # Always use this function to clear the screen in text mode
{
  local T_COLS
  local LenBT
  local HalfBT
  local cursor_row

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
