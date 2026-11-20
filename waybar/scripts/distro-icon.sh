#!/usr/bin/env bash
# Outputs a Nerd Font distro icon for the current system (Waybar launcher)
set -euo pipefail

icon="" # generic Linux fallback

if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  id="${ID:-}"
  like="${ID_LIKE:-}"
else
  id=""
  like=""
fi

case "$id" in
  arch)                     icon="󰣇" ;;
  artix)                    icon="" ;;
  endeavouros)              icon="" ;;
  manjaro)                  icon="" ;;
  cachyos|garuda)           icon="󰣇" ;;
  ubuntu)                   icon="" ;;
  debian)                   icon="" ;;
  linuxmint|mint)           icon="󰣭" ;;
  pop)                      icon="" ;;
  elementary)               icon="" ;;
  zorin)                    icon="" ;;
  fedora)                   icon="" ;;
  rhel|centos|rocky|almalinux|ol) icon="" ;;
  opensuse*|suse|sles|opensuse-tumbleweed|opensuse-leap) icon="" ;;
  nixos)                    icon="" ;;
  gentoo)                   icon="" ;;
  void)                     icon="" ;;
  alpine)                   icon="" ;;
  kali)                     icon="" ;;
  parrot)                   icon="" ;;
  raspbian)                 icon="" ;;
  slackware)                icon="" ;;
  deepin)                   icon="" ;;
  devuan)                   icon="" ;;
  *)
    case " $like " in
      *" arch "*)                icon="󰣇" ;;
      *" debian "*|*" ubuntu "*) icon="" ;;
      *" fedora "*|*" rhel "*)   icon="" ;;
      *" suse "*)                icon="" ;;
      *)                         icon="" ;;
    esac
    ;;
esac

printf '%s\n' "$icon"
