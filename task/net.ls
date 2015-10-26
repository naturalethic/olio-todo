require! \faye
require! \http
require! \node-static
require! \rethinkdbdash

export watch = [ __filename ]

export a = ->*
  client = new faye.Client \http://localhost:8000/faye
  client.subscribe \/todo, ->
    info it
  set-timeout ->
    client.publish \/todo, { a: true }
  , 1000

export b = ->*
  client = new faye.Client \http://localhost:8000/faye
  client.subscribe \/todo, ->
    info it
  set-timeout ->
    client.publish \/todo, { b: true }
  , 1000

export serve = ->*
  file = new node-static.Server './public'
  server = http.create-server (request, response) ->
    request.add-listener \end, ->
      file.serve request, response
    .resume!
  adapter = new faye.NodeAdapter mount: \/faye, engine: { type: faye-rethinkdb }
  adapter.attach server
  server.listen 8000
  info 'Serving on port 8000'

faye-rethinkdb =
  create: (server, options) ->
    # r = rethinkdbdash db: \todo
    # r.db(\todo).table-drop \todo
    # .then ->
    #   r.db(\todo).table-create \todo
    # .then ->
    #   r.table(\todo)
    # .then ->
    last-message = null
    namespace = new faye.Namespace
    clients   = {}
    channels  = {}
    messages  = {}
    create-client: (callback, context) ->
      client = namespace.generate!
      info 'Create', client
      server.trigger \handshake, client
      callback.call context, client
    destroy-client: (client, callback, context) ->
      return if not namespace.exists client
      info 'Destroy', client
      if clients[client]
        clients[client].for-each ~>
          @unsubscribe client, channel
      namespace.release client
      delete messages[client]
      server.trigger \disconnect, client
      server.trigger \close, client
      if callback
        callback.call context
    client-exists: (client, callback, context) ->
      info 'Exists', client, namespace.exists client
      callback.call context, namespace.exists client
    ping: (client) ->
      info 'Ping', client
    subscribe: (client, channel, callback, context) ->
      info 'Subscribe', client, channel
      clients[client]   ?= new faye.Set
      channels[channel] ?= new faye.Set
      channels[channel].add client
      if clients[client].add channel
        server.trigger \subscribe, id, channel
      if callback
        callback.call context, true
      if last-message
        messages[client] ?= []
        messages[client].push faye.copy-object last-message
        @empty-queue client
    unsubscribe: (client, channel, callback, context) ->
      info 'Unsubscribe', client, channel
      if clients[client]
        if clients[client].remove channel
          server.trigger \unsubscribe, client, channel
        if clients[client].is-empty!
          delete clients[client]
      if channels[channel]
        channels[channel].remove client
        if channels[channel].is-empty!
          delete channels[channel]
      if callback
        callback.call context, true
    publish: (message, to-channels) ->
      last-message := message
      info 'Publish', message, to-channels
      to-clients = new faye.Set
      to-channels |> each (channel) ->
        if subs = channels[channel]
          subs.for-each -> to-clients.add it
      to-clients.for-each (client) ~>
        return if client == message.client-id
        info 'Queueing', client, message
        messages[client] ?= []
        messages[client].push faye.copy-object message
        @empty-queue client
      server.trigger \publish\, message.clientId, message.channel, message.data
    empty-queue: (client) ->
      if server.has-connection(client) and messages[client]
        info 'Sending', client, messages[client]
        server.deliver client, messages[client]
        delete messages[client]
    disconnect: ->
