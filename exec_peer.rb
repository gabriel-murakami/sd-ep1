require 'drb/drb'
require_relative 'peer'
require 'net/ping'

SERVER_URI="druby://127.0.0.1:1099"
server = DRbObject.new_with_uri(SERVER_URI)

print "Informe o IP do Peer: "
host = gets.chomp
host = '127.0.0.1' if host.empty?

port = nil

loop do
  print "Informe a porta do Peer: "
  port = gets.chomp

  if Net::Ping::TCP.new(host, port).ping?
    puts "\e[31mEssa porta encontra-se em uso.\e[0m"
  else
    break
  end
end

print "Informe a pasta dos arquivos: "
dir = gets.chomp

current_peer = Peer.new(host, port, dir, server)
DRb.start_service(current_peer.peer_uri, current_peer)

loop do
  current_peer.menu
end
