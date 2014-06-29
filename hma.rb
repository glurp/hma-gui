#!/usr/bin/ruby
# encoding: utf-8
#
# License: LGPL V2.1
#
#######################################################################
#   hma.rb : GUI for manage VPN connection to hma network
#  Usage:
#    > sudo apt-get install openvpn
#     <<< install ruby 1.9.3 minimum >>>
#    > sudo gem install pty expect
#    > sudo gem install Ruiby
#    >
#    > sudo ruby hma.rb &
#######################################################################

##################### Check machine envirronent #############" 
if `which openvpn`.size==0
   puts "Please, install 'openvpn' : > sudo apt-get install openvpn"
   exit
end
if !Dir.exists?("/etc") && !Dir.exists?("/user")
   puts "Please, run mme on i Unix/Bsd/Linux machine...."
   exit
end
(puts "Must be root/sudo ! ";exit(1)) unless Process.uid==0 

##################""" Load ruby gem dependancy #################
def trequire(pack) 
   require pack
rescue Exception  => e
   puts "Please, install '#{pack}' : > sudo gem install #{pack}"
   exit
end

require 'open-uri'
require 'open3'
trequire 'Ruiby'
trequire 'pty'
trequire 'expect'
require_relative 'ip_speed_test.rb'

################################ Global state ##################

