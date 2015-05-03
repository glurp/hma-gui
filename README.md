HMA-GUI
=======


Gtk application for manage client connexion to VPN server.
Curently, connection to HMA is supported.

based on Ruby, Gtk3, Ruiby (ruby dsl for gtk)

login/password are save in local file, uncryped.
Features are :
* load list server from hma 
* let user choose one server
* connect/disconnect
* check if connection is realy on vpn (http geoip.com)
* speed test (download a big iso file from public repo)
* memorise login/password, forget memorisation

Usage
=====
> gksudo ruby hma.rb &

Installation
============
Install openvpn, ruby, and some ruby extentions :

```
     <<< install ruby 1.9.1 or + , from your distribution or rvm script>>>
    > sudo apt-get install openvpn
    > sudo gem install pty expect rubyzip Ruiby
    > git clone https://github.com/glurp/hma-gui
    > sudo ruby hma.rb &
```

License
=======
LGPL V2.1



 
