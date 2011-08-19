(function() {
  var save;
  save = function() {
    var maxTabs, updateInterval;
    updateInterval = parseInt($('#updateInterval').val());
    maxTabs = parseInt($('#maxTabs').val());
    if (updateInterval > 0) {
      Store.set('updateInterval', updateInterval * 60 * 1000);
    }
    if (maxTabs > 0) {
      return Store.set('maxTabs', maxTabs);
    }
  };
  $(function() {
    var blurred, focused, saveLoop, saveTimer, saving;
    $('#updateInterval').val(Store.get('updateInterval') / 60 / 1000);
    $('#maxTabs').val(Store.get('maxTabs'));
    saveTimer = null;
    saving = false;
    saveLoop = function() {
      if (!saving) {
        return;
      }
      clearTimeout(saveTimer);
      save();
      return saveTimer = setTimeout(save, 300);
    };
    focused = function() {
      saving = true;
      return saveLoop();
    };
    blurred = function() {
      save();
      return saving = false;
    };
    $("#updateInterval").focus(focused);
    $("#maxTabs").focus(focused);
    $("#updateInterval").blur(blurred);
    return $("#maxTabs").blur(blurred);
  });
}).call(this);
