(function() {
  var Store;
  Store = {};
  Store.get = function(key) {
    return (localStorage[key] != null) && $.parseJSON(localStorage[key]);
  };
  Store.set = function(key, val) {
    return localStorage[key] = $.toJSON(val);
  };
  Store.setDefault = function(key, val) {
    if (Store.get(key, val) == null) {
      return Store.set(key, val);
    }
  };
  window.Store = Store;
}).call(this);
