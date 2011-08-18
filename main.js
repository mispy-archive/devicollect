(function() {
  var currentIcon, deleteMessages, displayError, folderId, getDeviations, loading, loadingIconSeq, n, needLogin, newMessages, originalIcon, refresh, refreshTimer, rotateIcon, setIcon, setLoginRequired, updateDisplay, updateFolderId, waitForLoaded;
  var __indexOf = Array.prototype.indexOf || function(item) {
    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === item) return i;
    }
    return -1;
  };
  folderId = null;
  needLogin = false;
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
    return setIcon(originalIcon);
  });
  setLoginRequired = function() {
    console.log("Login required!");
    needLogin = true;
    chrome.browserAction.setBadgeText({
      text: "login"
    });
    return chrome.browserAction.setTitle({
      title: "Please log in to deviantART."
    });
  };
  updateFolderId = function(callback) {
    console.log("Updating folder ID...");
    return $.get("http://my.deviantart.com/messages/#view=deviations", function(data) {
      var match;
      match = data.match(/aggid.+?(\d+)/);
      if (!(match != null)) {
        if (data.match(/Deviant Login/)) {
          return setLoginRequired();
        } else {
          return displayError("Error loading deviantART!");
        }
      } else {
        folderId = match[1];
        console.log("Folder ID updated!");
        if (callback != null) {
          return callback(folderId);
        }
      }
    }).error(function(event) {
      return setLoginRequired();
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
        console.log(resp);
        if (callback != null) {
          return callback();
        }
      });
    });
  };
  displayError = function(err) {
    chrome.browserAction.setBadgeText({
      text: 'err'
    });
    chrome.browserAction.setTitle({
      title: err
    });
    return console.log(err);
  };
  getDeviations = function(callback) {
    var hits, message_url;
    message_url = "http://my.deviantart.com/global/difi/?c%5B%5D=%22MessageCenter%22%2C%22get_views%22%2C%5B" + folderId + "%2C%22oq%3Adevwatch%3A0%3A48%3Af%3Atg%3Ddeviations%22%5D&t=json";
    hits = [];
    console.log("Retrieving deviations...");
    return $.get(message_url, function(data) {
      var obj;
      window.data = data;
      obj = JSON.parse(data);
      if (obj.DiFi.status === "FAIL") {
        return setLoginRequired();
      } else {
        obj.DiFi.response.calls[0].response.content[0].result.hits.forEach(function(hit) {
          return hits.push(hit);
        });
        console.log("Deviations retrieved!");
        return callback(hits);
      }
    });
  };
  updateDisplay = function() {
    var num;
    if (newMessages.length === 0) {
      chrome.browserAction.setBadgeText({
        text: ""
      });
      return chrome.browserAction.setTitle({
        title: "No new deviations"
      });
    } else {
      num = newMessages.length;
      chrome.browserAction.setBadgeText({
        text: num.toString()
      });
      return chrome.browserAction.setTitle({
        title: "" + num + " new deviation" + (num > 1 ? 's' : '')
      });
    }
  };
  refreshTimer = null;
  refresh = function() {
    var fetch;
    if (refreshTimer != null) {
      clearTimeout(refreshTimer);
    }
    fetch = function() {
      return getDeviations(function(hits) {
        var extantIds, hit, message, _i, _j, _len, _len2, _ref;
        for (_i = 0, _len = newMessages.length; _i < _len; _i++) {
          message = newMessages[_i];
          extantIds = message.msgid;
        }
        for (_j = 0, _len2 = hits.length; _j < _len2; _j++) {
          hit = hits[_j];
          if (_ref = hit.msgid, __indexOf.call(extantIds, _ref) < 0) {
            newMessages.push(hit);
          }
        }
        return updateDisplay();
      });
    };
    if (!(folderId != null)) {
      updateFolderId(fetch);
    } else {
      fetch();
    }
    return refreshTimer = setTimeout(refresh, Store.get('updateInterval'));
  };
  chrome.browserAction.onClicked.addListener(function(tab) {
    var message, _i, _len;
    if (loading) {
      console.log("Loading...");
    } else if (needLogin) {
      return chrome.tabs.create({
        url: "http://www.deviantart.com/users/login"
      });
    } else if (newMessages.length === 0) {
      return refresh();
    } else {
      for (_i = 0, _len = newMessages.length; _i < _len; _i++) {
        message = newMessages[_i];
        chrome.tabs.create({
          url: message.url
        });
      }
      deleteMessages((function() {
        var _j, _len2, _results;
        _results = [];
        for (_j = 0, _len2 = newMessages.length; _j < _len2; _j++) {
          message = newMessages[_j];
          _results.push(message.msgid);
        }
        return _results;
      })());
      newMessages = [];
      return updateDisplay();
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
  chrome.tabs.onUpdated.addListener(function(tabId, changeInfo, tab) {
    if (needLogin && tab.url.match(/deviantart.com\/($|\?loggedin)/)) {
      console.log("Logged in? :D");
      needLogin = false;
      return waitForLoaded(tab.id, refresh);
    } else if (tab.url.match(/deviantart.+?rockedout/)) {
      console.log("Logged out? :(");
      return waitForLoaded(tab.id, refresh);
    }
  });
  Store.setDefault('updateInterval', 10 * 60 * 1000);
  refresh();
  window.refresh = refresh;
}).call(this);
