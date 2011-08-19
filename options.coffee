save = ->
  updateInterval = parseInt($('#updateInterval').val())
  maxTabs = parseInt($('#maxTabs').val())
  if updateInterval > 0
    if updateInterval != Store.get('updateInterval')
      Store.set('updateInterval', updateInterval * 60 * 1000)
      chrome.extension.getBackgroundPage().updateOptions()
  if maxTabs > 0
    Store.set('maxTabs', maxTabs)


$ ->
  $('#updateInterval').val(Store.get('updateInterval') / 60 / 1000)
  $('#maxTabs').val(Store.get('maxTabs'))

  saveTimer = null

  saving = false

  saveLoop = ->
    return unless saving
    clearTimeout(saveTimer)
    save()
    saveTimer = setTimeout(save, 300)

  focused = ->
    saving = true
    saveLoop()

  blurred = ->
    save()
    saving = false

  $("#updateInterval").focus focused
  $("#maxTabs").focus focused

  $("#updateInterval").blur blurred
  $("#maxTabs").blur blurred

