require 'drb/drb'
require_relative 'server'

SERVER_URI="druby://127.0.0.1:1099"

if DRb.start_service(SERVER_URI, Server.new)
  puts "[SERVIDOR ONLINE]\n"
end

# Coloca o servidor para abrir threads ao receber uma conexão
DRb.thread.join
