var JobMonitor = 
{
                   site: 'ucsd',
           currentJobID: '',
          currentTaskID: '',
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
                     'td-acctgroup': 2,
                          'td-user': 3,
                            'td-rb': 4,
                          'td-ceid': 5,
                      'td-exechost': 6,
                     'td-submitted': 7,
                       'td-started': 8,
                    'td-exitstatus': 9
                  },
               status_map: {
                  'R': 'Running',
                  'Q': 'Queued',
                  'H': 'Held',
                  'E': 'Completed',
                  'U': 'Completed'
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
  ($('#check-autoupdate').is(':checked')) ? JobMonitor.startAutoUpdate()
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
  //submit-4.t2.ucsd.edu#47993.57#1369854232
  if (jid == null) return false;

  var fields = jid.split('#');
  if (fields.length < 3) return false;

  var local_id = fields[1];
  fields = local_id.split('.');
  if (fields.length < 2 || isNaN(fields[0]) || isNaN(fields[1])) return false;

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
  if (! $('#check-myjobs').is(':checked')) query += '&myjobs=true';

  if (JobMonitor.diagnosisOn) {
    var value = $('#select-diagnose').val();
    if (value != null) {
      query += '&diagnose=' + value;
    }
  }
  return query;
}
// Communications start here
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
    if ($('#check-debug').is(':checked')) JobMonitor.addText('logger-debug', response);
    $('#label-auth').html(response);
    $('#image-dn').attr('src', 'images/vote-user-green.gif');
    $('#label-auth').fadeIn(1000);

    // Authentication successful, now load the task list
    JobMonitor.requestUserSummary();
  }
  catch (err) {
    JobMonitor.addError('fillAuthenticationInfo: Error detail: ' + err.message);
  }
};
JobMonitor.requestUserSummary = function () {
  var query = JobMonitor.prepareStatement();

  // Now build the request URL and go
  var url = JobMonitor.BASE_URL + 'command=userview' + query; 
  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'html',
       timeout: JobMonitor.AJAX_REQUEST_LTIMEOUT,
       success: JobMonitor.fillUserSummary,
         error: JobMonitor.errorResponse
  });
  $('div#summary-panel,div#jobinfo-panel').fadeOut(2000);
  JobMonitor.setMessage(url, 'User Summary table');
};
JobMonitor.fillUserSummary = function(response, status) {
  try {
    if ($('#check-logdebug').is(':checked')) 
      JobMonitor.addText('logger-debug', response);
    
    $('div#summary-panel')
      .empty()
      .append(response)
      .css('overflow','auto');

    // clicking the task_id will now show the detail at the bottom
    $('table#userview tbody tr').each(function() {
      var list = $(this).children('td');
      $(list).eq(0).css('text-align', 'left').dblclick(function() {
        var taskid = $(this).html();
        if (taskid.indexOf('All') < 0) JobMonitor.requestTaskView(taskid); 
      });
    });
    var oTable = $('table#userview').dataTable({
            "bJQueryUI": false,
                "bSort": true,
      "sPaginationType": "full_numbers",
           "bAutoWidth": false,
        "bLengthChange": false,
          "bProcessing": false,
       "iDisplayLength": 5,
            "aaSorting": [[2,'desc']]
    });
    $('div#summary-panel').fadeIn(2000);
  }
  catch (err) {
    JobMonitor.addError('fillUserSummary: Error detail: ' + err.message); 
  }
};
JobMonitor.requestTaskView = function (taskid) {
  var query = JobMonitor.prepareStatement();
  if (JobMonitor.diagnosisOn) JobMonitor.diagnosisOn = false;

  // Now build the request URL and go
  JobMonitor.currentTaskID = taskid;
  var url = JobMonitor.BASE_URL + 'command=taskview&task_id=' + encodeURIComponent(JobMonitor.currentTaskID) + query; 
  JobMonitor.transport = $.ajax({
           url: url,
         cache: false,
          type: 'GET',
      dataType: 'html',
       timeout: JobMonitor.AJAX_REQUEST_LTIMEOUT,
       success: JobMonitor.fillTaskInformation,
         error: JobMonitor.errorResponse
  });
  JobMonitor.setMessage(url, 'job list for a task');
  $('div#jobinfo-panel').fadeOut(2000);
};
JobMonitor.fillTaskInformation = function(response, status) {
  try {
    if ($('#check-logdebug').is(':checked')) 
      JobMonitor.addText('logger-debug', response);

    $('div#jobinfo-panel')
      .empty()
      .append(response)
      .css('overflow','auto');

    // clicking the task_id will now show the detail at the bottom
    $('table#taskview tbody tr').each(function() {
      var list = $(this).children('td');
      $(list).eq(0).css('text-align', 'left').dblclick(function() {
        var gridid = $(this).html();
        $('#tabpanel-a').tabs('option', 'active', 1);
        if (JobMonitor.findItem('select-jid', gridid)) { 
          JobMonitor.requestLocalId(gridid); 
        }
      });
      $(list).eq(1).html(JobMonitor.status_map[$(list).eq(1).html()]);
    });
    JobMonitor.fillJobidList();
    var oTable = $('table#taskview').dataTable({
            "bJQueryUI": false,
                "bSort": true,
      "sPaginationType": "full_numbers",
           "bAutoWidth": false,
        "bLengthChange": false,
          "bProcessing": false,
       "iDisplayLength": 16,
            "aaSorting": [[8,'desc']]
    });
    $('div#jobinfo-panel').fadeIn(2000);
  }
  catch (err) {
    JobMonitor.addError('fillTaskInformation: Error detail: ' + err.message); 
  }
};
JobMonitor.fillJobidList = function() {
  var options = [];
  var lids = '';
  $('table#taskview tbody tr').each(function() {
    var list = $(this).children('td');
    var gridid = $(list).eq(0).html();
    options.push('<option value="' + gridid + '">' + gridid + '</option>');
    lids += gridid + "\n";
  });

  // now empty the select and append the items from the array
  $('#select-jid').empty().append(options.join());
  $('#label-entries').html(options.length + ' Entries');
  // even/odd rows for options
  JobMonitor.stripe('select-jid');
  $('#logger-gid').val(lids);
  $('#div-entry').fadeIn(3000);
};
JobMonitor.requestJobidList = function () {
  var query = JobMonitor.prepareStatement();
  if (JobMonitor.diagnosisOn) JobMonitor.diagnosisOn = false;

  // Now build the request URL and go
  var url = JobMonitor.BASE_URL + 'command=list&task_id=' + encodeURIComponent(JobMonitor.currentTaskID) + query; 

  JobMonitor.setMessage(url, 'job list for a task');
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
    if ($('#check-logdebug').is(':checked')) 
      JobMonitor.addText('logger-debug', response);
    var rows = response.jids;
    var res = JobMonitor.fillSelectBoxJSON(rows, 'select-jid', 0);
    $('#label-entries').html(rows.length + ' Entries');
    $('#div-entry').fadeIn(3000);
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
    if ($('#check-logdebug').is(':checked')) 
      JobMonitor.addText('logger-debug', response);
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
    if ($('#check-logdebug').is(':checked')) 
                                                                                                                        
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
  var url = JobMonitor.BASE_URL + 'command=localid&jid=' + encodeURIComponent(gridid);
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
  if (response == null || !response.length) {
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
  if ($('#check-logdebug').is(':checked')) 
     JobMonitor.addText('logger-debug', response);
};
JobMonitor.requestJobInfo = function (jid) { 
  if (!JobMonitor.valid(jid)) return;
  JobMonitor.currentJobID = jid;

  // Irrespective of conditions uninstall AutoUpdate
  JobMonitor.stopAutoUpdate();

  var url = JobMonitor.BASE_URL + 'jid=' + encodeURIComponent(JobMonitor.currentJobID) + '&command=summary'; 
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
    if ($('#check-logdebug').is(':checked')) 
       JobMonitor.addText('logger-debug', response);
    var map = {
         'local_id': 'td-jobid', 
           'status': 'td-status', 
             'user': 'td-user', 
       'acct_group': 'td-acctgroup', 
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
          'task_id': 'td-taskid'
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
      var url = JobMonitor.BASE_URL + 'jid=' + encodeURIComponent(JobMonitor.currentJobID)
                                    + '&command=' + tag 
                                    + '&width=' + width 
                                    + '&height=' + height;
      if (status == 'Running') url = JobMonitor.addRandom(url);
      if ($('#check-logevent').is(':checked')) 
         JobMonitor.addText('logger-event', url);
      $(this).attr('src', url);
    });
  }
  catch (err) {
    JobMonitor.addError('fillJobInfo: Error detail: ' + err.message); 
  }
  // re-install autoupdate
  if ($('#check-autoupdate').is(':checked')) JobMonitor.startAutoUpdate()
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
  JobMonitor.requestLocalId(jid);
};
JobMonitor.fillSelectBoxJSON = function (rows, id, index) {
  var obj = $('#' + id).get(0);
  if (obj == null) {
    JobMonitor.addError('Select Box object, ' + id + ' not found!');
    return false;
  }

  JobMonitor.clearSelectBox(id);
  if (!rows.length) return false;

  var list = '';
  jQuery.each(rows, function() {
    var value = this;
    if (value.length > 0) {
      list += value + "\n";
      var option = new Option(value, value);
      option.title = value;
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
  //var list = $('#' + id + ' option');

  var index = -1;
  obj.selectedIndex = index;
  var len = obj.length;
  for (var i = 0; i < len; ++i) {
    var text = obj.options[i].text;
    //JobMonitor.addText('logger-debug', name + ',' + text);
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
  var obj = $('#' + id).get(0);
  if (obj == null) {
    JobMonitor.addError('Object, ' + id + ' not found!');
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
JobMonitor.getJobState = function() {
  return $('input:radio[name=jobstate]:checked').val();
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
  $('#tabpanel-e').tabs('option', 'active', 1);
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
  if ($('#check-logevent').is(':checked')) JobMonitor.addText('logger-event', url);
  $('#label-datatype').html('Loading ' + message);
};
JobMonitor.clearAllTextAreas = function() {
  $('p.fg-infoarea').html('');
};
JobMonitor.changeTagFontSize = function () {
  var tag = $('#select-filter').val();
  if (tag != 'subject') tag = 'default';
  $('#select-tag').css('font-size', JobMonitor.fsDict[tag]);
};
JobMonitor.showProgress = function() {
  // Show/Hide progress on ajaxStart/Stop
  $('#panel-progress').fadeIn(1000);
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
  $('#summary-panel,#tabpanel-d').unblock({fadeOut:0}).block({
         message: null,
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
};
JobMonitor.hideProgress = function () {
  $('#summary-panel,#tabpanel-b,#tabpanel-d,#button-panel')
    .unblock({fadeOut: 0});
  $('#panel-progress').fadeOut(1000);
};
JobMonitor.selectSame = function(obj) {
  var value = $(obj).html();
  if (value == null ||
      value == ''   ||
      value == '?'  ||
      value == 'n/a') return;

  var id = $(obj).attr('id');
  $('#tabpanel-d').tabs('option', 'active', 1);
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
  $('#tabpanel-a').tabs({ selected: 0 });
  $('#tabpanel-b').tabs();
  $('#tabpanel-c').tabs();
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
             interval: 750,
              timeout: 750    
        },
                 fx: {             
                    open: 'fadeIn', // can be 'show' or 'slideDown' or 'fadeIn'
                    openSpeed: 'normal'
                 },
          ajaxCache: false
    });
  });
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

  // Buttons
  $('input:submit[value=Show]').click(JobMonitor.diagnoseJob);
  $("input:submit[value='Update List']").click(JobMonitor.requestUserSummary);
  $("input:submit[value='Clear Log']").click(JobMonitor.clearLogger);
  $("input:submit[value='Reset Selection']").click(JobMonitor.resetSelection);

  // Radio buttons
//  $('input:radio[name=jobstate]').click(function() {
//    setTimeout('JobMonitor.requestUserSummary()', 50); // millisec
//  });

  // Quick Select
  for (var id in JobMonitor.tdmap) {
    $('#'+id).dblclick( function() { 
      JobMonitor.selectSame(this); 
    });
  }
 
  // Checkbox
  //$('#check-myjobs').click(JobMonitor.requestUserSummary);
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

  JobMonitor.clearLogger();
  JobMonitor.resetFilter();
  JobMonitor.setDateFields();

  setTimeout('JobMonitor.requestAuthenticationInfo()', 100); // millisec
});
