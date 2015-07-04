var Monitor =
{
               fname: undefined,
             rrdData: undefined,
             lastSrc: undefined,
           gtype_DSs: new Object(),
       gtype_formats: new Object(),
  autoUpdateInterval: 600000,  // in milliseconds
   autoUpdateTimerID: null
};
Monitor.baseURL = function () {
  var url = location.protocol + '//' + location.host;
  return url;
};
Monitor.BASE_URL = Monitor.baseURL() + '/cms/LCG/crab/server';
Monitor.gtype_DSs = {
     'jobs': new Array(
              'created',
              'not_handled',
              'handled',
              'failed',
              'output_requested',
              'in_progress')
};
Monitor.gtype_formats = {
  'jobs': {
              'created': { checked: true, lines: { show: true, fill: false} },
          'not_handled': { checked: true },
              'handled': { checked: true },
               'failed': { checked: true },
     'output_requested': { checked: true },
          'in_progress': { checked: true }
  }
};
Monitor.addRandom = function (url) 
{
  return (url + '?t='+Math.random());
};
Monitor.startAutoUpdate = function() 
{
  Monitor.autoUpdateTimerID 
    = setInterval('Monitor.fetchRRD()', Monitor.autoUpdateInterval);
};
Monitor.stopAutoUpdate = function() 
{
  if (Monitor.autoUpdateTimerID != null) {
    clearInterval(Monitor.autoUpdateTimerID); 
    Monitor.autoUpdateTimerID = null;
  }
};
Monitor.toggleAutoUpdate = function() 
{
  ($('#check-autoupdate').attr('checked')) ? Monitor.startAutoUpdate()
                                           : Monitor.stopAutoUpdate(); 
};
Monitor.showGraph = function ()
{
  var type = Monitor.getSelectedValue('select-plottype');
  var data = new RRDFilterDS(Monitor.rrdData, Monitor.gtype_DSs[type]);

  // the rrdFlot object creates and handles the graph
  var f = new rrdFlot('canvas', data, null, Monitor.gtype_formats[type]);
}
Monitor.rrdHandler = function(bf) 
{
  var data;
  try {
    data = new RRDFile(bf);            
  } 
  catch(err) {
    alert("File " + Monitor.fname + " is not a valid RRD archive!\n Error: " + err);
  }
  if (data == undefined) {
    alert('Invalid data returned for RRD archive, file: ' + Monitor.fname);
    return;
  }

  Monitor.rrdData = data;
  Monitor.showGraph();

  // re-install autoupdate
  if ($('#check-autoupdate').attr('checked')) Monitor.startAutoUpdate()
};

// this function is invoked when the RRD file name changes
Monitor.fetchRRD = function() 
{
  // Irrespective of conitions uninstall AutoUpdate
  Monitor.stopAutoUpdate();

  var srv = Monitor.getSelectedValue('select-server');
  Monitor.fname = Monitor.BASE_URL + '/rrd/' + srv + '.rrd';
  try {
    FetchBinaryURLAsync(Monitor.addRandom(Monitor.fname), Monitor.rrdHandler);
  } 
  catch (err) {
    alert("Failed loading " + Monitor.fname + "\n" + err);
  }
};
Monitor.getSelectedValue = function (id) 
{
  return $('#' + id + ' option:selected').val();
}
Monitor.clearSelectBox = function (id) 
{
  $('#' + id + ' option').each(function() {
    $(this).remove();
  });
};
Monitor.fillGraphType = function(pclass) 
{
  Monitor.clearSelectBox('select-plottype');

  var obj = $('#select-graphtype').get(0);

  var list = new Array();
  jQuery.each(items, function() {
    list.push(this);
  });
  // check if an extra argument was passed, if so append to 'items'
  var args = arguments[1];
  if (args != null && args.length > 0) list.push(args);

  jQuery.each(list, function() {
    var name = this;     
    var option = new Option(name, name);
    option.title = name;
    try {
      obj.add(option, null);
    }
    catch (e) {
      obj.add(option, -1);
    }
  });
}
Monitor.fillServerList = function() 
{
  Monitor.clearSelectBox('select-server');

  var url = Monitor.BASE_URL + '/rrd/server.json';
  jQuery.getJSON(Monitor.addRandom(url), function(data) {
    var obj = $('#select-server').get(0);
    var items = data.items;
    jQuery.each(items, function() {
      var name = this;     
      var option = new Option(name, name);
      option.title = name;
      try {
        obj.add(option, null);
      }
      catch (e) {
        obj.add(option, -1);
      }
    });
    Monitor.lastSrc = Monitor.getSelectedValue('select-server');
    setTimeout('Monitor.fetchRRD()', 50); // millisec
  });
};
Monitor.fillOptions = function() 
{
  // Server List
  Monitor.fillServerList();
};
Monitor.adjustGraphType = function()
{
  var pclass = $('input:radio[name=pclass]:checked').val();
  if (pclass != 'pool') return;

  var src = Monitor.getSelectedValue('select-server');
  if (src.indexOf('dcache') > -1 && Monitor.lastSrc.indexOf('dcache') > -1) return;

  var name = (src != 'global') ? 'cost' : undefined;
  Monitor.fillGraphType(pclass, name);
  Monitor.lastSrc = src;
}
// input field's event handlers
// wait till the DOM is loaded
$(document).ready(function() 
{
  // UI Customization
  $('body').css('font-size','0.75em');
  $('body,div,span,a,p,label,select,input,checkbox,radiobutton,button,textarea')
      .addClass('ui-widget');
  $('textarea,fieldset,p').addClass('ui-widget-content');
  $('div,fieldset').addClass('ui-corner-all');

  $('div.content-panel').css('width', '780px')
     .addClass('ui-widget-content')
     .addClass('ui-default-state');
  $('div.header-panel').css('width', '780px')
     .addClass('ui-widget-content')
     .addClass('ui-widget-header');
  $('div.content-panel').css('border','1px solid #aed0ea');

  $('select').css('width', '120px');
  $('select#select-server').css('width', '160px');

  // Buttons
  $('input:submit[value=Show]').click(Monitor.fetchRRD);

  // Radio buttons
  $('input:radio[name=pclass]').click(function() {
    setTimeout('Monitor.fillOptions()', 50); // millisec
  });

  // Checkbox
  $('#check-autoupdate').click(Monitor.toggleAutoUpdate);

  // show/hide the progress panel as soon as ajax request starts/returns
  $().ajaxStart(function() {
    $('#control').unblock({fadeOut:0}).block({
      message: 'Loading Pool List, please wait ...',
      overlayCSS: {
        backgroundColor: '#000',
                opacity: '0.025'
      }
    });
  });
  $().ajaxStop(function() {
    $('#control').unblock({fadeOut: 0});
  });
  setTimeout('Monitor.fillOptions()', 100); // millisec
});
