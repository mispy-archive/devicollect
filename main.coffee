
# Globals

folderId = null
loggedIn = false
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
  displayError("Error connecting to deviantART!")

# Main functionality

updateFolderId = (callback) ->
  console.log("Updating folder ID...")
  $.get("http://my.deviantart.com/messages/#view=deviations", (data) ->
    match = data.match(/aggid.+?(\d+)/)
    if !match?
      if data.match(/Deviant Login/)
        setLoggedOut()
      else
        console.log(data)
        displayError("Unable to find deviantWATCH folder ID.")
    else
      folderId = match[1]
      console.log("Folder ID updated!")
      callback(folderId) if callback?
  )

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
  console.log(err)
  chrome.browserAction.setBadgeText({ text: 'err' })
  chrome.browserAction.setTitle({ title: err })

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
      setLoggedOut()
    else
      #console.log(obj)
      try
        obj.DiFi.response.calls[0].response.content[0].result.hits.forEach((hit) ->
          hits.push(hit)
        )
      catch err
        console.log(err)
        displayError("Error parsing response from deviantART.")
        
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

  if loggedIn
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
  else
    checkLoginStatus()

  refreshTimer = setTimeout(refresh, Store.get('updateInterval'))

chrome.browserAction.onClicked.addListener((tab) ->
  if loading
    console.log("Loading...")
    return
  else if !loggedIn
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

setLoggedOut = ->
  console.log("Login required!")
  loggedIn = false
  folderId = null
  chrome.browserAction.setBadgeText({ text: "login" })
  chrome.browserAction.setTitle({ title: "Please log in to deviantART." })

setLoggedIn = ->
  folderId = null
  loggedIn = true
  refresh()

checkLoginStatus = ->
  chrome.cookies.get({ url: "http://my.deviantart.com/", name: "userinfo" }, (cookie) ->
    ui = $.parseJSON(decodeURIComponent(cookie.value).split(";")[1])
    if ui.username == "" and loggedIn
      setLoggedOut()
    else if ui.username != "" and !loggedIn
      setLoggedIn()
  )

chrome.cookies.onChanged.addListener (changeInfo) ->
  if changeInfo.cookie.domain == ".deviantart.com" and changeInfo.cookie.name == "userinfo"
    checkLoginStatus()

  
Store.setDefault('updateInterval', 10 * 60 * 1000)
Store.setDefault('maxTabs', 20)
setLoggedOut()
checkLoginStatus()

updateOptions = ->
  clearTimeout(refreshTimer)
  refreshTimer = setTimeout(refresh, Store.get('updateInterval'))

window.refresh = refresh
window.updateOptions = updateOptions
