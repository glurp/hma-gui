HMA-GUI
=======


Gtk application for manage client connexion to VPN server.
Curently, connection to HMA and IPVanish are supported.

based on Ruby, Gtk3, Ruiby (ruby dsl for gtk)

login/password are save in local file, uncryped.

Usage
=====
> gksudo ruby hma.rb &
> gksuo ruby ipvanish.rb &

Installation
============
Install openvpn, ruby, and some ruby extentions :

```
     <<< install ruby 1.9.1 or + , from your distribution or rvm script>>>
    > sudo apt-get install openvpn
    > sudo gem install pty expect rubyzip
    > sudo gem install Ruiby
    >
    > sudo ruby hma.rb &
```

License
=======
LGPL V2.1



 
