(function() {
  var Store;
  Store = {};
  Store.get = function(key) {
    if (localStorage[key] != null) {
      return $.parseJSON(localStorage[key]);
    } else {
      return null;
    }
  };
  Store.set = function(key, val) {
    return localStorage[key] = $.toJSON(val);
  };
  Store.setDefault = function(key, val) {
    if (!Store.get(key, val)) {
      return Store.set(key, val);
    }
  };
  window.Store = Store;
}).call(this);
