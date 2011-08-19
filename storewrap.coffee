Store = {}

Store.get = (key) ->
  if localStorage[key]? then $.parseJSON(localStorage[key]) else null

Store.set = (key, val) ->
  localStorage[key] = $.toJSON(val)

Store.setDefault = (key, val) ->
  Store.set(key, val) unless Store.get(key, val)

window.Store = Store
