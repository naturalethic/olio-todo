faye = require 'faye/browser/faye-browser'
client = new faye.Client \/faye

client.subscribe \/todo, ->
  post-message it

self.onmessage = ->
  client.publish \/todo, it.data
