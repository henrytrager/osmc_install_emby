#!/bin/bash
#===============================================================#
# Emby Installation Script - by dougiefresh                     #
#===============================================================#
# DISCLAIMER: This is a script by dougiefresh to install Emby   #
# Server to OSMC.  I am not responsible for any harm done to    #
# your system.  Using this script is done at your own risk.     #
#===============================================================#
VERSION=0.1
HOME_DIR=/home/osmc
EMBY_HOME=/opt/mediabrowser
MONO_DIR=/usr/bin
INSTALLED=$(cat $EMBY_HOME/mediabrowser.current)

# =================================================
# Functions required by this script:
# =================================================
function install_prerequisites()
{

	echo "================================================="
	echo "Installing prerequisites..."
	echo "================================================="
	sudo apt-get --show-progress -y --force-yes install aptitude unzip git build-essential pv dialog cron-app-osmc 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --title "Installing prerequisite programs if they are not present" --gauge "\nPlease wait...\n" 11 70
}

function install_dependencies()
{
	echo " "
	echo "================================================="
	echo "Installing Dependencies...."
	echo "================================================="
	sudo aptitude install imagemagick imagemagick-6.q16 imagemagick-common libimage-magick-perl libimage-magick-q16-perl libmagickcore-6-arch-config libmagickcore-6-headers libmagickcore-6.q16-2 libmagickcore-6.q16-2-extra libmagickcore-6.q16-dev libmagickwand-6-headers libmagickwand-6.q16-2 libmagickwand-6.q16-dev libmagickwand-dev webp mediainfo sqlite3
}

function build_ffmpeg()
{
	echo " "
	echo "================================================="
	echo "Building and installing FFmpeg...."
	echo "================================================="
	sudo aptitude remove ffmpeg
	cd /usr/src
	sudo mkdir ffmpeg
	sudo chown `whoami`:users ffmpeg
	git clone git://source.ffmpeg.org/ffmpeg.git ffmpeg
	cd ffmpeg
	./configure
	make -j`nproc` && sudo make install
	cd $HOME_DIR
	sudo rm -R /usr/src/ffmpeg
}

function install_mono()
{
	echo " "
	echo "================================================="
	echo "Getting Mono libraries..."
	echo "================================================="
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	echo "deb http://download.mono-project.com/repo/debian wheezy main" | sudo tee /etc/apt/sources.list.d/mono-xamarin.list
	test $(cat /etc/debian_version) > 7.999999 && (
        	echo "deb http://download.mono-project.com/repo/debian wheezy-apache24-compat main" | sudo tee -a /etc/apt/sources.list.d/mono-xamarin.list;
		echo "deb http://download.mono-project.com/repo/debian wheezy-libjpeg62-compat main" | sudo tee -a /etc/apt/sources.list.d/mono-xamarin.list;
	)
	sudo apt-get update 2>&1 | dialog --title "Updating package database..." --infobox "\nPlease wait...\n" 11 70
	sudo apt-get --show-progress -y install mono-complete 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --title "Installing Mono libraries if they are not present" --gauge "\nPlease wait...\n" 11 70
}

