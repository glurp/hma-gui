#######################################################################
#   hma.rb : GUI for manage VPN connection do hma network
#  Usage:
#    > sudo apt-get install openvpn
#     <<< install ruby 1.9.3 minimum >>>
#    > sudo gem install pty expect
#    > sudo gem install Ruiby
#    >
#    > sudo ruby hma.rb &
#######################################################################

def trequire(pack) 
   require pack
rescue Exception  => e
   puts "Please, install '#{pack}' : > sudo gem install #{pack}"
   exit
end
if `which openvpn`.size==0
   puts "Please, install 'openvpn' : > sudo apt-get install openvpn"
   exit
end
(puts "Must be root/sudo ! ";exit(1)) unless Process.uid==0 


require 'open-uri'
require 'open3'
trequire 'Ruiby'
trequire 'pty'
trequire 'expect'


$provider={}
$current=""
$connected=false
$openvpn_pid=0
$original_ip=open("http://geoip.hidemyass.com/ip").read.chomp
$auth=""

def check_system(with_connection)
  return unless with_connection
  vip=open("http://geoip.hidemyass.com/ip").read.chomp # truble: no hma ip is not detected...
  if vip!=$original_ip
    gui_invoke { alert("Virtual connection ok, ip=#{vip}") }
  else
    gui_invoke { error("VPN connection not active !") } 
    disconnect
  end
end

def get_list_server()
  gui_invoke { @lprovider.clear ; @lprovider.add_item("get from hma...") }
	open("https://securenetconnection.com/vpnconfig/servers-cli.php") do |body|
    $provider={}
		list=body.read.each_line.reject {|a| a=~ /USA|UK|Canada|France|Germany/i }.map {|line|
      ip,name,co,tcp,udp=line.chomp.split('|')
      $provider[name]={ip: ip,tcp: tcp,udp: udp}
      name
    }
		gui_invoke {
			@lprovider.clear
			list.sort.each { |item| @lprovider.add_item(item) ; update}
		}
  end
end

def choose_provider(item)
  ok=Message.ask("Connect to Provider \n '#{item}' \n @ip #{$provider[item][:ip]} ?")
  return unless ok

  if $auth==""
      user,pass="",""
      loop {
		    prompt("Hma client User Name ?") {|p| user=p }.run  
        return if user.size==0
		    prompt("Hma client Passwd ?") {|p| pass=p }.run
        break if user.size>2 && pass.size>2
        error("Error, redone...")
      }
      $auth=user+"////"+pass; user="";pass=""
  end

  $current=item
  if  $connected
    if ask("Kill current active vpn ?")
      disconnect
		else
			return
		end
  end
  Thread.new { connect }
end

def connect
  log "connect: to #{$current} with: #{$provider[$current]}"
  return unless $current.size>0 && $provider[$current] && $provider[$current].size>=3
  props=$provider[$current]
  ip=props[:ip]
  proto= props[:tcp]=="TCP" ? "tcp" : "udp"
  port =  (proto == "tcp") ? 443 :  53  
  log "proto #{proto}"
  log "ip  #{ip}"
  log "serveur  #{$current}"
  log "get openvpn cfg template from securenetconnection.com..." 
  tpl_uri="https://securenetconnection.com/vpnconfig/openvpn-template.ovpn"
  template=open(tpl_uri).read.split(/\r?\n/)
  template <<  "remote #{ip} #{port}" 
  template <<  "proto #{proto}" 
  template <<  "" 

  log "create .cfg file (#{template.size} lines)"
  File.write("/tmp/hma-config.cfg",template.join("\n"))
  log "run openvpn..."
  openvpn($current,"/tmp/hma-config.cfg")
 end

 def openvpn(name,cfg)
  openvpn = "openvpn --script-security 3 --verb 3 --config #{cfg} 2>&1"
  rusername = %r[Enter Auth Username:]i
  rpassword = %r[Enter Auth Password:]i
  rcompleted= %r[Initialization Sequence Completed]i
  rfail     = %r[WARNING]i
  log "spawn > #{openvpn} ..." 
  PTY.spawn(openvpn) do |read,write,pid|
    begin
      read.expect(rusername) { log "set user..."    ; write.puts $auth.split("////")[0] }
      read.expect(rpassword) { log "set passwd..." ; write.puts $auth.split("////")[1] }
      read.expect(rfail) { 
        log "NOK!!!!"
        $auth=""
        Process.kill(9,pid)
      }
      read.expect(rcompleted) { 
        log "OK!!!!"
	      gui_invoke {
          $openvpn_pid=pid
          status_connection(true)
					@ltitle.text=name
        } 
       }
      read.each { |output| log "log:    "+output.chomp }
    rescue Exception => e
      Process.kill(9,pid)
      log "openvpn Exception #{e} #{"  "+e.backtrace.join("\n  ")}"
    end
  end 
end

at_exit { Process.kill(9,$openvpn_pid) if $connected }

def log(*s)  
  p s
  gui_invoke { log s.force_encoding("UTF-8") } 
end

def disconnect
  return unless $connected
  Process.kill(9,$openvpn_pid) 
	gui_invoke {
    @ltitle.text="VPN Connection Manager"
    status_connection(false)
  } 
end

Ruiby.app width: 500,height: 400,title: "HMA VPN Connection" do
  rposition(10,10)
  def status_connection(state)
    $connected=state
    clear_append_to(@status) { label(state ? "#YES" : "#DIALOG_ERROR") } 
  end
  ############### HMI ###############
  flow do
     stacki do
       buttoni("Check vpn") { check_system(true) }
       buttoni("Refresh list") { Thread.new { get_list_server() } }
       buttoni("Disconnect...") { disconnect() }
       bourrage
       buttoni("Exit") { exit(0) }
     end
     separator
     stack do
       flowi do
          @ltitle=label("VPN Connection Manager",{
            font: "Arial bold 16",bg: "#004455", fg: "#AAAAAA"
					})
	 			  @status=stacki { labeli("") }
          status_connection(false)
       end
			 separator
       stack do
         @lprovider=list("Providers:",200,200) { |item| 
						@pvc.text=@lprovider.get_data[item.first]
				 }
         @lprovider.add_item("Loading...")
         flowi { 
           @pvc=entry("...",width:200)
					 button("Connect...") { choose_provider(@pvc.text) if @pvc.text.size>3 }
				 }
       end
     end
  end
  after 100 do
    Thread.new { 
      check_system(false) rescue nil
      get_list_server
    }
  end
end
