# install-scripts
Various scripts to aid in (re)installations of various services for FreeNAS 11.2. Use with caution as doing anything behind the back of the FreeNAS GUI could break things, especially if you configure the wrong network settings.

## Airsonic
This build requires `ffmpeg` to be compiled from source in order to include non-free codecs (like mp3). When prompted, the user should set/unset the following options:

    SET: LAME, OPUS, NONFREE
    UNSET: DOCS, OPENCV, V4L, VAAPI, VDPAU, X264, X265, XVID

Web interface default port:

## Apache/MySql/PHP (AMP)

## Emby
This build requires `ffmpeg` to be compiled from source in order to include non-free codecs (like mp3). When prompted, the user should set/unset the following options:

    SET: ASS, LAME, OPUS, X265, NONFREE
    UNSET: DOCS

Similarily with `imagemagick`:

    UNSET: 16BIT_PIXEL

Web interface default port: http/8096

## Nextcloud
Self-hosted "cloud" dropbox solution.

Web interface default port:

## OpenVPN
VPN server for remote encrypted connections. Automatically builds a self-signed CA and generates a server cert.

Note: `tun` devices in jails are broken in 11.2, so this service won't work.

## Transmission w/ VPN
Bittorrent daemon with a web interface, setup to tunnel all traffic over a VPN (specifically PIA).

Web interface default port: http/9091

Note: `tun` devices in jails are broken in 11.2, so this service won't work.

## UniFi
Network device management for Ubiquiti UniFi devices.

Web interface default port: https/8443
