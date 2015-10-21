/* Olio Todo

A documented example of using Olio FRP to implement the TodoMVC app.

Based on https://github.com/tastejs/todomvc/blob/master/app-spec.md

Olio FRP uses concepts from the cycle.js project (http://cycle.js.org/)

Components are read from *.ls files in the /web folder.  Any exported object from these files
is used to register a `Web Component`

Each component must provide:
  `view`: Jade template
  `intent`: Register event streams and return them as an array
  `model`: Receives events and generates the model, which will be passed to the template
Optional members:
  `style`: A style sheet (in Stylus) that will be scoped to the component
  `start`: A starting model to initialize the view
  `ready`: A function to be called after the initial rendering

Olio FRP integrates several technologies:
  * LiveScript
    Although one could (and may in the future), provide a platform for general Javascript,
    the author prefers the functional nature of LiveScript.
  * Web Components
    All *.ls files in the /web folder will be registered as components via `webcomponents.js`.
  * Jade & Mithril (VDOM Only)
    Olio uses Jade for templating.  Jade templates are compiled into functions and provided
    to the client.  A components model function will emit the `locals` for the view template.
    The template is compiled into HTML, then passed through a helper to produce mithril vdom
    code to construct the mithril tree.  The mithril vdom is then applied to the component.
  * JQuery
    Exposed globally as `q`.  Why?  `$` is ugly and hard to type.
  * Kefir
    Exposed as `s` and used for all FRP.  Olio adds a special stream creator called
    `from-child-events` which wraps JQuery's `on` in order to provide a stream that registers
    child events on the component, rather than on the actual child elements.  This is because
    the component contents (the children) may be destroyed and re-created as the vdom is applied.

Additionally, Olio provides a JQuery custom event on the window called `route`.  This event will
emit the current route, which is any location href contents beyond `#/`.

*/

# This object will be registered as a custom web component called `olio-todo`.
export olio-todo =
  # The view is compiled into a function.  When `model` emits, the framework will call the view
  # function with the model as the jade `locals`.  This will ultimately result in a mithril vdom
  # which is applied to the web component.
  view: '''
    section.todoapp
      header.header
        h1 todos
        input.new-todo(autofocus placeholder='What needs to be done?' value=(newTodo))
      if items.length
        section.main
          input.toggle-all(type='checkbox' checked=(!(items.length - completed)))
          label(for='toggle-all') Mark all as complete
          ul.todo-list
            each item, index in items
              li(class='#{item.completed ? "completed" : ""} #{item.hidden ? "hidden" : ""} #{editing == index ? "editing" : ""}' title=(item.title))
                .view
                  input.toggle(type='checkbox' checked=(item.completed))
                  label=item.title
                  button.destroy
                input.edit(value=(title))
        footer.footer
          span.todo-count
            strong #{items.length - completed}
            |  item#{(items.length - completed) != 1 ? 's' : ''} left
          ul.filters
            li
              a(class='#{!route ? "selected" : ""}' href='#/') All
            li
              a(class='#{route == "active" ? "selected" : ""}' href='#/active') Active
            li
              a(class='#{route == "completed" ? "selected" : ""}' href='#/completed') Completed
          if completed
            button.clear-completed Clear completed
    footer.info
      p Double-click to edit a todo
      p
        | Template by&nbsp;
        a(href='http://sindresorhus.com') Sindre Sorhus
      p
        | Created by&nbsp;
        a(href='http://todomvc.com') @naturalethic
      p
        | Part of&nbsp;
        a(href='http://todomvc.com') TodoMVC
  '''
  # Custom styles for the component may be defined here.  Stylus is expected.
  style: '''
    .hidden
      display: none
  '''
  # This function returns the initial state of the model for the jade template.  In this
  # case, we are checking to see if one exists in local storage, otherwise, give an initialized
  # model.
  start: ->
    if model = local-storage.get-item \todomvc-olio
      JSON.parse model
    else
      { new-todo: '', items: [], completed: 0 }
  # This is where one defines all the streams that the model should be paying attention to.
  # These are returned as an array.  Any transforms should be done here too.  The notion
  # in this example is that most of these will return a `key: value` or two.
  intent: ->
    [
      s.from-child-events this, \keydown, \.new-todo
        .filter -> it.which == 13 and it.target.value
        .map -> new-todo: it.target.value.trim!
      s.from-child-events this, \click, \.toggle
        .map -> toggle: it.current-target.parent-element.parent-element
      s.from-child-events this, \click, \.toggle-all
        .map -> toggle-all: it.target.checked
      s.from-child-events this, \click, \.clear-completed
        .map -> { +clear-completed }
      s.from-child-events this, \click, \.destroy
        .map -> destroy: it.current-target.parent-element.parent-element
      s.from-child-events this, \dblclick, '.view label'
        .map ->
          info set-timeout -> (q \.edit).focus!select! # Goofy way to do this
          editing: (q it.current-target.parent-element.parent-element).index!
      s.from-child-events this, \blur, \.edit
      s.from-child-events this, \keydown, \.edit
        .filter -> it.which == 13
        .map ->
          editing-complete: (q it.current-target.parent-element).index!
          title: it.target.value
      s.from-child-events this, \keydown, \.edit
        .filter -> it.which == 27
        .map ->
          editing-complete: (q it.current-target.parent-element).index!
      s.from-child-events this, \input, \.edit
        .map ->
          editing: (q it.current-target.parent-element).index!
          title: it.target.value
      s.from-events (q window), \route
        .map -> route: it
    ]
  # Here we generate the model for the view.  Every stream above is `merged`, so every event
  # will invoke this function, and thus a `redraw`.  In this example, the function inspects
  # the components dom, and then considers the intent it has recieved to determine the appopriate
  # view model.  Also, we go ahead and persist the model.
  model: (intent) ->
    model =
      editing: intent.editing
      new-todo: (!intent.new-todo and (q this).find('.new-todo').val!) or ''
      items: ((q this).find('.todo-list li')
      |> filter -> intent.destroy != it
      |> map -> {
        title: (intent.item-edit == it and intent.item-edit-text) or (q it).attr \title
        completed: (q it).has-class(\completed) == (it != intent.toggle)
        edit: it == intent.item-wants-edit
      }) ++ ((intent.new-todo and { title: intent.new-todo, completed: false }) or [])
      |> map -> intent.toggle-all? and it.completed = intent.toggle-all; it
      |> filter -> !(intent.clear-completed and it.completed)
      |> each -> it.hidden = (current-route! == \active and it.completed) or (current-route! == \completed and !it.completed)
    model.completed = (model.items |> filter -> it.completed).length
    if intent.editing?
      intent.title ?= model.items[intent.editing].title
      model.title = intent.title
    if intent.editing-complete?
      model.items[intent.editing-complete].title = intent.title if intent.title?
    local-storage.set-item \todomvc-olio, JSON.stringify model
    model.route = intent.route if intent.route?
    model
