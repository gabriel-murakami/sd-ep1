require 'drb/drb'
require 'redis'
require 'json'

class Server
  attr_accessor :peers, :redis

  def initialize
    @redis = Redis.new
  end

  def join(peer_uri, files_names)
    return 'ALREADY_JOIN' if already_join?(peer_uri)

    redis.set(peer_uri, files_names)

    puts "[JOIN] Peer #{peer_uri} adicionado com os arquivos " \
      "#{get_array(peer_uri).join(' ')}"

    'JOIN_OK'
  end

  def left(peer_uri)
    return unless redis.get(peer_uri)

    redis.del(peer_uri)

    puts "[LEFT] Peer #{peer_uri} removido"

    'LEFT_OK'
  end

  def update(peer_uri, file_name)
    if redis.get(peer_uri).nil?
      redis.set(peer_uri, [file_name])
    else
      redis.set(peer_uri, get_array(peer_uri) << file_name)
    end

    puts "[UPDATE] Peer #{peer_uri} atualizado com o arquivo #{file_name}"

    'UPDATE_OK'
  end

  def search(peer_uri, file_name)
    # é feita uma iteração mapeando todas as chaves salvas no Redis e verificando
    # se as mesmas possuem em seus arquivos algum com o mesmo nome buscado
    result = redis.keys('*').map do |key|
      next if redis.mget(key).compact.empty?

      if get_array(key).any? { |e| e == file_name }
        key
      end
    end.compact

    puts "[SEARCH] Peer #{peer_uri} solicitou o arquivo #{file_name}"

    if result.empty?
      ""
    else
      "Peers com o arquivo solicitado:\n#{result.join("\n")}"
    end
  end

  # método que checa se aquele endereço de peer já está salvo no Redis
  def already_join?(peer_uri)
    redis.get(peer_uri) != nil
  end

  private

  # faz o parse do registro do Redis para um objeto Ruby (Array)
  def get_array(peer_uri)
    JSON.parse(redis.get(peer_uri))
  end

  # instancia o Peer que está fazendo a conexão no momento
  def current_peer(peer_uri)
    DRbObject.new_with_uri(peer_uri)
  end
end