function install_emby()
{
	echo " "
	echo "================================================="
	echo "Getting latest version of Emby from GitHub..."
	echo "================================================="
	url=$(curl -s https://github.com/MediaBrowser/Emby/releases/latest | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "/releases/")
	LATEST_VER=$(basename $url | tee /tmp/mediabrowser.current)
	file=$(curl -s $url | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "Emby.Mono.zip")
	wget --no-check-certificate -w 4 http://github.com$file -O /tmp/Emby.Mono.zip 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --title "Downloading Emby Server v$latest" --gauge "\nPlease wait...\n"  11 70
	sudo unzip -o /tmp/Emby.Mono.zip -d $EMBY_HOME
	rm /tmp/Emby.Mono.zip
	sudo mv /tmp/mediabrowser.current $EMBY_HOME/mediabrowser.current

	# =================================================
	# Fixing Emby configuration files happens here:
	# Needs more work for it to work properly in all cases:
	# =================================================
	echo "<configuration>" > /tmp/ImageMagickSharp.dll.config
	echo "  <dllmap dll=\"CORE_RL_Wand_.dll\" target=\"libMagickWand-6.Q16.so.2\" os=\"linux\"/>" >> /tmp/ImageMagickSharp.dll.config
	echo "  <dllmap dll=\"CORE_RL_Wand_.dll\" target=\"libMagickWand-6.so\" os=\"freebsd,openbsd,netbsd\"/>" >> /tmp/ImageMagickSharp.dll.config
	echo "  <dllmap dll=\"CORE_RL_Wand_.dll\" target=\"./MediaInfo/osx/libmediainfo.dylib\" os=\"osx\"/>" >> /tmp/ImageMagickSharp.dll.config
	echo "</configuration>" >> /tmp/ImageMagickSharp.dll.config
	sudo mv /tmp/ImageMagickSharp.dll.config $EMBY_HOME/ImageMagickSharp.dll.config 

	echo "<configuration>" > /tmp/System.Data.SQLite.dll.config
	echo "  <dllmap dll=\"sqlite3\" target=\"libsqlite3.so.0\" os=\"linux\"/>" >> /tmp/System.Data.SQLite.dll.config
	echo "</configuration>" >> /tmp/System.Data.SQLite.dll.config
	sudo mv /tmp/System.Data.SQLite.dll.config $EMBY_HOME/System.Data.SQLite.dll.config

	echo "<configuration>" > /tmp/MediaBrowser.MediaInfo.dll.config
	echo "  <dllmap dll=\"MediaInfo\" target=\"./MediaInfo/osx/libmediainfo.dylib\" os=\"osx\"/>" >> /tmp/MediaBrowser.MediaInfo.dll.config
	echo "  <dllmap dll=\"MediaInfo\" target=\"libmediainfo.so.0\" os=\"linux\"/>" >> /tmp/MediaBrowser.MediaInfo.dll.config
	echo "</configuration>" >> /tmp/MediaBrowser.MediaInfo.dll.config
	sudo mv /tmp/MediaBrowser.MediaInfo.dll.config $EMBY_HOME/MediaBrowser.MediaInfo.dll.config 
}

function create_service()
{
	echo " "
	echo "================================================="
	echo "Adding Emby Service..."
	echo "================================================="
	echo "#! /bin/bash" > /tmp/emby
	echo "### BEGIN INIT INFO" >> /tmp/emby
	echo "# Provides:          emby" >> /tmp/emby
	echo "# Required-Start:    \$local_fs \$network" >> /tmp/emby
	echo "# Required-Stop:     \$local_fs" >> /tmp/emby
	echo "# Default-Start:     2 3 4 5" >> /tmp/emby
	echo "# Default-Stop:      0 1 6" >> /tmp/emby
	echo "# Short-Description: emby" >> /tmp/emby
	echo "# Description:       Emby server" >> /tmp/emby
	echo "### END INIT INFO" >> /tmp/emby
	echo "" >> /tmp/emby
	echo "PIDFILE=\"/tmp/mediabrowser-server.pid\"" >> /tmp/emby
	echo "EXEC=\"$EMBY_HOME/MediaBrowser.Server.Mono.exe -ffmpeg /usr/local/share/man/man1/ffmpeg.1 -ffprobe /usr/local/share/man/man1/ffprobe.1\"" >> /tmp/emby
	echo "" >> /tmp/emby
	echo "function install_start_emby()" >> /tmp/emby
	echo "{" >> /tmp/emby
	echo "	start-stop-daemon -S -m -p \$PIDFILE -b -x $MONO_DIR/mono -- \${EXEC}" >> /tmp/emby
	echo "}" >> /tmp/emby
	echo "" >> /tmp/emby
	echo "function install_stop_emby()" >> /tmp/emby
	echo "{" >> /tmp/emby
	echo "	start-stop-daemon -K -p \${PIDFILE}" >> /tmp/emby
	echo "}" >> /tmp/emby
	echo "" >> /tmp/emby
	echo "function install_restart_emby()" >> /tmp/emby
	echo "{" >> /tmp/emby
	echo "	install_stop_emby" >> /tmp/emby
	echo "	install_start_emby" >> /tmp/emby
	echo "}" >> /tmp/emby
	echo "" >> /tmp/emby
	echo "case \"\$1\" in" >> /tmp/emby
	echo "	start)" >> /tmp/emby
	echo "		install_start_emby" >> /tmp/emby
	echo "    ;;" >> /tmp/emby
	echo "  stop)" >> /tmp/emby
	echo "		install_stop_emby" >> /tmp/emby
	echo "    ;;" >> /tmp/emby
	echo "  restart|force_reload)" >> /tmp/emby
	echo "		install_stop_emby" >> /tmp/emby
	echo "		sleep 3" >> /tmp/emby
	echo "		install_start_emby" >> /tmp/emby
	echo "    ;;" >> /tmp/emby
	echo "  *)" >> /tmp/emby
	echo "    echo \"Usage: /etc/init.d/emby {start|stop|restart|force_reload}\"" >> /tmp/emby
	echo "    exit 1" >> /tmp/emby
	echo "    ;;" >> /tmp/emby
	echo "esac" >> /tmp/emby
	sudo echo "exit 0" >> /tmp/emby
	sudo mv /tmp/emby /etc/init.d/emby
	sudo chmod 755 /etc/init.d/emby
	sudo update-rc.d emby defaults
	sudo /etc/init.d/emby start
}

function get_addon()
{
        file=$(curl -s $1 | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "$2")
        wget --no-check-certificate -w 4 $1/$file -O /tmp/$file 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --title "Downloading Addon" --gauge "\nPlease wait...\n"  $
	# Unzip the addon, and move the zip to the package store of OSMC
        cd /tmp/
        unzip /tmp/$file -d $HOME_DIR/.kodi/addons
        mv /tmp/$file $HOME_DIR/.kodi/addons/packages/$file
}

function install_addons()
{
	echo " "
	echo "================================================="
	echo "Installing Emby for Kodi repository..."
	echo "================================================="
	# get the repository for Emby for Kodi:
	get_addon http://kodi.emby.media repository.emby.kodi

	# figure out where to pull the Kodi addons:
	dir='<datadir>http'$(cat $HOME_DIR/.kodi/addons/repository.emby.kodi/addon.xml | grep "</datadir>" | sed -n 's/.*http//p')
	dir=$(echo $dir | grep -oPm1 "(?<=<datadir>)[^<]+")
	
	# pull the rest of the addons from the Emby repository:
	get_addon $dir/plugin.video.emby/ plugin.video.emby
	get_addon $dir/plugin.video.emby.movies/ plugin.video.emby.movies
	get_addon $dir/plugin.video.emby.musicvideos/ plugin.video.emby.musicvideos
	get_addon $dir/plugin.video.emby.tvshows/ plugin.video.emby.tvshows
}

function cleanup()
{
	echo " "
	echo "================================================="
	echo "Cleaning up!"
	echo "================================================="
	sudo apt-get clean

	ip="hostname -I"
	dialog --title "FINISHED!" --msgbox "\nYour Emby Server should now be available for you at http://$ip:8096\nPress OK to return to the menu.\n" 11 70

	# restart script
	exec $HOME_DIR/install-emby.sh
}

function update_script()
{
	# retrieve the latest version of the script from GitHub:
	wget --no-check-certificate -w 4 -O $HOME_DIR/install-emby.sh.1 https://raw.githubusercontent.com/douglasorend/osmc_install-emby/master/install-emby.sh 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --title "Downloading latest version of Emby Server script" --gauge "\nPlease wait...\n"  11 70
	chmod +x $HOME_DIR/install-emby.sh.1
	mv $HOME_DIR/install-emby.sh.1 $HOME_DIR/install-emby.sh

	# restart script
	exec $HOME_DIR/install-emby.sh
}

function upgrade_emby()
{
	if [[ "$INSTALLED" != "" ]]; then
		LATEST_VER=$(curl -s https://github.com/MediaBrowser/Emby/releases/latest | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "/releases/")
		LATEST_VER=$(basename $latest)
		if [[ $latest > $INSTALLED ]]; then
			/etc/init.d/emby stop
			install_emby
			create_service
			upgraded=1
		fi
	fi
	upgraded=0
}	

function create_cron_job()
{
	# put a copy of this script in Emby folder and create the cron job
	sudo cp $HOME_DIR/install-emby.sh $EMBY_HOME/install-emby.sh
	crontab -l | { cat | grep -v "install-emby.sh"; echo "0 0 * * * $EMBY_HOME/install-emby.sh cron"; } | crontab -
	dialog --title "Update Emby Server" --msgbox "\nThe Emby Server Update cron job has been created.\nThe job will run at midnight (12am) on Sunday each week.\nPress OK to return to the menu.\n" 11 70

	# restart script
	exec $HOME_DIR/install-emby.sh
}

function remove_cron_job()
{
	# put a copy of this script in Emby folder and create the cron job
	sudo rm $EMBY_HOME/install-emby.sh
	crontab -l | { cat | grep -v "install-emby.sh"; } | crontab -
	dialog --title "Update Emby Server" --msgbox "\nThe Emby Server Update cron job has been removed.\nPress OK to return to the menu.\n" 11 70

	# restart script
	exec $HOME_DIR/install-emby.sh
}


# =================================================
# Are we requesting a CRON job to be done?
# =================================================
if [[ "$1" == "cron" ]]; then
	upgrade_emby
	exit %upgraded
fi

# =================================================
# Display the menu, then execute selected option:
# =================================================
cmd=(dialog --backtitle "Emby Server installation - Version $VERSION" --menu "Welcome to the Emby Server installation.\nWhat would you like to do?\n " 14 50 16)
options=(
	1 "Install Emby Server & Kodi Add-Ons"
	2 "Add Cron job for Automatic Emby Updates"
	3 "Update Emby Server to latest version"
	4 "Update this script to latest version"
)
choices=$("${cmd[@]}" "${options[@]}" 2>&1 >/dev/tty)
for choice in $choices
do
    case $choice in
		1)	# install everything at this point!
			install_prerequisites
			install_dependencies
			build_ffmpeg
			install_mono
			install_emby
			create_service
			install_addons
			cleanup
			;;

		2)	# create cron job for updating Emby
			create_cron_job
			;;

		3)	# if newer version is available, stop Emby and upgrade!
			upgrade_emby
			if [[ $upgraded == 0 ]]; then
				dialog --title "Update Emby Server" --msgbox "\nYour Emby Server is up to date!.\nPress OK to return to the menu.\n" 11 70
			fi
			if [[ $upgraded == 1 ]]; then
				dialog --title "Update Emby Server" --msgbox "\nYour Emby Server has been upgraded to v$LATEST_VER.\nPress OK to return to the menu.\n" 11 70
			fi
			exec $HOME_DIR/install-emby.sh
			;;
			
		4)	# update this script!
			update_script
			;;
    esac
done
clear
