var JobMonitor = 
{
                   site: 'SITENAME',
           currentJobID: -1,
       currentJobStatus: 'UNKNOWN',
            diagnosisOn: false,
     autoUpdateInterval: 600000,  // in milliseconds
      autoUpdateTimerID: null,
  AJAX_REQUEST_STIMEOUT: 20000,
  AJAX_REQUEST_LTIMEOUT: 60000,
              SIX_HOURS: 6 * 60 * 60 * 1000, // in milliseconds
              transport: null,
              paramRead: false,
                 fsDict: {
                   'localid': 'medium',
                    'gridid': 'x-small',
                   'subject': 'x-small',
                   'default': 'medium'
                 },
               colorMap: {
                    'Queued': '#aaa',
                   'Running': '#d54a17',
                      'Held': '#777',
                  'Finished': '#5b9c49',
                   'Unknown': '#f00'
               },
                  tdmap: {
                       'td-subject': 1,
                         'td-queue': 2,
                          'td-user': 3,
                            'td-rb': 4,
                          'td-ceid': 6,
                      'td-exechost': 7,
                     'td-submitted': 8,
                       'td-started': 9,
                    'td-exitstatus':10
                  }
};
JobMonitor.baseURL = function () {
  var url = location.protocol + '//' + location.host;
  return url;
};
JobMonitor.BASE_URL = '/cgi-bin/jobmon/' + JobMonitor.site + '/monitor.cgi?';
JobMonitor.startAutoUpdate = function() {
  JobMonitor.autoUpdateTimerID 
    = setInterval('JobMonitor.jobInfo()', JobMonitor.autoUpdateInterval);
};
JobMonitor.toggleAutoUpdate = function() {
  ($('#check-autoupdate').attr('checked')) ? JobMonitor.startAutoUpdate()
                                           : JobMonitor.stopAutoUpdate(); 
};
JobMonitor.stopAutoUpdate = function() {
  if (JobMonitor.autoUpdateTimerID != null) {
    clearInterval(JobMonitor.autoUpdateTimerID); 
    JobMonitor.autoUpdateTimerID = null;
  }
};
JobMonitor.errorResponse = function (transport, status, errorThrown) {
  var message = 'Last Ajax request failed, ' + 'status=' + status;
  if (status != 'timeout') message += "\nServer says:\n" + transport.responseText;
  JobMonitor.addError(message);
};
JobMonitor.valid = function (jid) {
  if (jid == null || isNaN(jid)) return false;
  return true;
}
JobMonitor.timeWindow = function(jobstate) {
  // Choose completed jobs within a time window 
  var query = '';
  if (jobstate == 'completed' || jobstate == 'unknown') {
    // Check that the text areas are filled with range
    var f = $('#input-from');
    var t = $('#input-to');
    if (f.val() != '' && t.val() != '') 
      query = '&from=' + f.val() + '&to=' + t.val();
  }
  return query;
} 
JobMonitor.requestAuthenticationInfo = function () {
  var url = JobMonitor.BASE_URL + '&command=auth';
  JobMonitor.setMessage(url, 'Authentication info');

  // Use cached info
  JobMonitor.transport = $.ajax({
           url: url, 
          type: 'GET',
      dataType: 'text',
       timeout: JobMonitor.AJAX_REQUEST_STIMEOUT,
       success: JobMonitor.fillAuthenticationInfo,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillAuthenticationInfo =  function (response, status) {
  try {
    if ($('#check-debug').attr('checked')) JobMonitor.addText('logger-debug', response);
    $('#label-auth').html(response);
    $('#image-dn').attr('src', 'images/vote-user-green.gif');
    $('#label-auth').fadeIn(1000);

    JobMonitor.requestUserSummary();
  }
  catch (err) {
    JobMonitor.addError('fillAuthenticationInfo: Error detail: ' + err.message);
  }
};
JobMonitor.prepareStatement = function () {
  // State of the job (Running, Queued etc.)
  var jobstate = JobMonitor.getJobState() || 'running';

  var query = '&jobstate=' + jobstate 
                           + JobMonitor.timeWindow(jobstate);

  // Any filter (Queue, WN, Subject etc.) specified?
  var filter = JobMonitor.getFilter();
  if (filter != '?') query += '&filter='+filter;

  // By default only jobs from _this user_ (DN) shown
  // optionally, show jobs from the VO(s) the DN belongs to
  if (! $('#check-myjobs').attr('checked')) query += '&myjobs=true';

  if (JobMonitor.diagnosisOn) {
    var value = $('#select-diagnose').val();
    if (value != null) {
      query += '&diagnose=' + value;
    }
  }
  return query;
}
JobMonitor.requestUserSummary = function () {
  var query = JobMonitor.prepareStatement();

  // Now build the request URL and go
  var url = JobMonitor.BASE_URL + 'command=userview' + query; 

  JobMonitor.setMessage(url, 'User Summary table');
  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'html',
       timeout: JobMonitor.AJAX_REQUEST_LTIMEOUT,
       success: JobMonitor.fillUserSummary,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillUserSummary = function(response, status) {
  try {
    if ($('#check-logdebug').attr('checked')) 
      JobMonitor.addText('logger-debug', response);
    
    $('div#summary-panel').empty();
    var table = $('<table id="summary-view"></table>')
                  .html(response);
    $('div#summary-panel').append(table).css('overflow','auto');

    // enable sorting 
    $('table#summary-view')
      .addClass('sortable')
      .css('width', '100%');
    var id = $('#summary-view').get(0);
    sorttable.makeSortable(id);
    
    $('table#summary-view thead th, table#summary-view tfoot th')
      .css('color', '#ffffff')
      .css('background-color', '#7e98af');
    $('table#summary-view tbody tr:odd').css('background-color', '#f7f7f7');
      
    // add a custom quick-search to the summary table
    $('input#id_search').quicksearch('table#summary-view tbody tr',
    {
            delay: 100,
       stripeRows: ['odd', 'even'],
         'loader': 'span.loading'
    });
    $('input#id_search')
      .addClass('ui-widget-content')
      .css('padding','.2em');

    // clicking the jobid will now show the detail
    $('table#summary-view tbody tr').each(function() {
      var list = $(this).children('td');
      $(list).eq(0).css('text-align', 'left').dblclick(function() {
        $('#tabpanel-a').tabs('option', 'selected', 1);
        var gridid = $(this).html();
        var indx = gridid.indexOf('CREAM');
        var fields = gridid.split('!');
        if (fields.length > 1 || indx == 0) {
          var jid = (indx == 0) ? fields[0] : fields[1];
          JobMonitor.requestJobInfo(jid);
        } 
        else {
          JobMonitor.requestLocalId('https://' + gridid); 
        }
        JobMonitor.findItem('select-jid', gridid);
      });
    });

    // send the next request
    JobMonitor.requestJobidList();
  }
  catch (err) {
    JobMonitor.addError('fillUserSummary: Error detail: ' + err.message); 
  }
};
JobMonitor.requestJobidList = function () {
  var query = JobMonitor.prepareStatement();
  if (JobMonitor.diagnosisOn) JobMonitor.diagnosisOn = false;

  // Now build the request URL and go
  var url = JobMonitor.BASE_URL + 'command=list' + query; 

  JobMonitor.setMessage(url, 'job list');
  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'json',
       timeout: JobMonitor.AJAX_REQUEST_LTIMEOUT,
       success: JobMonitor.fillJobidListJSON,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillJobidListJSON = function(response, status) {
  try {
    if ($('#check-logdebug').attr('checked')) 
      JobMonitor.addText('logger-debug', response);
    var rows = response.jids;
    var res = JobMonitor.fillSelectBoxJSON(rows, 'select-jid', 0);
    $('#label-entries').html(rows.length + ' Entries');
    $('#div-entry').fadeIn(3000);

    if (res) JobMonitor.jobInfo();
  }
  catch (err) {
    JobMonitor.addError('fillJobidListJSON: Error detail: ' + err.message); 
  }
};
JobMonitor.requestTagList = function () {
  var tagname = $('#select-filter').val().toLowerCase();
  if (tagname == 'all') {
    JobMonitor.clearSelectBox('select-tag');
    JobMonitor.requestUserSummary(); 
    return;
  }
  var jobstate = JobMonitor.getJobState() || 'running';

  var url = JobMonitor.BASE_URL + 'command=tag'
                                + '&tagname=' + tagname 
                                + '&jobstate=' + jobstate 
                                + JobMonitor.timeWindow(jobstate);
  JobMonitor.setMessage(url, 'values for: ' + tagname);

  JobMonitor.transport = $.ajax({
           url: url, 
         cache: false,
          type: 'GET',
         async: false,
      dataType: 'xml',
       timeout: JobMonitor.AJAX_REQUEST_LTIMEOUT,
       success: JobMonitor.fillTagList,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillTagList = function (response, status) {
  try {
    if ($('#check-logdebug').attr('checked')) JobMonitor.addText('logger-debug', response);
    var root = response.documentElement;
    var rows = root.getElementsByTagName('tag');
    
    JobMonitor.fillSelectBox(rows, 'select-tag', -1);
  }
  catch (err) {
    JobMonitor.addError('fillTagList: Error detail: ' + err.message); 
  }
};
JobMonitor.requestAllTagValues = function () {
  var jobstate = JobMonitor.getJobState() || 'running';

  var url = JobMonitor.BASE_URL + 'command=alltags&jobstate=' + jobstate
                                + JobMonitor.timeWindow(jobstate);
  JobMonitor.setMessage(url, 'all selection tag values');

  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'xml',
       timeout: JobMonitor.AJAX_REQUEST_LTIMEOUT,
       success: JobMonitor.fillAllTags,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillAllTags = function (response, status) {
  try {
    if ($('#check-logdebug').attr('checked')) 
      JobMonitor.addText('logger-debug', response);
    var map = {
           'queue': 'select-queue',
            'ceid': 'select-ce',
              'rb': 'select-rb',
       'exec_host': 'select-wn',
         'subject': 'select-subject',
           'qtime': 'select-submitted',
           'start': 'select-started'
    };
    var root = response.documentElement;
    for (var key in map) {
      var tagElem = root.getElementsByTagName(key).item(0);
      var rows = tagElem.getElementsByTagName('item');
      JobMonitor.fillSelectBox(rows, map[key], -1);
    }
  }
  catch (err) {
    JobMonitor.addError('fillAllTags: Error detail: ' + err.message);
  }
};
JobMonitor.requestLocalId = function (gridid) {
  if (gridid == '?' || gridid.length == 0) return;

  var url = JobMonitor.BASE_URL + 'command=localid&jid=' + gridid;
  JobMonitor.setMessage(url, 'LocalID from GridID');

  // Use cached info
  JobMonitor.transport = $.ajax({
           url: url, 
         cache: false,
          type: 'GET',
      dataType: 'text',
       timeout: JobMonitor.AJAX_REQUEST_LTIMEOUT,
       success: JobMonitor.fillLocalIdInfo,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillLocalIdInfo = function (response, status) {
  if (isNaN(response)) {
    JobMonitor.addError('Invalid LocalID retrieved from DB: localid='+response);
    return;
  }
  JobMonitor.requestJobInfo(response);
};
JobMonitor.requestJobStatus = function () { 
  var jid = $('#select-jid').val();
  if (!JobMonitor.valid(jid)) return;

  var url = JobMonitor.BASE_URL + '&jid=' + jid + '&command=status'; 
  JobMonitor.setMessage(url, 'job status');

  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'text',
       timeout: JobMonitor.AJAX_REQUEST_STIMEOUT,
       success: JobMonitor.fillJobSatus,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillJobStatus = function (response, status) {
  if ($('#check-logdebug').attr('checked')) 
     JobMonitor.addText('logger-debug', response);
};
JobMonitor.requestJobInfo = function (jid) { 
  if (!JobMonitor.valid(jid)) return;
  JobMonitor.currentJobID = jid;

  // Irrespective of conitions uninstall AutoUpdate
  JobMonitor.stopAutoUpdate();

  var url = JobMonitor.BASE_URL + 'jid=' + JobMonitor.currentJobID + '&command=summary'; 
  JobMonitor.setMessage(url, 'summary info');

  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'xml',
       timeout: JobMonitor.AJAX_REQUEST_STIMEOUT,
       success: JobMonitor.fillJobInfo,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillJobInfo = function (response, status) {
  try {
    if ($('#check-logdebug').attr('checked')) 
       JobMonitor.addText('logger-debug', response);
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
      try {
        var rows = root.getElementsByTagName(key);
        if (rows.length != 1) continue;
        var name = rows[0].childNodes[0].nodeValue;
        if (key == 'grid_id' && name != '?') {
          $('#' + map[key]).html('<a class="link" href="jobinfo.html?gridid='+name+'">'+name+'</a>');
        } else {
          $('#' + map[key]).html(name);
        }
      }
      catch (e) {
        JobMonitor.addError("fillJobInfo: Error for key="+key+", detail: \n" + e.message); 
      }
    }

    var status = $('#td-status').html();
    if (status == '?') return;
    $('#td-status').css('color', JobMonitor.colorMap[status]);

    // add rank and priority of queued jobs
    if (status == 'Queued') {
      var rank = -1;
      try {
        var rows = root.getElementsByTagName('rank');
        rank = rows[0].childNodes[0].nodeValue;
      }
      catch (e) {
        JobMonitor.addError("fillJobInfo: Error for key=rank, detail: \n" + e.message); 
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
      var url = JobMonitor.BASE_URL + 'jid=' + JobMonitor.currentJobID
                                    + '&command=' + tag 
                                    + '&width=' + width 
                                    + '&height=' + height;
      if (status == 'Running') url = JobMonitor.addRandom(url);
      if ($('#check-logevent').attr('checked')) JobMonitor.addText('logger-event', url);
      $(this).attr('src', url);
    });

    // ps, top etc. only for running jobs
    var list = $('#tabpanel-c').tabs('option', 'disabled');
    if ( (status == 'Running' || status == 'Unknown') ) {
      // enable the ps tab[index = 1], if disabled
      if (list.length > 5) 
        JobMonitor.tabOperation('#tabpanel-c', [2,3,4,5,6]);

      // enable all the detail tabs if 'show detail' is on
      if ($('#check-showdetail').attr('checked') && list.length > 1)
        JobMonitor.tabOperation('#tabpanel-c', []);

      JobMonitor.requestPsInfo();
    }
    else {
      // disable the ps tab
      // disable all the detail tabs even if 'show detail' is on
      if (list.length < 6) 
        JobMonitor.tabOperation('#tabpanel-c', [1,2,3,4,5,6]);
      JobMonitor.clearAllTextAreas();
    }
  }
  catch (err) {
    JobMonitor.addError('fillJobInfo: Error detail: ' + err.message); 
  }
  // re-install autoupdate
  if ($('#check-autoupdate').attr('checked')) JobMonitor.startAutoUpdate()
};
JobMonitor.requestPsInfo = function () {
  var url = JobMonitor.BASE_URL + 'jid=' + JobMonitor.currentJobID + '&command=ps';
  JobMonitor.setMessage(url, 'job ps info');

  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'text',
       timeout: JobMonitor.AJAX_REQUEST_STIMEOUT,
       success: JobMonitor.fillPsInfo,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillPsInfo = function (response, status) {
  JobMonitor.fillText('p-ps', response);

  // request the next one
  if ( $('#check-showdetail').attr('checked') ) JobMonitor.requestTopInfo();
};
JobMonitor.requestTopInfo = function () {
  var url = JobMonitor.BASE_URL + 'jid=' + JobMonitor.currentJobID + '&command=top';
  JobMonitor.setMessage(url, 'wn top info');

  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'text',
       timeout: JobMonitor.AJAX_REQUEST_STIMEOUT,
       success: JobMonitor.fillTopInfo,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillTopInfo = function (response, status) {
  JobMonitor.fillText('p-top', response);

  // Here goes Log and error info
  JobMonitor.requestWorkdirListInfo();
};
JobMonitor.requestWorkdirListInfo = function () {
  var url = JobMonitor.BASE_URL + 'jid=' + JobMonitor.currentJobID + '&command=workdir';
  JobMonitor.setMessage(url, 'work dir info');

  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'text',
       timeout: JobMonitor.AJAX_REQUEST_STIMEOUT,
       success: JobMonitor.fillWorkdirListInfo,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillWorkdirListInfo = function (response, status) {
  JobMonitor.fillText('p-workdir', response);

  // Here goes Log and error info
  JobMonitor.requestJobdirListInfo();
};
JobMonitor.requestJobdirListInfo = function () {
  var url = JobMonitor.BASE_URL + 'jid=' + JobMonitor.currentJobID + '&command=jobdir';
  JobMonitor.setMessage(url, 'job dir info');

  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'text',
       timeout: JobMonitor.AJAX_REQUEST_STIMEOUT,
       success: JobMonitor.fillJobdirListInfo,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillJobdirListInfo = function (response, status) {
  JobMonitor.fillText('p-jobdir', response);

  // Here goes Log and error info
  JobMonitor.requestLogInfo();
};
JobMonitor.requestLogInfo = function () {
  var url = JobMonitor.BASE_URL + 'jid=' + JobMonitor.currentJobID + '&command=log';
  JobMonitor.setMessage(url, 'job log');

  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'text',
       timeout: JobMonitor.AJAX_REQUEST_STIMEOUT,
       success: JobMonitor.fillLogInfo,
         error: JobMonitor.errorResponse
  });
};
JobMonitor.fillLogInfo = function (response, status) {
  JobMonitor.fillText('p-log', response);

  // Finally the error info
  JobMonitor.requestErrorInfo();
};
JobMonitor.requestErrorInfo = function () {
  var url = JobMonitor.BASE_URL + 'jid=' + JobMonitor.currentJobID + '&command=error';
  JobMonitor.setMessage(url, 'job error log');

  JobMonitor.transport = $.ajax({
          url: url,
        cache: false,
      timeout: JobMonitor.AJAX_REQUEST_STIMEOUT,
         type: 'GET',
     dataType: 'text',
      success: JobMonitor.fillErrorInfo,
        error: JobMonitor.errorResponse
  });
};
JobMonitor.fillErrorInfo = function (response, status) {
  JobMonitor.fillText('p-error', response);
};
// should handle both jobid and grid_id
JobMonitor.diagnoseJob = function () {
  var jid = $('#jidvalue').val();
  JobMonitor.resolveJobid(jid);
}
JobMonitor.diagnose = function () {
  JobMonitor.diagnosisOn = true;
  JobMonitor.requestUserSummary();
};
// should handle both jobid and grid_id
JobMonitor.jobInfo = function () {
  var args = arguments[0]; 
  var jid;
  if (args != null && args.length > 0) {
    jid = args;
  }
  else if ( !JobMonitor.paramRead && $(document).getUrlParam('gridid') != null ) {
    JobMonitor.paramRead = true;
    args = $(document).getUrlParam('gridid');
    jid = (args.length > 0) ? args : '?';
    JobMonitor.findItem('select-jid', args.replace('https://',''));
  }
  else {
    args = $('#select-jid').val();
    if (args.indexOf('!') > -1) {
      var fields = args.split('!');
      jid = (JobMonitor.valid(fields[0])) ? fields[0] : fields[1];
    }
    else 
      jid = args;
  }
  JobMonitor.resolveJobid(jid);
}
JobMonitor.resolveJobid = function(jid) {
  if (JobMonitor.valid(jid)) {
    // set jid as the selected value  
    JobMonitor.requestJobInfo(jid);
  }
  else {
    // should start with https://
    var index = jid.indexOf('https://');
    if (index < 0) {
      index = jid.indexOf('CREAM');
      if (index < 0) jid = 'https://' + jid;
    }
    JobMonitor.requestLocalId(jid);
  }
};
JobMonitor.fillSelectBoxJSON = function (rows, id, index) {
  var obj = $('#' + id).get(0);
  if (obj == null) {
    JobMonitor.addError('Select Box object, ' + id + ' not found!');
    return false;
  }

  // Type of Jobid to be displayed (Local ID, Grid ID)
  var jidType = $('#select-jidtype').val();
  if (jidType == null) {
    JobMonitor.addError('Invalid JID type!, type=' + jidType);
    return false;
  }
  JobMonitor.clearSelectBox(id);
  if (!rows.length) return false;

  var list = '';
  jQuery.each(rows, function() {
    var fields = this.split('##');
    if (fields.length > 1) {
      var value = fields[0];      
      var title = fields[1];
      var text  = value;
      if (jidType == 'gridid') {
        var idxl = fields[1].indexOf('Unknown Job');
        var idxp = fields[1].indexOf('Pilot Job');
        value = (idxl  > -1 || idxp > -1) ? fields[0] : fields[1];
        title = fields[0];
         text = fields[1];
      }

      list += text + "\n";
      var option = new Option(text, value);
      option.title = title;
      try {
        obj.add(option, null);
      }
      catch (e) {
        obj.add(option, -1);
      }
    }
  });
  $('#logger-gid').val(list);
  if (index > -1 && index < obj.options.length)
    obj.options[index].selected = true;

  // even/odd rows for options
  JobMonitor.stripe(id);

  return true;
};
JobMonitor.findItem = function(id, name) {
  var obj = $('#' + id).get(0);
  if (obj == null) {
    JobMonitor.addError('findItem: SelectBox object, ' + id + ' not found!');
    return false;
  }

  var index = -1;
  obj.selectedIndex = index;
  var len = obj.length;
  for (var i = 0; i < len; ++i) {
    var text = obj.options[i].text;
    JobMonitor.addText('logger-debug', name + ',' + text);
    if (text == name) {
      index = i;
      break;
    }
  }
  if (index < 0) return false;

  obj.selectedIndex = index;
  return true;
};
JobMonitor.disableInputFields = function (decision) {
  $('#input-from').attr('disabled', decision);
  $('#input-to').attr('disabled', decision);
};
JobMonitor.setDateFields = function () {
  var d = new Date();
  $('#input-to').val(JobMonitor.getDate(d));

  var epoch = d.getTime() - JobMonitor.SIX_HOURS;
  d = new Date(epoch);
  $('#input-from').val(JobMonitor.getDate(d));
};
JobMonitor.getDate = function (obj) {
  var sec   = $.sprintf("%02d", obj.getSeconds());
  var min   = $.sprintf("%02d", obj.getMinutes());
  var hour  = $.sprintf("%02d", obj.getHours());
  var day   = $.sprintf("%02d", obj.getDate());
  var month = $.sprintf("%02d", obj.getMonth() + 1);
  var year  = obj.getFullYear();

  var s = year + '-' + month + '-' + day + ' ' + hour + ':' + min + ':' + sec;
  return s;
};
JobMonitor.getFilter = function () {
  var name = $('#select-filter').val();
  if (name == null || name == 'all') return '?';

  var value = $('#select-tag').val();
  if (value == null) return '?';

  return (name + '!' + value);
};
JobMonitor.isStdJob = function(tag) {
  var idxl = tag.indexOf('Unknown Job');
  var idxp = tag.indexOf('Pilot Job');
  if (idxl > -1 || idxp > -1) return false;
  return true;
}
JobMonitor.fillSelectBox = function (rows, id, index) {
  // Run number select box
  var obj = $('#' + id).get(0);
  if (obj == null) {
    JobMonitor.addError('Run option Object, ' + id + ' not found!');
    return;
  }
  JobMonitor.clearSelectBox(id);
  jQuery.each(rows, function() {
    var name   = this.childNodes[0].nodeValue;
    var option = new Option(name, name);
    option.title = name;
    try {
      obj.add(option, null);
    }
    catch (e) {
      obj.add(option, -1);
    }
  });
  if (index > -1 && index < obj.options.length) 
    obj.options[index].selected = true;

  // even/odd rows for options
  JobMonitor.stripe(id, 0);
};
JobMonitor.swapView = function() {
  // Type of Jobid to be displayed (Local ID, Grid ID)
  var jidType = $('#select-jidtype').val();
  if (jidType == null) {
    JobMonitor.addError('Invalid JID type!, type=' + jidType);
    return false;
  }

  // Job id select box
  var id = 'select-jid';
  var obj = $('#' + id).get(0);
  if (obj == null) return;

  var selindex = JobMonitor.getSelectedIndex(id);

  var rows = new Array();
  $('#' + id + ' option').each(function() {
    var text  = $(this).text();
    var title = $(this).attr('title');
 
    var value;
    // check if text displayed is a Pilot
    if (JobMonitor.isStdJob(text) && JobMonitor.isStdJob(title)) {
      value = title;
      text  = title;
      title = $(this).val();
    }
    else {
      value = $(this).val();
      title = text;
      text = $(this).attr('title');
    }
    var str = value + '##' + text + '##' + title;
    rows.push(str);
  });

  JobMonitor.clearSelectBox(id);
  var list = '';
  jQuery.each(rows, function() {
    var fields = this.split('##');
    if (fields.length > 2) {
      var value = fields[0];
      var text  = fields[1];
      var title = fields[2];

      list += text + "\n";
      var option = new Option(text, value);
      option.title = title;
      try {
        obj.add(option, null);
      }
      catch (e) {
        obj.add(option, -1);
      }
    }
  });
  // even/odd rows for options
  JobMonitor.stripe(id);

  if (selindex > -1 && selindex < obj.options.length)
    obj.options[selindex].selected = true;

  $('#logger-gid').val(list);
};
JobMonitor.getJobState = function() {
  return $('input:radio[name=jobstate]:checked').val();
};
JobMonitor.fillText = function (id, text) {
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
JobMonitor.stripe = function(id) {
  $('#' + id + ' option:odd').css('background-color', '#f7f7f7');
  var padv = '2';
  var args = arguments[1];
  if (args != null && args > -1) padv = args;
  var px = padv + 'px';
  $('#' + id + ' option').css('padding-top', px).css('padding-bottom', px);
}
JobMonitor.stopRKey = function (evt) {
  var evt = (evt) ? evt : ((event) ? event : null);
  var node = (evt.target) ? evt.target : ((evt.srcElement) ? evt.srcElement : null);
  if ((evt.keyCode == 13) && (node.type == 'text'))  {return false;}
};
JobMonitor.clearLogger = function() {
  $('textarea.fg-logger').val('');
};
JobMonitor.addError = function(text) {
  JobMonitor.addText('logger-error', text);
  $('#tabpanel-e').tabs('option', 'selected', 1);
}
JobMonitor.addText = function(id, text) {
  var val = $('#' + id).val();
  if (val == null) return;
  val += ((val != '') ? "\n" : '') + (new Date()) + " >>> " + text;
  $('#' + id).val(val);
};
JobMonitor.getSelectedValue = function (id) {
  return $('#' + id + ' option:selected').val();
}
JobMonitor.getSelectedIndex = function (id) {
  var option = $('#' + id + ' option:selected').get(0);
  return $('#' + id + ' option').index(option);
};
JobMonitor.setSelectIndex = function (id, index) {
  $('#' + id).get(0).selectedIndex = index;
};
JobMonitor.clearSelectBox = function (id) {
  $('#' + id + ' option').each(function() {
    $(this).remove();
  });
};
JobMonitor.addRandom = function (url) {
  return (url + '&t='+Math.random());
};
JobMonitor.resetFilter = function () {
  JobMonitor.setSelectIndex('select-filter', 0);  
};
JobMonitor.setMessage = function (url, message) {
  if ($('#check-logevent').attr('checked')) JobMonitor.addText('logger-event', url);
  $('#label-datatype').html('Loading ' + message);
};
JobMonitor.clearAllTextAreas = function() {
  $('p.fg-infoarea').html('');
};
JobMonitor.changeJIDFontSize = function () {
  var jidType = $('#select-jidtype').val();
  $('#select-jid').css('font-size', JobMonitor.fsDict[jidType]);
};
JobMonitor.changeTagFontSize = function () {
  var tag = $('#select-filter').val();
  if (tag != 'subject') tag = 'default';
  $('#select-tag').css('font-size', JobMonitor.fsDict[tag]);
};
JobMonitor.showProgress = function() {
  $('#tabpanel-d').unblock({fadeOut:0}).block({
    message: null,
    overlayCSS: {
      backgroundColor: '#000',
              opacity: '0.025'
    }
  });
  $('#tabpanel-b').unblock({fadeOut:0}).block({
    message: $('#panel-message-blockui'),
        css: { 
              padding: 0, 
               margin: 0, 
                width: '60%', 
                  top: '40%', 
                 left: '35%', 
              opacity: '0.7',
            textAlign: 'center', 
                color: '#fff', 
               border: '3px solid #aaa', 
      backgroundColor: '#000', 
               cursor: 'wait' 
    }, 
    overlayCSS: {
      backgroundColor: '#000',
              opacity: '0.025'
    }
  });
  $('#button-panel').unblock({fadeOut:0}).block({
    message: null,
    overlayCSS: {
      backgroundColor: '#000',
              opacity: '0.025'
    }
  });
  $('#panel-progress').fadeIn();
};
JobMonitor.hideProgress = function() {
  $('#panel-progress').fadeOut();
  $('#tabpanel-b').unblock({fadeOut: 0});
  $('#tabpanel-d').unblock({fadeOut: 0});
  $('#button-panel').unblock({fadeOut: 0});
};
JobMonitor.toggleShowDetail = function() {
  if ( $('#check-showdetail').attr('checked') ) {
    var status = $('#td-status').html();
    if ( (status == 'Running' || status == 'Unknown') ) {
      JobMonitor.tabOperation('#tabpanel-c', []);
      JobMonitor.requestTopInfo();
    }
  } 
  else {
    if ($('#tabpanel-c').tabs('option', 'selected') >= 2) {
      $('#tabpanel-c').tabs('option', 'selected', 0);
    }
    JobMonitor.tabOperation('#tabpanel-c', [2, 3, 4, 5, 6]);
  }
}; 
JobMonitor.tabOperation = function(id, indexList) {
  $(id).tabs('option', 'disabled', indexList);
}
JobMonitor.selectSame = function(obj) {
  var value = $(obj).html();
  if (value == null ||
      value == ''   ||
      value == '?'  ||
      value == 'n/a') return;

  var id = $(obj).attr('id');
  $('#tabpanel-d').tabs('option', 'selected', 1);
  JobMonitor.setSelectIndex('select-filter', JobMonitor.tdmap[id]);
  $('#select-filter').change();

  if (id == 'td-user') {
    var a = value.split(' ');
    value = a[0];
  }
  $('#select-tag').val(value);
  setTimeout("$('#select-tag').dblclick()", 100);
};
JobMonitor.resetSelection = function() {
  JobMonitor.resetFilter();
  $('#select-filter').change();
}
// input field's event handlers 
// wait till the DOM is loaded
$(document).ready(function() {
  document.onkeypress = JobMonitor.stopRKey;

  $('body').css('font-size','0.75em');
  $('body,div,span,a,p,label,select,input,checkbox,radiobutton,button,textarea')
      .addClass('ui-widget')
      .css('font-weight', 'normal');
  $('select,textarea,fieldset,p').addClass('ui-widget-content');
  $('div,fieldset').addClass('ui-corner-all');
  $('fieldset').addClass('ui-widget-header');
  $('input,checkbox,radiobutton,button').addClass('ui-state-default');
  $('textarea').addClass('fg-logger');
  $('textarea#logger-error').css('color','red');
  $('p').addClass('fg-infoarea');
  $('div.panel-header').addClass('ui-widget-header');
  $('#panel-north').css('border','1px solid #aed0ea');
  $('hr').css('color','#aed0ea');
  $('#tabpanel-a,#tabpanel-b,#tabpanel-c,#tabpanel-d,#tabpanel-e')
    .css('border','0px solid #aed0ea')
    .addClass('ui-widget-content');
  $('#panel-south').css('border','1px solid #aed0ea').css('padding','1px 0px 2px 0px');

  $('img.info')
     .attr('src', 'images/info.png')
     .attr('title', 'double-click the value for related jobs')
     .css('margin-bottom', '-2px');
  $('img.wlabel').css('margin-bottom', '-2px');
  $('select.fg-combobox').css('width', '67%');
  $("input:submit[value='Update List']").addClass('fg-button');
  $("input:submit[value='Reset Selection']").addClass('fg-button');
  $('input:submit').addClass('ui-corner-all');

  // Create the tabs
  $('#tabpanel-a').tabs({ selected: 1 });
  $('#tabpanel-b').tabs();
  $('#tabpanel-c').tabs({disabled: [2,3,4,5,6]});
  $('#tabpanel-d').tabs();
  $('#tabpanel-e').tabs({ selected: 3 });

  var wl = new Array('350px','800px');
  var hl = new Array('auto','500px');
  $('a.dtips,a.htips').each(function(index) {
    var w = wl[index];
    var h = hl[index];
    $(this).cluetip({
              width: w, 
             height: h,
             sticky: true, 
      closePosition: 'title', 
             arrows: true, 
          showTitle: true,
         activation: 'click',
        hoverIntent: {
         sensitivity:  1,
            interval:     750,
             timeout:      750    
         },
                 fx: {             
                   open:       'fadeIn', // can be 'show' or 'slideDown' or 'fadeIn'
                   openSpeed:  'normal'
                 },
          ajaxCache: false
    });
  })
  // show/hide the progress panel as soon as ajax request starts/returns
  $(document).ajaxStart(function() {
    JobMonitor.showProgress();
  });
  $(document).ajaxStop(function() {
    JobMonitor.hideProgress();
  });

  // even/odd rows for options
  JobMonitor.stripe('select-diagnose');
  JobMonitor.stripe('select-filter', 0);

  // Attach actions
  // Select boxes
  $('#select-jid').dblclick(JobMonitor.jobInfo);
  $('#select-tag').dblclick(JobMonitor.requestUserSummary);
  $('#select-diagnose').dblclick(JobMonitor.diagnose);
  $('#select-filter').change(function() {
    JobMonitor.requestTagList();
  });
  $('#select-jidtype').change(function() {
    var jtype = JobMonitor.getSelectedValue('select-jidtype');
    var m = (jtype == 'gridid') ? 'Grid' : 'Local';
    JobMonitor.setMessage('Swapping JID view', m + ' JobID');
    JobMonitor.showProgress();
    setTimeout('JobMonitor.swapView()', 50); // millisec
    JobMonitor.hideProgress();
  });

  // Buttons
  $('input:submit[value=Show]').click(JobMonitor.diagnoseJob);
  $('input:submit[value=LoadAll]').click(JobMonitor.requestAllTagValues);
  $("input:submit[value='Update List']").click(JobMonitor.requestUserSummary);
  $("input:submit[value='Clear Log']").click(JobMonitor.clearLogger);
  $("input:submit[value='Reset Selection']").click(JobMonitor.resetSelection);

  // Radio buttons
  $('input:radio[name=jobstate]').click(function() {
    setTimeout('JobMonitor.requestUserSummary()', 50); // millisec
  });

  // Quick Select
  for (var id in JobMonitor.tdmap) {
    $('#'+id).dblclick( function() { 
      JobMonitor.selectSame(this); 
    });
  }
 
  // Checkbox
  $('#check-showdetail').click(JobMonitor.toggleShowDetail);
  $('#check-myjobs').click(JobMonitor.requestUserSummary);
  $('#check-autoupdate').click(JobMonitor.toggleAutoUpdate);

  // Style
  // Input text  
  $('input:text').focus(function() {
    $(this).removeClass('ui-state-default').addClass('ui-state-focus');
  }).blur(function() {
    $(this).removeClass('ui-state-focus').addClass('ui-state-default');
  });

  // buttons
  $('input:submit').mouseover(function() {
    $(this).removeClass('ui-state-default').addClass('ui-state-focus');
  }).mouseout(function() {
    $(this).removeClass('ui-state-focus').addClass('ui-state-default');
  });

  // hide the authetication panel in the beginning
  $('#div-entry').hide();
  $('#label-auth').hide();
  $('#panel-progress').hide();

  // Set label color
  $('#panel-auth label').css('color', '#2779aa');
  $('#panel-progress label').css('color', '#2779aa');

  // reset the logger area checkbox
  $('input:checkbox').each(function() {
    $(this).attr('checked', false);
  });

  // Check 'running' as default state
  $('input:radio[value=running]').attr('checked', true);

  // If mozilla set vertical-align for the labels
  // seems also to depend on the OS :-(
  if ($.browser.msie) {
    $('table').css('border-collapse','collapse').css('border-spacing','0px');
    $('td').css('border-width','1px');
  }
  if ($.browser.mozilla) {
    var p = (navigator.platform == 'Win32') ? '2px' : '2px';
    $('label').css('vertical-align', p);
    $('label.noal').css('vertical-align', '0px');
  }
  if ($.browser.opera) {
    $('#img-loading').css('margin-bottom', '-2px');
  }

  JobMonitor.clearLogger();
  JobMonitor.resetFilter();
  JobMonitor.setDateFields();
  JobMonitor.toggleShowDetail();

  setTimeout('JobMonitor.requestAuthenticationInfo()', 100); // millisec
});
