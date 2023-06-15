require 'drb/drb'
require 'fileutils'
require 'socket'
require 'tty-progressbar'

PEER_BASE_URI="druby://"

class Peer
  attr_reader :peer_uri, :dir, :port, :server

  def initialize(host, port, dir, server)
    @peer_uri = "#{PEER_BASE_URI}#{host}:#{port}"
    @port = port
    @dir = create_dir(dir)
    @server = server
  end

  def download(file_name, position, content_size)
    path = "#{dir}/#{file_name}"

    if File.exist?(path)
      current_file = File.open(path, 'rb')
      current_file.seek(position)

      file_content = current_file.read(content_size)

      current_file.close

      return file_content
    else
      return nil
    end
  end

  def file_size(file_name)
    if File.exist?("#{dir}/#{file_name}")
      File.size("#{dir}/#{file_name}")
    else
      nil
    end
  end

  def menu
    puts "\n1 - JOIN\n" \
      "2 - SEARCH\n" \
      "3 - DOWNLOAD\n" \
      "4 - LEFT\n" \
      "5 - Encerrar sessão\n"
    print "\nSelecione uma opção: "

    op = gets.chomp.to_i

    begin
      case op
      when 1
        handle_response server.join(peer_uri, get_files_names)
      when 2
        handle_response search_operation
      when 3
        handle_response download_operation
      when 4
        handle_response server.left(peer_uri)
      when 5
        DRb.stop_service
        exit!
      else
        "Opção inválida"
      end
    rescue => exception
      puts "\n[ERRO] #{exception}\n\n"
    end
  end

  private

  # lida com a resposta vinda do servidor
  def handle_response(response)
    case response
    when 'JOIN_OK'
      puts "\nSou o Peer #{peer_uri} com arquivos os #{get_files_names}"
    when 'UPDATE_OK'
      puts "\e[32m\nArquivo baixado com sucesso!\e[0m"
    when 'LEFT_OK'
      puts "\e[32m\nServiço removido com sucesso!\e[0m"
    when 'ALREADY_JOIN'
      puts "\e[33m\nPeer já adicionado\e[0m"
    else
      puts "\n" + response
    end
  end

  def search_operation
    print "Insira o nome do arquivo procurado: "
    file_name = gets.chomp

    server.search(peer_uri, file_name)
  end

  def download_operation
    unless server.already_join?(peer_uri)
      return puts "\nÉ preciso se registrar antes de baixar algum conteúdo!"
    end

    print "Informe o IP do Peer para fazer o download: "
    d_host = gets.chomp
    d_host = '127.0.0.1' if d_host.empty?

    print "Informe a porta do Peer para fazer o download: "
    d_port = gets.chomp

    if self.port == d_port
      return puts "\nNão é possível baixar um arquivo próprio"
    end

    print "Informe o nome do arquivo: "
    d_file_name = gets.chomp

    download_peer_uri = "#{PEER_BASE_URI}#{d_host}:#{d_port}"

    start_position = 0
    part_size = 1_000_000

    file_size = DRbObject.new_with_uri(download_peer_uri).file_size(d_file_name)

    if file_size
      destination_file = File.open("#{dir}/#{d_file_name}", 'wb')
    else
      return puts "\nArquivo não encontrado"
    end

    puts "\n[Iniciando Download] Arquivo: #{d_file_name} | Tamanho: #{file_size/part_size} MB\n\n"

    # instancia a barra de progresso do dowload
    # https://github.com/piotrmurach/tty-progressbar
    bar = TTY::ProgressBar.new(
      "DOWNLOAD: :bar :percent",
      total: file_size,
      bar_format: :block
    )

    loop do
      content = DRbObject.new_with_uri(
        download_peer_uri
      ).download(d_file_name, start_position, part_size)

      if content
        bar.advance(part_size)

        destination_file.write(content)
        start_position += part_size
      else
        break
      end
    end

    destination_file.close

    server.update(peer_uri, d_file_name)
  end

  # lista os nomes dos arquivos contidos em um determinado diretório
  def get_files_names
    Dir.children(dir)
  end

  # cria o diretório com base no path passado
  def create_dir(dir)
    FileUtils.mkdir_p dir
    dir
  end
end
