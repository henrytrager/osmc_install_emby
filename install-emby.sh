#!/bin/bash
#===================================================================#
# Simple Emby Server Installer - by dougiefresh                     #
#===================================================================#
# DISCLAIMER: This is a script by dougiefresh to install Emby       #
# Server to OSMC.  I am not responsible for any harm done to        #
# your system.  Using this script is done at your own risk.         #
#===================================================================#
VERSION=0.4
HOME_DIR=/home/osmc
EMBY_HOME=/opt/mediabrowser
PID_FILE=$EMBY_HOME/mediabrowser.pid
MONO_DIR=/usr/bin

# ==================================================================
# First function of script!  DO NOT CHANGE PLACEMENT!!
# ==================================================================
function update_script()
{
	# ==================================================================
	title "Upgrading Emby installation script..."
	# ==================================================================
	# retrieve the latest version of the script from GitHub:
	wget --no-check-certificate -w 4 -O $HOME_DIR/install-emby.sh.1 https://raw.githubusercontent.com/douglasorend/osmc_install_emby/master/install-emby.sh 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Downloading latest version of Emby Server script" --gauge "\nPlease wait...\n"  11 70
	chmod +x $HOME_DIR/install-emby.sh.1
	mv $HOME_DIR/install-emby.sh.1 $HOME_DIR/install-emby.sh
	if [[ -f $EMBY_HOME/install-emby.sh ]]; then
		cp $HOME_DIR/install-emby.sh $EMBY_HOME/install-emby.sh
	fi

	# restart script
	exec $HOME_DIR/install-emby.sh
}

# ==================================================================
# Sub-Functions required by this script:
# ==================================================================
function title()
{
	echo -ne "\033]0;$1\007"
}

function fix_config()
{
	# ==================================================================
	# Fixing Emby configuration files happens here:
	# Needs more work for it to work properly in all cases:
	# ==================================================================
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
	
	# ==================================================================
	# Fix TimeZone issue found by Toast on OSMC discussion board
	# ==================================================================
	 sudo sh -c "echo export TZ='\$(cat /etc/timezone)' >> /etc/profile"
}

