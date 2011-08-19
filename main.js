(function() {
  var checkLoginStatus, currentIcon, deleteMessages, displayError, folderId, getDeviations, loading, loadingIconSeq, loggedIn, maxMessages, n, newMessages, originalIcon, refresh, refreshTimer, rotateIcon, setIcon, setLoggedIn, setLoggedOut, updateDisplay, updateFolderId, waitForLoaded;
  folderId = null;
  loggedIn = false;
  loading = false;
  newMessages = [];
  originalIcon = "icons/icon.png";
  loadingIconSeq = (function() {
    var _results;
    _results = [];
    for (n = 0; n <= 7; n++) {
      _results.push("icons/ajax-loader-" + n + ".png");
    }
    return _results;
  })();
  currentIcon = originalIcon;
  setIcon = function(path) {
    currentIcon = path;
    return chrome.browserAction.setIcon({
      path: path
    });
  };
  rotateIcon = function() {
    var icon;
    if (!loading) {
      return;
    }
    icon = loadingIconSeq[loadingIconSeq.indexOf(currentIcon) + 1];
    if (!(icon != null)) {
      icon = loadingIconSeq[0];
    }
    setIcon(icon);
    return setTimeout(rotateIcon, 100);
  };
  $(document).ajaxStart(function() {
    console.log("Ajax start!");
    loading = true;
    chrome.browserAction.setBadgeText({
      text: ''
    });
    return rotateIcon();
  });
  $(document).ajaxStop(function() {
    console.log("Ajax stop!");
    loading = false;
    return setIcon(originalIcon);
  });
  $(document).ajaxError(function(event) {
    console.log("Ajax error!");
    console.log(event);
    loading = false;
    setIcon(originalIcon);
    return displayError("Error connecting to deviantART!");
  });
  updateFolderId = function(callback) {
    console.log("Updating folder ID...");
    return $.get("http://my.deviantart.com/messages/#view=deviations", function(data) {
      var match;
      match = data.match(/aggid.+?(\d+)/);
      if (!(match != null)) {
        if (data.match(/Deviant Login/)) {
          return setLoggedOut();
        } else {
          console.log(data);
          return displayError("Unable to find deviantWATCH folder ID.");
        }
      } else {
        folderId = match[1];
        console.log("Folder ID updated!");
        if (callback != null) {
          return callback(folderId);
        }
      }
    });
  };
  deleteMessages = function(msgIds, callback) {
    return chrome.cookies.get({
      url: "http://my.deviantart.com/",
      name: "userinfo"
    }, function(cookie) {
      var call, data, msgId;
      call = '"MessageCenter","trash_messages",';
      call += ((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = msgIds.length; _i < _len; _i++) {
          msgId = msgIds[_i];
          _results.push("[" + folderId + ",\"id:devwatch:" + msgId + "\"]");
        }
        return _results;
      })()).join();
      data = {
        ui: decodeURIComponent(cookie.value),
        "c[]": call,
        t: 'json'
      };
      console.log("Deleting messages...");
      return $.post("http://my.deviantart.com/global/difi/?", data, function(resp) {
        if (callback != null) {
          return callback();
        }
      });
    });
  };
  displayError = function(err) {
    console.log(err);
    chrome.browserAction.setBadgeText({
      text: 'err'
    });
    return chrome.browserAction.setTitle({
      title: err
    });
  };
  maxMessages = 101;
  getDeviations = function(callback) {
    var hits, message_url;
    message_url = 'http://my.deviantart.com/global/difi/?' + encodeURI('c[]="MessageCenter","get_views",[' + folderId + ',"oq:devwatch:0:' + maxMessages + ':f:tg=deviations"]') + '&t=json';
    hits = [];
    console.log("Retrieving deviations...");
    return $.get(message_url, function(data) {
      var obj;
      window.data = data;
      obj = JSON.parse(data);
      if (obj.DiFi.status === "FAIL") {
        return setLoggedOut();
      } else {
        try {
          obj.DiFi.response.calls[0].response.content[0].result.hits.forEach(function(hit) {
            return hits.push(hit);
          });
        } catch (err) {
          console.log(err);
          displayError("Error parsing response from deviantART.");
        }
        console.log("Deviations retrieved!");
        return callback(hits);
      }
    });
  };
  updateDisplay = function() {
    var num, numDesc;
    if (newMessages.length === 0) {
      chrome.browserAction.setBadgeText({
        text: ""
      });
      return chrome.browserAction.setTitle({
        title: "No new deviations"
      });
    } else {
      num = newMessages.length;
      numDesc = num === maxMessages ? ">" + (num - 1) : "" + num;
      chrome.browserAction.setBadgeText({
        text: numDesc
      });
      return chrome.browserAction.setTitle({
        title: "" + numDesc + " new deviation" + (num > 1 ? 's' : '')
      });
    }
  };
  refreshTimer = null;
  refresh = function() {
    var fetch;
    if (refreshTimer != null) {
      clearTimeout(refreshTimer);
    }
    if (loggedIn) {
      fetch = function() {
        return getDeviations(function(hits) {
          newMessages = hits;
          return updateDisplay();
        });
      };
      if (!(folderId != null)) {
        updateFolderId(fetch);
      } else {
        fetch();
      }
    } else {
      checkLoginStatus();
    }
    return refreshTimer = setTimeout(refresh, Store.get('updateInterval'));
  };
  chrome.browserAction.onClicked.addListener(function(tab) {
    var max, message, _i, _len, _ref;
    if (loading) {
      console.log("Loading...");
    } else if (!loggedIn) {
      return chrome.tabs.create({
        url: "http://www.deviantart.com/users/login"
      });
    } else if (newMessages.length === 0) {
      return refresh();
    } else {
      max = Store.get('maxTabs');
      _ref = newMessages.slice(0, (max + 1) || 9e9);
      for (_i = 0, _len = _ref.length; _i < _len; _i++) {
        message = _ref[_i];
        chrome.tabs.create({
          url: message.url
        });
      }
      deleteMessages((function() {
        var _j, _len2, _ref2, _results;
        _ref2 = newMessages.slice(0, (max + 1) || 9e9);
        _results = [];
        for (_j = 0, _len2 = _ref2.length; _j < _len2; _j++) {
          message = _ref2[_j];
          _results.push(message.msgid);
        }
        return _results;
      })(), refresh);
      return newMessages = newMessages.slice(max);
    }
  });
  waitForLoaded = function(tabId, callback) {
    var repeater, timer;
    timer = null;
    repeater = function() {
      return chrome.tabs.get(tabId, function(tab) {
        if (tab.status === 'complete') {
          clearTimeout(timer);
          return callback();
        } else {
          return timer = setTimeout(repeater, 500);
        }
      });
    };
    return repeater();
  };
  /*
  chrome.tabs.onUpdated.addListener (tabId, changeInfo, tab) ->
    console.log("From: '#{tab.url}' to '#{changeInfo.url}'")
    if needLogin and tab.url.match(/deviantart.com\/($|\?loggedin)/)
      console.log("Logged in? :D")
      needLogin = false
      waitForLoaded(tab.id, refresh)
    else if tab.url.match(/deviantart.+?rockedout/)
      console.log("Logged out? :(")
      waitForLoaded(tab.id, refresh)
  */
  setLoggedOut = function() {
    console.log("Login required!");
    loggedIn = false;
    folderId = null;
    chrome.browserAction.setBadgeText({
      text: "login"
    });
    return chrome.browserAction.setTitle({
      title: "Please log in to deviantART."
    });
  };
  setLoggedIn = function() {
    folderId = null;
    loggedIn = true;
    return refresh();
  };
  checkLoginStatus = function() {
    return chrome.cookies.get({
      url: "http://my.deviantart.com/",
      name: "userinfo"
    }, function(cookie) {
      var ui;
      ui = $.parseJSON(decodeURIComponent(cookie.value).split(";")[1]);
      if (ui.username === "" && loggedIn) {
        return setLoggedOut();
      } else if (ui.username !== "" && !loggedIn) {
        return setLoggedIn();
      }
    });
  };
  chrome.cookies.onChanged.addListener(function(changeInfo) {
    if (changeInfo.cookie.domain === ".deviantart.com" && changeInfo.cookie.name === "userinfo") {
      return checkLoginStatus();
    }
  });
  Store.setDefault('updateInterval', 10 * 60 * 1000);
  Store.setDefault('maxTabs', 20);
  setLoggedOut();
  checkLoginStatus();
  window.refresh = refresh;
}).call(this);
