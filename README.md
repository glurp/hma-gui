HMA-GUI
=======


Gtk application for manage client connexion to HMA VPN server.

Hma provide a gui for windows. here is a simpler version, running
for linux ( *ix) host.

based on Ruby, Gtk3, Ruiby (ruby dsl for gtk)

login/apssword are not saved : you must edit them at each run...

Issues/TODO
===========

* save parameters in crtpt form (?) : server provider, authentifications
* real detection on good  connection to hma ( geoip.hidemyass.com/ip do not work 
  with ruby open-uri
* icon, colors, styles in window...
* openvpn  traces visibles in console window (PTY do not catch stderr...)


Usage
=====
> sudo ruby hma.rb &

Installation
============
Install openvpn, ruby, and some ruby extentions :

```
     <<< install ruby 1.9.1 or + , from your ditribution or rvm script>>>
    > sudo apt-get install openvpn
    > sudo gem install pty expect
    > sudo gem install Ruiby
    >
    > sudo ruby hma.rb &
```

 