$provider={}
$current=""
$connected=false
$openvpn_pid=0
$thtail=nil
$style_ok= <<EOF
* { background-image:  -gtk-gradient(linear, left top, left bottom,  from(#066), to(#ACC));
    color: #FFFFFF;
}
GtkEntry,GtkTreeView { background-image:  -gtk-gradient(linear, left top, left bottom,  
      from(#FFE), to(#EED));
    color: #000;
}
GtkButton, GtkButton > GtkLabel { background-image:  -gtk-gradient(linear, left top, left bottom,  
      from(#EFF), to(#CDD));
    color: #000;
}
EOF
$style_nok= <<EOF
* { background-image:  -gtk-gradient(linear, left top, left bottom,  from(#966), to(#FCC));
    color: #FFFFFF;
}
GtkEntry,GtkTreeView { background-image:  -gtk-gradient(linear, left top, left bottom,  
      from(#FFE), to(#EED));
    color: #000;
}
GtkButton, GtkButton > GtkLabel { background-image:  -gtk-gradient(linear, left top, left bottom,  
      from(#EFE), to(#DED));
    color: #000;
}
EOF



$auth=""
if $auth.size>0 
  puts "*************** Auth in code !!!! Do not commit !!! ************************"
end
if File.exists?("client.cred")  
  $auth=File.read("client.cred")
end 

############################# Tools ##############################
def check_system(with_connection)
  return unless with_connection
  data=open("http://geoip.hidemyass.com").read.chomp
  if (data=~ /<table>(.*?)<\/table>/m)
    props=$1.gsub(/\s+/,"").
            split(/<\/*tr>/).select {|s| s && s.size>0}.
            each_with_object({}) { |r,h| 
              k,v=r.split("</td><td>").map {|c| ;c.gsub(/<.*?>/,"")}
              h[k]=v if k && v
            }
    alert("Your connection is :\n #{props.map {|kv| "%-10s : %10s" % kv}.join("\n")}")
  else
  end
end

def get_list_server()
  gui_invoke { @lprovider.clear ; @lprovider.add_item("get server list from hma...") }
  iplist="https://securenetconnection.com/vpnconfig/servers-cli.php"
  begin
	  open(iplist) do |body|
      gui_invoke { @lprovider.add_item("server reached...") }
      $provider={}
		  list=body.read.each_line.reject {|a| a=~ /USA|UK|Canada|France|Germany/i }.map {|line|
        ip,name,co,tcp,udp=line.chomp.split('|')
        $provider[name]={ip: ip,tcp: tcp,udp: udp}
        name
      }
		  gui_invoke {
			  @lprovider.clear
			  list.sort.each_with_index { |item,i| @lprovider.add_item(item) ; update if i%10==1}
		  }
    end
  rescue Exception => e
		  gui_invoke { error("Error getting HMA server list : #{e} \n on #{iplist}")}
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
      File.write("client.cred",$auth) 
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
  flog="/tmp/openvpn_hma.log"
  log "proto #{proto}"
  log "ip  #{ip}"
  log "serveur  #{$current}"
  log "get openvpn cfg template from securenetconnection.com..." 
  tpl_uri="https://securenetconnection.com/vpnconfig/openvpn-template.ovpn"
  log "...get openvpn cfg template ok"
  template=open(tpl_uri).read.split(/\r?\n/)
  template <<  "remote #{ip} #{port}" 
  template <<  "proto #{proto}" 
  template <<  "log-append #{flog}" 
  template <<  "" 

  log "create .cfg file (#{template.size} lines)"
  File.write("/tmp/hma-config.cfg",template.join("\n"))
  log "run openvpn..."
  openvpn($current,"/tmp/hma-config.cfg",flog)
 end

 def openvpn(name,cfg,flog)
  openvpn = "openvpn --script-security 3 --verb 4 --config #{cfg} 2>&1"
  rusername = %r[Enter Auth Username:]i
  rpassword = %r[Enter Auth Password:]i
  rcompleted= %r[Initialization\s*Sequence\s*Completed]i
  rfail     = %r[AUTH_FAILED]i
  log "spawn > #{openvpn} ..." 
  th=tailmf(flog,rcompleted,rfail)
  PTY.spawn(openvpn) do |read,write,pid|
    begin
      $openvpn_pid=pid
      th0=nil
      read.expect(rusername) { log "set user..."    ; write.puts $auth.split("////")[0] }
      read.expect(rpassword) { log "set passwd..."  ; write.puts $auth.split("////")[1] }
      read.expect(rcompleted) {
				log "OK !!!!"
				gui_invoke {
				 status_connection(true)
				 @ltitle.text=name
				} 
      }
      read.each { |o| log "log:    "+o.chomp }
    rescue Exception => e
	    gui_invoke { status_connection(false) }
      Process.kill(9,pid)
      log "openvpn Exception #{e} #{"  "+e.backtrace.join("\n  ")}"
    ensure
      th.kill rescue nil
    end
  end 
  $openvpn_pid=0
end

def disconnect
  if $openvpn_pid==0
    gui_invoke { system("killall","openvpn")  if ask("Kill all 'openvpn' session ?") }
    return
  end
  Process.kill("INT",$openvpn_pid) rescue nil
  $openvpn_pid=0
	gui_invoke { status_connection(false) } 
end

def reconnect()
 if $current.size>0 && $provider[$current] && $auth.size>0 && $auth.split("////").size==2
   Thread.new() {  
     disconnect()
     log "sleep 4 seconds..."
     sleep 4
     log "reconnect..."
     connect()
   }
 else
   alert("Not connected !!!")
 end
end

def speed_test()
  alabel=[]
  dialog_async("Speed test",{:response=> proc {|dia| $sth.kill if $sth; true }}) {
     stack(bg:"#FFF") {
       3.times { |i| alabel << entry("",bg:"#FFF",fg:"#000") }
     }
  }
  alabel[0].text="Connecting..."
  $sth=ip_speed_test(4) { |qt,delta,speed| 
    alabel[0].text=""
    if delta>0
      alabel[1].text="downlolad test..."
      alabel[2].text="Speed : #{speed.round(2)} KB/s"
    else
      alabel[1].text="End test"
    end
  }
end

at_exit { (Process.kill("TERM",$openvpn_pid) rescue nil; $openvpn_pid=0) if $openvpn_pid>0 }

###########################################################################
#               M A I N    W I N D O W
###########################################################################

Ruiby.app width: 500,height: 400,title: "HMA VPN Connection" do
  rposition(1,1)
  def status_connection(state)
    $connected=state
    def_style state ? $style_ok : $style_nok 
    @ltitle.text= state ? $current : "VPN Connection Manager"
    clear_append_to(@status) { label(state ? "#YES" : "#DIALOG_ERROR") } 
  end
  ############### HMI ###############
  flow do
     stacki do
       buttoni("Check vpn") { check_system(true) }
       buttoni("Refresh list") { Thread.new { get_list_server() } }
       buttoni("Disconnect...") { Thread.new { disconnect() } }
       buttoni("Change IP...") { reconnect() }
       buttoni("Speed Test...") { speed_test() }
       buttoni("Forget name&pass") { $auth=""; File.delete("client.cred") }
       bourrage
       buttoni("Exit") { ruiby_exit()  }
     end
     separator
     stack do
       flowi do
          @ltitle=label("VPN Connection Manager",{
            font: "Arial bold 16",bg: "#004455", fg: "#AAAAAA"
					})
	 			  @status=stacki { labeli("#DIALOG_ERROR") }
	 			  $connected=false
       end
			 separator
       stack do
         @lprovider=list("Providers:",200,200) { |item| 
						@pvc.text=@lprovider.get_data[item.first] rescue nil
				 }
         @lprovider.add_item("Loading...")
         flowi { 
           @pvc=entry("...",width:200)
					 button("Connect...") { choose_provider(@pvc.text) if @pvc.text.size>3 }
				 }
       end
     end
  end
  after(50) do
    Thread.new {
       begin
         puts "get public ip..."
         $original_ip=open("http://geoip.hidemyass.com/ip").read.chomp
         puts "public is ip=#{$original_ip}"
         gui_invoke {alert("Public ip is #{$original_ip}") }
       rescue 
         $original_ip=""
         gui_invoke {error("Internet seem unreachable !") }
       end
      check_system(false) rescue nil
      get_list_server
    }
  end  
  set_icon "hme32.png" 
end
