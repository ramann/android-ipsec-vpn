# Android VPN Tether

### These are instructions to set up a not (terribly) invasive Android phone. They were inspired by and build upon instructions that Jacob Appelbaum created for removing various sensors from the Motorola Moto E (about $60 in December 2015). When Clear Wireless turned of their network in November, a colleague provided me with a script to tether while connected to a VPN. I have modifed it for use with USB tethering and added a couple routing entries to fix a DHCP re-lease issue. Additionally I created a wrapper around dnsmasq which can be used to change the DHCP range and lease time via a config file. I also have a couple of iptables commands that run at boot which disallow outbound traffic that is not related to the VPN or tethering. You don't need to log in with a Google account for any of this to work - all necessary apks have been included and you can take a look at FDroid if you want to check out some other apps.

### Note: I used Ubuntu 14.04 when rooting - search around for other steps if you're using a different (non-Linux) OS. You'll need to make some modifications to get this working with WiFi instead of USB tethering (probably just change the iptables entries from rndis0 to wlan0 and the DHCP server's IP from 42.x to 43.x).

1. Purchase a Motorola Moto E (1st gen). Going for about $60 on Amazon in December 2015.

2. Make sure it works. Put in a sim card and make sure it is functional (tethering works, etc).
	Check your carrier for appropriate sim settings. I found that I had to change the auto-configured APN type to 'default,dun' to get tethering to work.
	Here are my settings (StraightTalk wireless on T-Mobile's network):
		apn - wap.tracfone
		port - 8080
		mmsc - http://mms.tracfone.com
		mms port - 8080
		mcc - 310
		mnc - 260
		apn type - default,dun
		apn protocol - IPv4
		apn roaming protocol - IPv4

3. Update to android 4.4.4 by going to Settings -> About phone -> System updates

4. Enable Developer options

	Settings -> About phone -> keep tapping Build number
	Settings -> Developer options -> USB debugging (switch on)

5. Get adb working.

	```echo 'SUBSYSTEMS=="usb", ATTRS{idVendor}=="22b8", MODE="0666"' >> /etc/udev/rules.d/80-android.rules```
	

6. Install Motorola Update Services apk.

	```adb install com.motorola.ccc.ota-7.0.1-70001-androidgb.apk```

7. Update to android 5.1.

8. Update to patch for stagefright vulnerability.

9. Unzip mfastboot-v2.zip and use linux-fastboot instead of fastboot in any unlocking or flashing instructions.

10. Unlock bootloader using Motorola's instructions. You'll need an (accessible) email address. https://motorola-global-portal.custhelp.com/app/answers/detail/a_id/87215

11. Root it (http://www.droidviews.com/root-moto-e-install-twrp-recovery/).
	```adb push UPDATE-SuperSU-v2.46.zip /sdcard/```
	```adb reboot bootloader```
	```./linux-fastboot flash recovery twrp-2.7.1.0-condor.img```
	```./linux-fastboot reboot```
	```adb reboot recovery```
	```Select Install -> UPDATE-SuperSU-v2.46.zip```
	```Confirm installation and then Reboot -> System```

12. Follow Jacob Appelbaum's instructions to remove sensors ().
	CAUTION! Before you start cutting metal to get to the accelerometer, put the piece of plastic that held the battery back on. This should help prevent you from slicing the ribbon cable if your knife slips.

13. Get the strongSwan VPN client working.
	Setup a strongSwan server (beyond the scope of this project) and create a certificate (also beyond the scope of this project) for it, as well as for the phone. (Note the limitations: https://wiki.strongswan.org/projects/strongswan/wiki/AndroidVPNClient)
		I used my server's IP for the gateway (and thus, the subjectAltName of the gateway's certificate). I bundled the phone's key, cert, and CA cert using openssl pkcs12 to get a pfx file. The CA cert was in PEM format.
	adb install strongSwan-1.5.0.apk
	Select 'Add VPN Profile'
	Select 'Type: IKEv2 Certificate'
	Uncheck 'CA certificate: Select automatically'
	Select the appropriate certificates
	Test out the VPN connection (open chrome and google "IP address", etc)

14. Get Tethering working with the VPN
	adb install os.tools.scriptmanager.3.0.4.apk
	adb shell mkdir /sdcard/Scripts/
	adb push tether_vpn_usb.sh /sdcard/Scripts/.
	In SManager, select tether_vpn_usb.sh, then the "Su" and "Net" and hit Save.
	Try tethering with and without the VPN running. Make sure you grant SManager root access in SuperSU

15. Create dnsmasq wrapper
	adb push dnsmasq /sdcard/.
	adb push dnsmasq.conf /sdcard/.
	adb shell
		su
		mount -o rw,remount,rw /system
		mv /system/bin/dnsmasq /system/bin/dnsmasq.real
		cp /sdcard/dnsmasq /system/bin/.
		chmod 755 /system/bin/dnsmasq
		chown root:shell /system/bin/dnsmasq
		cp /sdcard/dnsmasq.conf /etc/.
		chmod 644 /etc/dnsmasq.conf
		chown root:root /etc/dnsmasq.conf
		mount -o ro,remount,ro /system
		exit
		exit
	
16. Add boot script for outbound non tethering/VPN traffic
	adb push drop_non_vpn_or_tether.sh /sdcard/Scripts/.
	In SManager, select drop_non_vpn_or_tether.sh, then "Su" and "Boot", enter your VPN server's IP on the arguments line and hit Save.
	After reboot you can open up an adb shell and enter the following command to view dropped non-VPN related traffic.
		grep --line-buffered 'NOT-VPN-RELATED' /proc/kmsg
	Note that your phone will have an exclamation mark next to the signal strength. This doesn't mean you can't connect to your VPN. It just means your phone is having trouble phoning home to the Google mothership (which is what we want!).


17. You should now have a phone which isn't brimming with extraneous sensors and which drops all outbound traffic that is not associated with tethering or the VPN connection. Enjoy!

Links worth clicking:
