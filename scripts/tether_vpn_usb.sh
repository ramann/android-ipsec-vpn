#!/system/bin/sh

# This script reconfigures routing and iptables rules to send Tethered traffic through the VPN
# instead of bypassing the VPN as Android does by default.  This script will be run automatically by
# SManager after enabling/disabling Tethering or enabling/disabling WiFi.  On Android 5.1 it is also
# run automatically after enabling/disabling the VPN.  On Android 5.0 it is not run automatically
# after enabling/disabling the VPN, so you must currently either run it manually or disable and
# re-enable Tethering after enabling/disabling the VPN.

# To install this script:
# * Install the SManager app from Google Play
# * adb shell mkdir /sdcard/Scripts/
# * adb push tether_vpn /sdcard/Scripts/
# * In SManager, select this tether_vpn script and select 'Su' and 'Net' boxes, then hit 'Save'

LOG_FILE='/sdcard/Scripts/tether_vpn.log'

# Erase the log file
> "$LOG_FILE"

# Send all output to the log file
(
  # Print a header for the log file
  date
  [ "$SM_LAUNCHER" != "" ] && echo "Launched by SManager: $SM_LAUNCHER"
  echo

  # If explicitly requested by the user, undo all changes made by this script
  if [ "$1" == "off" -o "$1" == "--off" ] ; then
    echo "Removing all custom routes and iptables rules"
    ip rule del priority 100 2>/dev/null
    iptables -D natctrl_FORWARD -i tun0 -o rndis0 -m state --state RELATED,ESTABLISHED -g natctrl_tether_counters 2>/dev/null
    iptables -D natctrl_FORWARD -i rndis0 -o tun0 -m state --state INVALID -j DROP 2>/dev/null
    iptables -D natctrl_FORWARD -i rndis0 -o tun0 -m ttl --ttl-lt 2 -j DROP 2>/dev/null
    iptables -D natctrl_FORWARD -i rndis0 -o tun0 -g natctrl_tether_counters 2>/dev/null
    iptables -D natctrl_tether_counters -i rndis0 -o tun0 -j RETURN 2>/dev/null
    iptables -D natctrl_tether_counters -i tun0 -o rndis0 -j RETURN 2>/dev/null
    iptables -t nat -D natctrl_nat_POSTROUTING -o tun0 -j MASQUERADE 2>/dev/null
#  fi
else

  if ! iptables -C natctrl_tether_counters -i tun0 -o rndis0 -j RETURN 2>/dev/null ; then
    echo "Adding iptables packet/byte counters"
    echo "(will be left in place until \`$0 --off\` or reboot)"
    iptables -I natctrl_tether_counters -i tun0 -o rndis0 -j RETURN
    iptables -I natctrl_tether_counters -i rndis0 -o tun0 -j RETURN
  fi

  if ! ip rule | grep 'iif rndis0' | grep -v '^100:' >/dev/null ; then
    echo "Tethering disabled"
    if ip rule | grep 'iif rndis0' | grep '^100:' >/dev/null ; then
      echo "Removing custom routes"
      ip rule del priority 100
    else
      echo "Custom routes were not configured, nothing to remove 1"
    fi
    echo "If present, custom iptables rules were automatically removed by the system"
  elif ! ip link show tun0 >/dev/null 2>&1 ; then
    echo "VPN not available"
    if ip rule | grep 'iif rndis0' | grep '^100:' >/dev/null ; then
      # Routes to the VPN become invalid after the VPN disconnects, so even if the VPN reconnects,
      # we will need to remove and re-create the routes
      echo "Removing custom routes"
      ip rule del priority 100
    else
      echo "Custom routes were not configured, nothing to remove 2"
    fi
    echo "If present, custom iptables rules will be left in place until tethering is disabled"
  else
    echo "Tether enabled and VPN available"
    if iptables -t nat -C natctrl_nat_POSTROUTING -o tun0 -j MASQUERADE 2>/dev/null ; then
      echo "Custom iptables rules are already in place 1"
    else
      echo "Adding custom iptables rules"
      iptables -t nat -I natctrl_nat_POSTROUTING -o tun0 -j MASQUERADE
      iptables -I natctrl_FORWARD -i rndis0 -o tun0 -g natctrl_tether_counters
      iptables -I natctrl_FORWARD -i rndis0 -o tun0 -m ttl --ttl-lt 2 -j DROP
      iptables -I natctrl_FORWARD -i rndis0 -o tun0 -m state --state INVALID -j DROP
      iptables -I natctrl_FORWARD -i tun0 -o rndis0 -m state --state RELATED,ESTABLISHED -g natctrl_tether_counters
    fi
    if ip rule | grep 'iif rndis0 lookup tun0' >/dev/null ; then
      echo "Custom routes are already in place 2"
    elif ip rule | grep 'iif rndis0' | grep '^100:' >/dev/null ; then
      echo "Updating custom routes"
      ip rule del priority 100
      ip rule add priority 100 iif rndis0 table tun0
      ip route add 192.168.42.0/24 dev rndis0 scope link table tun0
      ip route add broadcast 255.255.255.255 dev rndis0 scope link table tun0
    else
      echo "Adding custom routes"
      ip rule add priority 100 iif rndis0 table tun0
      ip route add 192.168.42.0/24 dev rndis0 scope link table tun0
      ip route add broadcast 255.255.255.255 dev rndis0 scope link table tun0
    fi
  fi
fi
  # Print a footer for the log file
  echo
  echo "Complete"
  date
) > "$LOG_FILE" 2>&1
