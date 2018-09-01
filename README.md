# install-scripts
Various scripts to aid in (re)installations.

Built and tested for FreeNAS 11.1-U5.

Note that some of these builds require ffmpeg to be built from source in order to include non-free codecs (like mp3). This requires manual config by the user and the build process can take a long time.

## Airsonic Music Server
ffmpeg:
    SET: LAME, OPUS, NONFREE
    UNSET: DOCS, OPENCV, V4L, VAAPI, VDPAU, X264, X265, XVID

## Apache/MySql/PHP (AMP)

## Emby Media Server
ffmpeg
    SET: ASS, LAME, OPUS, X265, NONFREE
    UNSET: DOCS
imagemagick
    UNSET: 16BIT_PIXEL

## Nextcloud
TODO: all

## Transmission BitTorrent Daemon
TODO: openvpn tunnel interface and firewall setup

## UniFi Controller
