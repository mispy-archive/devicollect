
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
      console.log(resp)
      callback() if callback?
    )
  )

displayError = (err) ->
  chrome.browserAction.setBadgeText({ text: 'err' })
  chrome.browserAction.setTitle({ title: err })
  console.log(err)

getDeviations = (callback) ->
  #message_url = 'http://my.deviantart.com/global/difi/?' + encodeURIComponent('c[]="MessageCenter","get_views",[18173586,"oq:devwatch:0:48:f:tg=deviations"]&t=json')
  message_url = "http://my.deviantart.com/global/difi/?c%5B%5D=%22MessageCenter%22%2C%22get_views%22%2C%5B" + folderId + "%2C%22oq%3Adevwatch%3A0%3A48%3Af%3Atg%3Ddeviations%22%5D&t=json"

  hits = []

  console.log("Retrieving deviations...")
  $.get(message_url, (data) ->
    window.data = data
    obj = JSON.parse(data)
    if obj.DiFi.status == "FAIL"
      #err = obj.DiFi.response.details.calls[0].response.content.error
      setLoginRequired()
    else
      obj.DiFi.response.calls[0].response.content[0].result.hits.forEach((hit) ->
        hits.push(hit)
      )
      console.log("Deviations retrieved!")
      callback(hits)
  )

updateDisplay = ->
  if newMessages.length == 0
    chrome.browserAction.setBadgeText({ text: "" })
    chrome.browserAction.setTitle({ title: "No new deviations" })
  else
    num = newMessages.length
    chrome.browserAction.setBadgeText({ text: num.toString() })
    chrome.browserAction.setTitle({ title: "#{num} new deviation#{if num > 1 then 's' else ''}" })

refreshTimer = null

refresh = () ->
  clearTimeout(refreshTimer) if refreshTimer?

  fetch = -> getDeviations((hits) ->
      extantIds = message.msgid for message in newMessages
      for hit in hits
        newMessages.push(hit) unless hit.msgid in extantIds
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
    chrome.tabs.create( url: message.url ) for message in newMessages
    deleteMessages(message.msgid for message in newMessages)
    newMessages = []
    updateDisplay()
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


chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
  #console.log("From: '#{tab.url}' to '#{changeInfo.url}'")
  if needLogin and tab.url.match(/deviantart.com\/($|\?loggedin)/)
    console.log("Logged in? :D")
    needLogin = false
    waitForLoaded(tab.id, refresh)
  else if tab.url.match(/deviantart.+?rockedout/)
    console.log("Logged out? :(")
    waitForLoaded(tab.id, refresh)

  
Store.setDefault('updateInterval', 10 * 60 * 1000)
refresh()

window.refresh = refresh
