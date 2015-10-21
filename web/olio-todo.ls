export olio-todo =
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
  style: '''
    .hidden
      display: none
  '''
  start: ->
    if model = local-storage.get-item \todomvc-olio
      JSON.parse model
    else
      { new-todo: '', items: [], completed: 0 }
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
