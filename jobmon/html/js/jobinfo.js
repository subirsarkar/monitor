var JobInfo = 
{
                   site: 'SITENAME',
           currentJobID: -1,
  AJAX_REQUEST_STIMEOUT: 20000,
  AJAX_REQUEST_LTIMEOUT: 60000,
              transport: null,
               colorMap: {
                    'Queued': '#aaa',
                   'Running': '#d54a17',
                      'Held': '#777',
                  'Finished': '#5b9c49',
                   'Unknown': '#f00'
               }
};
JobInfo.baseURL = function () {
  var url = location.protocol + '//' + location.host;
  return url;
};
//JobInfo.BASE_URL = JobInfo.baseURL() + '/cgi-bin/jobmon/' + JobInfo.site + '/monitor.cgi?';
JobInfo.BASE_URL = '/cgi-bin/jobmon/' + JobInfo.site + '/monitor.cgi?';
JobInfo.showError = function(message) {
  JobInfo.addText('logger-error', message);
  $('#tabpanel-b').tabs('option', 'selected', 1);
}
JobInfo.errorResponse = function (transport, status, errorThrown) {
  var message = 'Last ajax request failed, ' + 'status=' + status;
  if (status != 'timeout') message += "\nServer says:\n" + transport.responseText;
  JobInfo.showError(message);
};
JobInfo.valid = function (jid) {
  if (jid == null || isNaN(jid)) return false;
  return true;
}
JobInfo.requestAuthenticationInfo = function () {
  var url = JobInfo.BASE_URL + '&command=auth';
  JobInfo.setMessage(url, 'Authentication info');

  // Use cached info
  JobInfo.transport = $.ajax({
           url: url, 
          type: 'GET',
      datatype: 'text',
       timeout: JobInfo.AJAX_REQUEST_STIMEOUT,
       success: JobInfo.fillAuthenticationInfo,
         error: JobInfo.errorResponse
  });
};
JobInfo.fillAuthenticationInfo =  function (response, status) {
  try {
    $('#label-auth').html(response);
    $('#image-dn').attr('src', 'images/vote-user-green.gif');
    $('#label-auth').fadeIn(1000);

    JobInfo.requestLocalId();
  }
  catch (err) {
    JobInfo.showError('Error detail: ' + err.message);
  }
};
JobInfo.requestLocalId = function () {
  // required by the 'update' action
  var status = $('#td-status').html();

  if (status == 'Finished') {
    JobInfo.addText('logger-event', 'Job already finished!');
    return;
  }

  var gridid = $(document).getUrlParam('gridid');
  if (gridid == null || gridid.length == 0) {
    JobInfo.showError('Invalid gridid=' + gridid);
    return;
  }
  // First check if it is a Pilot job, then local id is available in GRID_ID
  var patt = /^(PILOTJOB|LOCALJOB|UNKNOJOB)/;
  if (gridid.match(patt) != null) {
    var fields = gridid.split('!');
    if (fields.length > 1)
      JobInfo.requestJobInfo(fields[1]); // extract local id
    return;
  }

  // Must ask the server for the local id
  patt = /^(https:|CREAM)/;
  if (gridid.match(patt) == null) {
    JobInfo.showError('Grid ID must begin with https:// or CREAM! gridid=' + gridid);
    return;
  }

  var url = JobInfo.BASE_URL + 'command=localid&jid=' + gridid;
  JobInfo.setMessage(url, 'LocalID from GridID');

  // Use cached info
  JobInfo.transport = $.ajax({
           url: url, 
         cache: false,
          type: 'GET',
      datatype: 'text',
       timeout: JobInfo.AJAX_REQUEST_STIMEOUT,
       success: JobInfo.fillLocalIdInfo,
         error: JobInfo.errorResponse
  });
};
JobInfo.fillLocalIdInfo = function (response, status) {
  if (!JobInfo.valid(response)) {
    JobInfo.showError('Invalid LocalID retrieved from the server: localid='+response);
    return;
  }
  JobInfo.requestJobInfo(response);
};
JobInfo.requestJobInfo = function (jobid) { 
  JobInfo.currentJobID = jobid;
  JobInfo.clearAllTextAreas();

  var url = JobInfo.BASE_URL + 'jid=' + JobInfo.currentJobID + '&command=summary'; 
  JobInfo.setMessage(url, 'summary info');

  JobInfo.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      datatype: 'xml',
       timeout: JobInfo.AJAX_REQUEST_STIMEOUT,
       success: JobInfo.fillJobInfo,
         error: JobInfo.errorResponse
  });
};
JobInfo.fillJobInfo = function (response, status) {
  try {
    var map = {
              'jid': 'td-jobid', 
           'status': 'td-status', 
             'user': 'td-user', 
            'queue': 'td-queue', 
            'qtime': 'td-submitted', 
            'start': 'td-started',
              'end': 'td-finished', 
            'ex_st': 'td-exitstatus', 
          'cputime': 'td-cputime', 
         'walltime': 'td-walltime', 
        'exec_host': 'td-exechost',
          'grid_id': 'td-gridid', 
             'ceid': 'td-ceid',
               'rb': 'td-rb', 
          'subject': 'td-subject', 
         'timeleft': 'td-timeleft', 
             'role': 'td-role', 
          'jobdesc': 'td-jobdesc'
    };
    var root = response.documentElement;
    for (var key in map) {
      var rows = root.getElementsByTagName(key);
      if (rows.length != 1) continue;
      var name = rows[0].childNodes[0].nodeValue;
      $('#' + map[key]).html(name);
    }

    var status = $('#td-status').html();
    if (status == '?') return;
    $('#td-status').css('color', JobInfo.colorMap[status]);

    // add rank and priority of queued jobs
    if (status == 'Queued') {
      var rank = -1;
      try {
        var rows = root.getElementsByTagName('rank');
        rank = rows[0].childNodes[0].nodeValue;
      }
      catch (e) {
        JobInfo.showError("fillJobInfo: Error for key=rank, detail: \n" + e.message); 
      }
      status += ' [R: ' + rank;    
      try {
        var rows = root.getElementsByTagName('priority');
        var p = rows[0].childNodes[0].nodeValue;
        status += ', P: ' + p;
      }
      catch (e) {
        // pass
      }
      status += ']';   
      $('#td-status').html(status);    
    }
    // fade out the admin table for local jobs
    var ceid = $('#td-ceid').html();
    if (ceid == '?')
      $('#table-admin').fadeTo('slow', 0.4);
    else
      $('#table-admin').fadeTo('fast', 1.0);
    
    // now the images
    $('img.canvas').each(function() {
      var width  = $(this).width();
      var height = $(this).height();

      // get width and height if tab is invisible
      if (width == 0) { width = $(this)[0].width; }
      if (height == 0) { height = $(this)[0].height; }

      width -= 1; height -= 1;

      var tag = $(this).attr('name');
      var url = JobInfo.BASE_URL + 'jid=' + JobInfo.currentJobID
                                    + '&command=' + tag 
                                    + '&width=' + width 
                                    + '&height=' + height;
      if (status == 'Running') url = JobInfo.addRandom(url);
      JobInfo.addText('logger-event', url);
      $(this).attr('src', url);
    });

    // ps, top etc. only for running jobs
    if ( (status == 'Running' || status == 'Unknown')) {
      JobInfo.activateDetailTabs(true);
      JobInfo.requestPsInfo();
    }
    else {
      JobInfo.activateDetailTabs(false);
    }
  }
  catch (err) {
    JobInfo.showError('Error detail: ' + err.message); 
  }
};
JobInfo.requestPsInfo = function () {
  var url = JobInfo.BASE_URL + 'jid=' + JobInfo.currentJobID + '&command=ps';
  JobInfo.setMessage(url, 'job ps info');

  JobInfo.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      datatype: 'text',
       timeout: JobInfo.AJAX_REQUEST_STIMEOUT,
       success: JobInfo.fillPsInfo,
         error: JobInfo.errorResponse
  });
};
JobInfo.fillPsInfo = function (response, status) {
  JobInfo.fillText('p-ps', response);

  // request the next one
  JobInfo.requestTopInfo();
};
JobInfo.requestTopInfo = function () {
  var url = JobInfo.BASE_URL + 'jid=' + JobInfo.currentJobID + '&command=top';
  JobInfo.setMessage(url, 'wn top info');

  JobInfo.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      datatype: 'text',
       timeout: JobInfo.AJAX_REQUEST_STIMEOUT,
       success: JobInfo.fillTopInfo,
         error: JobInfo.errorResponse
  });
};
JobInfo.fillTopInfo = function (response, status) {
  JobInfo.fillText('p-top', response);

  // Here goes Log and error info
  JobInfo.requestWorkdirListInfo();
};
JobInfo.requestWorkdirListInfo = function () {
  var url = JobInfo.BASE_URL + 'jid=' + JobInfo.currentJobID + '&command=workdir';
  JobInfo.setMessage(url, 'work dir info');

  JobInfo.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      datatype: 'text',
       timeout: JobInfo.AJAX_REQUEST_STIMEOUT,
       success: JobInfo.fillWorkdirListInfo,
         error: JobInfo.errorResponse
  });
};
JobInfo.fillWorkdirListInfo = function (response, status) {
  JobInfo.fillText('p-workdir', response);

  // Here goes Log and error info
  JobInfo.requestJobdirListInfo();
};
JobInfo.requestJobdirListInfo = function () {
  var url = JobInfo.BASE_URL + 'jid=' + JobInfo.currentJobID + '&command=jobdir';
  JobInfo.setMessage(url, 'job dir info');

  JobInfo.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      datatype: 'text',
       timeout: JobInfo.AJAX_REQUEST_STIMEOUT,
       success: JobInfo.fillJobdirListInfo,
         error: JobInfo.errorResponse
  });
};
JobInfo.fillJobdirListInfo = function (response, status) {
  JobInfo.fillText('p-jobdir', response);

  // Here goes Log and error info
  JobInfo.requestLogInfo();
};
JobInfo.requestLogInfo = function () {
  var url = JobInfo.BASE_URL + 'jid=' + JobInfo.currentJobID + '&command=log';
  JobInfo.setMessage(url, 'job log');

  JobInfo.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      datatype: 'text',
       timeout: JobInfo.AJAX_REQUEST_STIMEOUT,
       success: JobInfo.fillLogInfo,
         error: JobInfo.errorResponse
  });
};
JobInfo.fillLogInfo = function (response, status) {
  JobInfo.fillText('p-log', response);

  // Finally the error info
  JobInfo.requestErrorInfo();
};
JobInfo.requestErrorInfo = function () {
  var url = JobInfo.BASE_URL + 'jid=' + JobInfo.currentJobID  + '&command=error';
  JobInfo.setMessage(url, 'job error log');

  JobInfo.transport = $.ajax({
          url: url,
        cache: false,
      timeout: JobInfo.AJAX_REQUEST_STIMEOUT,
         type: 'GET',
     datatype: 'text',
      success: JobInfo.fillErrorInfo,
        error: JobInfo.errorResponse
  });
};
JobInfo.fillErrorInfo = function (response, status) {
  JobInfo.fillText('p-error', response);
};
JobInfo.fillText = function (id, text) {
  if ($.browser.msie) {
    lines = text.split("\n");
    text = '';
    jQuery.each(lines, function() {
      text += this + '<br/>';
    });
    $('#' + id).html('<pre>'+text+'</pre>');
  }
  else 
    $('#' + id).html(text);
};
JobInfo.clearLogger = function() {
  $('textarea.fg-logger').val('');
};
JobInfo.addText = function(id, text) {
  var val = $('#' + id).val();
  if (val == null) return;
  val += ((val != '') ? "\n" : '') + (new Date()) + " >>> " + text;
  $('#' + id).val(val);
};
JobInfo.addRandom = function (url) {
  return (url + '&t='+Math.random());
};
JobInfo.setMessage = function (url, message) {
  JobInfo.addText('logger-event', url);
  $('#label-datatype').html('Loading ' + message);
};
JobInfo.clearAllTextAreas = function() {
  $('p.fg-infoarea').html('');
};
JobInfo.activateDetailTabs = function (active) {
  (active) 
    ? $('#tabpanel-a').data('disabled.tabs', [])
    : $('#tabpanel-a').data('disabled.tabs', [1, 2, 3, 4, 5, 6]);
}
// input field's event handlers 
// wait till the DOM is loaded
$(document).ready(function() {
  $('img.wlabel').css('margin-bottom', '-2px');

  $('#tabpanel-a').tabs();
  JobInfo.activateDetailTabs(false);
  $('#tabpanel-b').tabs();

  $('a.tips').cluetip({
            width: '350px', 
           sticky: true, 
    closePosition: 'title', 
           arrows: true, 
        showTitle: true
  });
  $('input:submit[value=Update]').click(JobInfo.requestLocalId);

  // style buttons
  $('body').css('font-size','0.65em');
  $('body,div,span,a,p,label,fieldset,select,input,checkbox,radiobutton,button,textarea')
      .addClass('ui-widget')
      .css('font-weight', 'normal');
  $('fieldset,select,textarea').addClass('ui-widget-content');
  $('div,fieldset').addClass('ui-corner-all');
  $('input,checkbox,radiobutton,button')
      .addClass('ui-widget-content')
      .addClass('ui-state-default');
  $('textarea').addClass('fg-logger');
  $('textarea#logger-error').css('color','red');
  $('p').addClass('fg-infoarea').css('height', '455px');
  $('div.panel-header').addClass('ui-widget-header');
  $('#tabpanel-a,#tabpanel-b').css('border','1px solid #aed0ea');

  // buttons
  $('input:submit').mouseover(function() {
    $(this).removeClass('ui-state-default').addClass('ui-state-focus');
  }).mouseout(function() {
    $(this).removeClass('ui-state-focus').addClass('ui-state-default');
  });
  $('input:submit')
    .addClass('ui-corner-all')
    .addClass('fg-button');

  $('#label-auth').hide();
  $('#panel-progress').hide();

  // Set label color
  $('#panel-auth label').css('color', '#2779aa');
  $('#panel-progress label').css('color', '#2779aa');

  // show/hide the progress panel as soon as ajax request starts/returns
  $(document).ajaxStart(function() {
    $('#panel-progress').fadeIn(1000);
    $('input:submit[value=Update]').attr('disabled', true);
  });
  $(document).ajaxStop(function() {
    $('#panel-progress').fadeOut(1000);
    $('input:submit[value=Update]').attr('disabled', false);
  });

  JobInfo.clearLogger();

  // If mozilla set vertical-align for the labels
  // seems also to depend on the OS :-(
  if ($.browser.mozilla) {
    var p = (navigator.platform == 'Win32') ? '2px' : '2px';
    $('label').css('vertical-align', p);
  }
  // For IE7 use 'collapse' as the border-collapse property; default: 'separate'
  if ($.browser.msie) {
    $('table').css('border-collapse','collapse').css('border-spacing','0px');
    $('td').css('border-width','1px');
  }
  if ($.browser.opera) {
    $('#img-loading').css('margin-bottom', '-2px');
  }

  setTimeout('JobInfo.requestAuthenticationInfo()', 100); // millisec
});
