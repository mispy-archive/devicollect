Store = {}

Store.get = (key) ->
  localStorage[key]? and $.parseJSON(localStorage[key])

Store.set = (key, val) ->
  localStorage[key] = $.toJSON(val)

Store.setDefault = (key, val) ->
  Store.set(key, val) unless Store.get(key, val)?

window.Store = Store
