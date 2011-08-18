save = ->
  val = parseInt($('#updateInterval').val())
  if val > 0
    Store.set('updateInterval', parseInt(val * 60 * 1000))

$ ->
  $('#updateInterval').val(Store.get('updateInterval') / 60 / 1000)

  saveTimer = null

  saving = false

  saveLoop = ->
    return unless saving
    clearTimeout(saveTimer)
    save()
    saveTimer = setTimeout(save, 300)

  $("#updateInterval").focus ->
    saving = true
    saveLoop()

  $("#updateInterval").blur ->
    save()
    saving = false
