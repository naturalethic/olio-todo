require! \faye
require! \http
require! \node-static

export serve = ->*
  file = new node-static.Server './public'
  server = http.create-server (request, response) ->
    request.add-listener \end, ->
      file.serve request, response
    .resume!
  adapter = new faye.NodeAdapter mount: \/faye
  adapter.attach server
  server.listen 8080