(function() {
  var save;
  save = function() {
    var val;
    val = parseInt($('#updateInterval').val());
    if (val > 0) {
      return Store.set('updateInterval', parseInt(val * 60 * 1000));
    }
  };
  $(function() {
    var saveLoop, saveTimer, saving;
    $('#updateInterval').val(Store.get('updateInterval') / 60 / 1000);
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
    $("#updateInterval").focus(function() {
      saving = true;
      return saveLoop();
    });
    return $("#updateInterval").blur(function() {
      save();
      return saving = false;
    });
  });
}).call(this);