function find_latest_stable()
{
	file=$(curl -s https://github.com/MediaBrowser/Emby/releases/latest | sed -n 's/.*href="\([^"]*\).*/\1/p')
	LATEST_VER=$(basename $file | tee /tmp/mediabrowser.current)
	file=$(curl -s $file | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "Emby.Mono.zip")
}

function find_latest_beta()
{
	list=$(curl -s https://github.com/MediaBrowser/Emby/releases | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep '/download/' | grep "Emby.Mono.zip")
	file=''
	for item in $list
	do
		if [[ $item > $file ]]; then
			file=$item
		fi
	done
	LATEST_VER=$(basename $(dirname $file) | tee /tmp/mediabrowser.current)
}

# ==================================================================
# Functions performing major tasks in this script:
# ==================================================================
function install_prerequisites()
{
	# ==================================================================
	title "Installing prerequisites..."
	# ==================================================================
	sudo apt-get --show-progress -y --force-yes install aptitude unzip git build-essential pv dialog --ascii-lines cron-app-osmc 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Installing prerequisite programs if they are not present" --gauge "\nPlease wait...\n" 11 70
}

function install_dependencies()
{
	# ==================================================================
	title "Installing Dependencies...."
	#=============================================================================================
	sudo aptitude install imagemagick imagemagick-6.q16 imagemagick-common libimage-magick-perl libimage-magick-q16-perl libmagickcore-6-arch-config libmagickcore-6-headers libmagickcore-6.q16-2 libmagickcore-6.q16-2-extra libmagickcore-6.q16-dev libmagickwand-6-headers libmagickwand-6.q16-2 libmagickwand-6.q16-dev libmagickwand-dev webp mediainfo sqlite3
}

function build_ffmpeg()
{
	#=============================================================================================
	title "Building and installing FFmpeg...."
	#=============================================================================================
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
	# ==================================================================
	title "Installing Mono libraries..."
	# ==================================================================
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF
	echo "deb http://download.mono-project.com/repo/debian wheezy main" | sudo tee /etc/apt/sources.list.d/mono-xamarin.list
	test $(cat /etc/debian_version) > 7.999999 && (
        echo "deb http://download.mono-project.com/repo/debian wheezy-apache24-compat main" | sudo tee -a /etc/apt/sources.list.d/mono-xamarin.list;
		echo "deb http://download.mono-project.com/repo/debian wheezy-libjpeg62-compat main" | sudo tee -a /etc/apt/sources.list.d/mono-xamarin.list;
	)
	sudo apt-get update 2>&1 | dialog --ascii-lines --title "Updating package database..." --infobox "\nPlease wait...\n" 11 70
	sudo apt-get --show-progress -y install mono-complete 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Installing Mono libraries if they are not present" --gauge "\nPlease wait...\n" 11 70
}

function install_emby()
{
	# ==================================================================
	title "Getting latest version of Emby from GitHub..."
	# ==================================================================
	find_latest_stable
	wget --no-check-certificate -w 4 http://github.com$file -O /tmp/Emby.Mono.zip 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Downloading Emby Server v$latest" --gauge "\nPlease wait...\n"  11 70
	sudo unzip -o /tmp/Emby.Mono.zip -d $EMBY_HOME
	rm /tmp/Emby.Mono.zip
	sudo mv /tmp/mediabrowser.current $EMBY_HOME/mediabrowser.current
	fix_config
}

function create_service()
{
	# ==================================================================
	title "Adding Emby Service..."
	# ==================================================================

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
	echo "PIDFILE=\"$PID_FILE\"" >> /tmp/emby
	echo "EXEC=\"$EMBY_HOME/MediaBrowser.Server.Mono.exe -ffmpeg /usr/local/share/man/man1/ffmpeg.1 -ffprobe /usr/local/share/man/man1/ffprobe.1\"" >> /tmp/emby
	echo "" >> /tmp/emby
	echo "case \"\$1\" in" >> /tmp/emby
	echo "	start)" >> /tmp/emby
	echo "		echo \"Starting Emby server...\"" >> /tmp/emby
	echo "		start-stop-daemon -S -m -p \$PIDFILE -b -x $MONO_DIR/mono -- \${EXEC}" >> /tmp/emby
	echo "		;;" >> /tmp/emby
	echo "  stop)" >> /tmp/emby
	echo "		echo \"Stopping Emby server...\"" >> /tmp/emby
	echo "	  	start-stop-daemon -K -p \${PIDFILE}" >> /tmp/emby
	echo "		rm $PID_FILE" >> /tmp/emby
	echo "		;;" >> /tmp/emby
	echo "  restart|force_reload)" >> /tmp/emby
	echo "		echo \"Stopping Emby server...\"" >> /tmp/emby
	echo "		start-stop-daemon -K -p \${PIDFILE}" >> /tmp/emby
	echo "		rm $PID_FILE" >> /tmp/emby
	echo "		sleep 3" >> /tmp/emby
	echo "		echo \"Starting Emby server...\"" >> /tmp/emby
	echo "		start-stop-daemon -S -m -p \$PIDFILE -b -x $MONO_DIR/mono -- \${EXEC}" >> /tmp/emby
	echo "    ;;" >> /tmp/emby
	echo "  *)" >> /tmp/emby
	echo "    echo \"Usage: /etc/init.d/emby {start|stop|restart|force_reload}\"" >> /tmp/emby
	echo "    exit 1" >> /tmp/emby
	echo "    ;;" >> /tmp/emby
	echo "esac" >> /tmp/emby
	sudo echo "exit 0" >> /tmp/emby

	# Move the new service file into position and activate it:
	sudo mv /tmp/emby /etc/init.d/emby
	sudo chmod 755 /etc/init.d/emby
	sudo update-rc.d emby defaults
	sudo /etc/init.d/emby start

	# Add cron task to remove "mediabrowser-server.pid" after reboot:
	crontab -l | { cat | grep -v "$PID_FILE"; echo "@reboot rm $PID_FILE"; } | crontab -
}

function get_addon()
{
	# ==================================================================
	# Get the addon, unzip, then move the zip to the package store of OSMC
	# ==================================================================
    file=$(curl -s $1 | sed -n 's/.*href="\([^"]*\).*/\1/p' | grep "$2")
    wget --no-check-certificate -w 4 $1/$file -O /tmp/$file 2>&1 | grep --line-buffered -oP "(\d+(\.\d+)?(?=%))" | dialog --ascii-lines --title "Downloading Addon" --gauge "\nPlease wait...\n"  $
    unzip /tmp/$file -d $HOME_DIR/.kodi/addons
    mv /tmp/$file $HOME_DIR/.kodi/addons/packages/$file
}

function install_addons()
{
	# ==================================================================
	title "Installing Emby for Kodi repository and addons..."
	# ==================================================================
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

function done_installing()
{
	ip="hostname -I"
	dialog --ascii-lines --title "FINISHED!" --msgbox "\nYour Emby Server should now be available for you at http://$ip:8096\nPress OK to return to the menu.\n" 11 70
	exec $HOME_DIR/install-emby.sh
}

function upgrade_emby()
{
	upgraded=0
	find_latest_stable
	if [[ $LATEST_VER > $INSTALLED ]]; then
		sudo /etc/init.d/emby stop
		install_emby
		create_service
		upgraded=1
	fi
}

function create_cron_job()
{
	#=============================================================================================
	title "Creating Cron Job for OSMC..."
	#=============================================================================================
	# put a copy of this script in Emby folder and create the cron job:
	sudo cp $HOME_DIR/install-emby.sh $EMBY_HOME/install-emby.sh
	crontab -l | { cat | grep -v "install-emby.sh"; echo "@daily $EMBY_HOME/install-emby.sh cron"; } | crontab -
	dialog --ascii-lines --title "Creating Cron Job for OSMC" --msgbox "\nThe Emby Server Update cron job has been created.\nThe job will run at midnight (12am) on Sunday each week.\nPress OK to return to the menu.\n" 11 70

	# restart script
	exec $HOME_DIR/install-emby.sh
}

function remove_cron_job()
{
	#=============================================================================================
	title "Removing Cron Job for OSMC..."
	#=============================================================================================
	# put a copy of this script in Emby folder and create the cron job
	sudo rm $EMBY_HOME/install-emby.sh
	crontab -l | { cat | grep -v "install-emby.sh"; } | crontab -
	dialog --ascii-lines --title "Removing Cron Job for OSMC" --msgbox "\nThe Emby Server Update cron job has been removed.\nPress OK to return to the menu.\n" 11 70

	# restart script
	exec $HOME_DIR/install-emby.sh
}

# ==================================================================
# Figure out what version of Emby Server we are running:
# ==================================================================
INSTALLED=
if [[ -f $EMBY_HOME/mediabrowser.current ]]; then
	INSTALLED=$(cat $EMBY_HOME/mediabrowser.current)
else
	if [[ -f $EMBY_HOME/ProgramData-Server/config/system.xml ]]; then
		url=http://$(echo $(hostname -I)):$(echo $(cat $EMBY_HOME/ProgramData-Server/config/system.xml | grep "HttpServerPortNumber" | sed -e 's/<[a-zA-Z\/][^>]*>//g'))
		INSTALLED=$(curl -s $url/web/login.html | sed -n 's/.*window.dashboardVersion=\([^"]*\).*/\1/p' | cut -d";" -f1)
		INSTALLED=$(echo ${INSTALLED//\'/} | tee /tmp/mediabrowser.current)
		sudo mv /tmp/mediabrowser.current $EMBY_HOME/mediabrowser.current
	fi
fi

# ==================================================================
# Are we requesting a CRON job to be done?
# ==================================================================
if [[ "$1" == "cron" ]]; then
	upgrade_emby
	exit $upgraded
fi

# ==================================================================
# Display the menu, then execute selected option:
# ==================================================================
title "Emby Server installation - Version $VERSION"
cmd=(dialog --ascii-lines --cancel-label "Exit" --backtitle "Simple Emby Server Installer - Version $VERSION" --menu "Welcome to the Simple Emby Server Installer.\nWhat would you like to do?\n " 14 50 16)
if [[ -f $EMBY_HOME/mediabrowser.current ]]; then
	options=(
		1 "Install Emby Server & Kodi Add-Ons"
		2 "Update this script to latest version"
		3 "Add Cron job for Automatic Emby Updates"
		4 "Update Emby Server to latest version"
	)
else
	options=(
		1 "Install Emby Server & Kodi Add-Ons"
		2 "Update this script to latest version"
	)
fi
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
			done_installing
			;;

		2)	# update this script!
			update_script
			;;

		3)	# create cron job for updating Emby
			create_cron_job
			;;

		4)	# if newer version is available, stop Emby and upgrade!
			upgrade_emby
			if [[ $upgraded == 0 ]]; then
				dialog --ascii-lines --title "Update Emby Server" --msgbox "\nYour Emby Server is up to date!.\nPress OK to return to the menu.\n" 11 70
			fi
			if [[ $upgraded == 1 ]]; then
				dialog --ascii-lines --title "Update Emby Server" --msgbox "\nYour Emby Server has been upgraded to v$LATEST_VER.\nPress OK to return to the menu.\n" 11 70
			fi
			exec $HOME_DIR/install-emby.sh
			;;
    esac
done
clear
