
# Globals

folderId = null
needLogin = false
loading = false
newMessages = []

originalIcon = "icons/icon.png"
loadingIconSeq = ("icons/ajax-loader-#{n}.png" for n in [0..7])
currentIcon = originalIcon

# AJAX loading

setIcon = (path) ->
  currentIcon = path
  chrome.browserAction.setIcon({ path: path })

rotateIcon = ->
  return unless loading
  icon = loadingIconSeq[loadingIconSeq.indexOf(currentIcon)+1]
  icon = loadingIconSeq[0] if !icon?
  setIcon(icon)
  setTimeout(rotateIcon, 100)

$(document).ajaxStart ->
  console.log("Ajax start!")
  loading = true
  chrome.browserAction.setBadgeText({ text: '' })
  rotateIcon()

$(document).ajaxStop ->
  console.log("Ajax stop!")
  loading = false
  setIcon(originalIcon)

$(document).ajaxError (event) ->
  console.log("Ajax error!")
  console.log(event)
  loading = false
  setIcon(originalIcon)

# Main functionality

setLoginRequired = ->
  console.log("Login required!")
  needLogin = true
  folderId = null
  chrome.browserAction.setBadgeText({ text: "login" })
  chrome.browserAction.setTitle({ title: "Please log in to deviantART." })

updateFolderId = (callback) ->
  console.log("Updating folder ID...")
  $.get("http://my.deviantart.com/messages/#view=deviations", (data) ->
    match = data.match(/aggid.+?(\d+)/)
    if !match?
      if data.match(/Deviant Login/)
        setLoginRequired()
      else
        console.log
        displayError("Error loading deviantART!")
    else
      folderId = match[1]
      console.log("Folder ID updated!")
      callback(folderId) if callback?
  ).error (event) ->
    setLoginRequired()

deleteMessages = (msgIds, callback) ->
  chrome.cookies.get({ url: "http://my.deviantart.com/", name: "userinfo" }, (cookie) ->
    call = '"MessageCenter","trash_messages",'
    call += ("[#{folderId},\"id:devwatch:#{msgId}\"]" for msgId in msgIds).join()

    data = {
      ui: decodeURIComponent(cookie.value)
      "c[]": call
      t: 'json'
    }
    console.log("Deleting messages...")
    $.post("http://my.deviantart.com/global/difi/?", data, (resp) ->
      #console.log(resp)
      callback() if callback?
    )
  )

displayError = (err) ->
  chrome.browserAction.setBadgeText({ text: 'err' })
  chrome.browserAction.setTitle({ title: err })
  console.log(err)

maxMessages = 101

getDeviations = (callback) ->
  message_url = 'http://my.deviantart.com/global/difi/?' + encodeURI('c[]="MessageCenter","get_views",[' + folderId + ',"oq:devwatch:0:' + maxMessages + ':f:tg=deviations"]') + '&t=json'

  hits = []

  console.log("Retrieving deviations...")
  $.get(message_url, (data) ->
    window.data = data
    obj = JSON.parse(data)
    if obj.DiFi.status == "FAIL"
      #err = obj.DiFi.response.details.calls[0].response.content.error
      setLoginRequired()
    else
      #console.log(obj)
      try
        obj.DiFi.response.calls[0].response.content[0].result.hits.forEach((hit) ->
          hits.push(hit)
        )
      catch err
        displayError(err)
        
      console.log("Deviations retrieved!")
      callback(hits)
  )

updateDisplay = ->
  if newMessages.length == 0
    chrome.browserAction.setBadgeText({ text: "" })
    chrome.browserAction.setTitle({ title: "No new deviations" })
  else
    num = newMessages.length
    numDesc = if num == maxMessages then ">#{num-1}" else "#{num}"
    chrome.browserAction.setBadgeText({ text: numDesc })
    chrome.browserAction.setTitle({ title: "#{numDesc} new deviation#{if num > 1 then 's' else ''}" })

refreshTimer = null

refresh = () ->
  clearTimeout(refreshTimer) if refreshTimer?

  fetch = -> getDeviations((hits) ->
      newMessages = hits
      #extantIds = message.msgid for message in newMessages
      #for hit in hits
      #  newMessages.push(hit) unless hit.msgid in extantIds
      updateDisplay()
    )

  if !folderId?
    updateFolderId(fetch)
  else
    fetch()

  refreshTimer = setTimeout(refresh, Store.get('updateInterval'))

chrome.browserAction.onClicked.addListener((tab) ->
  if loading
    console.log("Loading...")
    return
  else if needLogin
    chrome.tabs.create( url: "http://www.deviantart.com/users/login" )
  else if newMessages.length == 0
    refresh()
  else
    max = Store.get('maxTabs')
    chrome.tabs.create( url: message.url ) for message in newMessages[0..max]
    deleteMessages(message.msgid for message in newMessages[0..max], refresh)
    newMessages = newMessages[max..-1]
)

waitForLoaded = (tabId, callback) ->
  timer = null
  repeater = () ->
    chrome.tabs.get(tabId, (tab) ->
      if tab.status == 'complete'
        clearTimeout(timer)
        callback()
      else
        timer = setTimeout(repeater, 500)
    )
  repeater()


###
chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  console.log("From: '#{tab.url}' to '#{changeInfo.url}'")
  if needLogin and tab.url.match(/deviantart.com\/($|\?loggedin)/)
    console.log("Logged in? :D")
    needLogin = false
    waitForLoaded(tab.id, refresh)
  else if tab.url.match(/deviantart.+?rockedout/)
    console.log("Logged out? :(")
    waitForLoaded(tab.id, refresh)
###

loginCheckTimer = null

chrome.cookies.onChanged.addListener (changeInfo) ->
  if changeInfo.cause == "explicit" and changeInfo.cookie.domain == ".deviantart.com" and changeInfo.cookie.name == "userinfo"
    console.log("OMG CHANGE")
    console.log(changeInfo)
    clearTimeout(loginCheckTimer)
    loginCheckTimer = setTimeout((->
      needLogin = false
      refresh()), 1000)

  
Store.setDefault('updateInterval', 10 * 60 * 1000)
Store.setDefault('maxTabs', 20)
refresh()

window.refresh = refresh
