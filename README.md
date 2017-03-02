## osmc_install_emby
This script sprung from [a tutorial on how to install the Emby Server](https://discourse.osmc.tv/t/howto-install-emby-server-broken/6364), which sprung from the discussion thath be found [here](https://discourse.osmc.tv/t/emby-server-osmc-on-rpi2/6274).

The goal of this project is to cleanly and easily install the Emby Server on [OSMC](http://osmc.tv), and integrate it with the Kodi installation that the OSMC install contains.

If you're not familiar with Emby, check out http://www.emby.media

## What is Emby?
In essence Emby, formerly MediaBrowser is a server software intended to provide an open source media server that can be used as a fancy DLNA server as well as through their own apps. It can also be tightly integrated with Kodi which is why I'm posting this :smile:

When integrated with kodi/Osmc Emby provides a great way to manage your media and metadata from any web browser as well as sync play positions between devices - Running Kodi or anything else!

## What this script does:
+ Installs several prerequisites, such as aptitude, unzip, and git.
+ Installs the ImageMagick, webp, mediainfo and sqlite3 packages into the 
+ Downloads/builds and installs x264 support.
+ Downloads/builds and installs FFmpeg using x264 and mp3lame support.
+ Installs the Mono libraries from [Xamarin](https://www.xamarin.com/)
+ Installs the latest Emby Server from [GitHub](https://github.com/MediaBrowser/Emby/releases/latest) (no intervention required)
+ Gets and installs the latest [Emby for Kodi repository](http://kodi.wiki/view/Add-on:Emby_for_Kodi).
+ Creates a service so that the Emby Server starts automatically.

## Optional actions this script can do:
+ Creates a Cron job, to be executedevery night at midnight, in order to keep Emby up-to-date.
+ Can update the script.
