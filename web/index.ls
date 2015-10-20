export index =
  view: '''
    doctype html
    html(lang='en')
      head
        meta(charset='utf-8')
        meta(name='viewport', content='width=device-width, initial-scale=1')
        title Olio • TodoMVC
      body
        script(src='./index.js')
        pm-main
  '''
  style: '''
    @import url("../node_modules/todomvc-common/base.css");
    @import url("../node_modules/todomvc-app-css/index.css");
  '''
  module: ->
