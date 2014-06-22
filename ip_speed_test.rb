require 'socket'
require 'thread'
require 'timeout'



def ip_speed_test(dt,&block)
  Thread.new do
    # http://releases.ubuntu.com/releases/14.04/ubuntu-14.04-desktop-i386.iso
    iso="ubuntu-14.04-desktop-i386.iso"
    host="releases.ubuntu.com"
    uri="http://#{host}"
    path="/releases/14.04"
    url="#{uri}#{path}/#{iso}"

    header= <<EOF
GET #{url} HTTP/1.0
User-Agent: Mozilla/5.0 (X11; Ubuntu; Linux i686; rv:30.0) Gecko/20100101 Firefox/30.0
Host: iso.linuxquestions.org
Connection: close

EOF
    header.gsub!(/\n/,"\r\n")
    puts header
	  timeout(12000) {
		  s = TCPSocket.open(host, 80) 
      s.sync=true
      s.print header
      content=s.recv(1)
		  ss=0
      start=Time.now.to_f
		  loop  do
        content=s.recv(1024)
        break unless content && content.size>0
			  ss+=content.size
        now=Time.now.to_f
        if (now-start)>dt
          speed=ss/(1024*(now-start))
          if block
           block.call(ss,now-start,speed) 
          else
            puts "size #{ss} during #{now-start} seconds >> speed= #{speed} KB/s"
          end
				  ss=0
				  start=now
			  end
		  end
		  s.close
	  } rescue puts "Error #{$!}"
    if block_given?
      yield(0,0,0) 
    end
  end 
end


if $0==__FILE__
  th=ip_speed_test(1) { |qt,delta,speed| puts "speed #{speed.round} KB/s" }
  sleep 30
  puts "kill thread..."
  th.kill
end

