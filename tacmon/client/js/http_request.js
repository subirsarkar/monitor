var request = null; 
var BASE_URL = getBaseURL()+'/cgi-bin/tacmon/monitor.pl?';
var DEBUG = false;
var SEC2MSEC = 1000;
var autoUpdateInterval = 3*60*SEC2MSEC;  // 5 minutes
var autoUpdateTimerID = null;

// ------------------------------------------------
// From AJAX Hacks, Bruce W. Perry, O'Reilly, 2005
// -----------------------------------------------
/* Wrapper function for constructing a request object. 
   Parameters: 
     <reqType>: The HTTP request type, such as GET or POST. 
     <url>: The URL of the server program. 
     <asynch>: Whether to send the request asynchronously or not. 
     <respHandle>: The name of the function that will handle the response. 

     Any fifth parameters, represented as arguments[4], are the data a 
     POST request is designed to send. 
*/ 
function httpRequest(reqType, url, asynch, respHandle) { 
  url += '&t='+Math.random();
  if (window.XMLHttpRequest) {   // Mozilla-based browsers 
    request = new XMLHttpRequest(); 
  } 
  else if (window.ActiveXObject) { 
    request = new ActiveXObject("Msxml2.XMLHTTP"); 
    if (!request) { 
      request = new ActiveXObject("Microsoft.XMLHTTP"); 
    } 
  } 
  // very unlikely, but we test for a null request 
  // if neither ActiveXObject was initialized 
  if (request) { 
    // if the reqType parameter is POST, then the 
    // 5th argument to the function is the POSTed data 
    if (reqType.toLowerCase() != "post") { 
      initReq(reqType, url, asynch, respHandle); 
    }  
    else { 
      // the POSTed data 
      var args = arguments[4]; 
      if (args != null && args.length > 0) { 
         initReq(reqType, url, asynch, respHandle, args); 
      } 
    } 
  } 
  else { 
    alert("Your browser does not permit the use of all "+ 
          "of this application's features!"); 
  } 
} 
// Initialize a request object that is already constructed 
function initReq(reqType, url, bool, respHandle) { 
  try { 
    // Specify the function that will handle the HTTP response 
    request.onreadystatechange = respHandle; 
    request.open(reqType, url, bool); 

    // if the reqType parameter is POST, then the 
    // 5th argument to the function is the POSTed data 
    if (reqType.toLowerCase() == "post") { 
      request.setRequestHeader("Content-Type", 
           "application/x-www-form-urlencoded; charset=UTF-8"); 
      request.send(arguments[4]); 
    }  
    else { 
      request.send(null); 
    } 
  } 
  catch (errv) { 
    alert ( 
        "The application cannot contact " + 
        "the server at the moment. " + 
        "Please try again in a few seconds.\\n" + 
        "Error detail: " + errv.message); 
  } 
}
//input field's event handlers 
window.onload=function() { 
  // this takes time 
  //var tabs = Array('Shifter Summary','Run Summary', 'Local Raw', 'Local EDM','Castor Raw', 'Castor EDM', 'DBS Raw', 'DBS Reco');
  var tabs = Array('Run Summary', 'Local Raw', 'Local EDM','Castor Raw', 'Castor EDM', 'DBS Raw', 'DBS Reco');
  initTabs('dhtmlgoodies_tabView1', tabs, 0,'99.5%','100%');

  RequestDetectorList();
}
window.onunload=function() {
  StopAutoUpdate();
}
function RequestDetectorList() {
  var queryString = 'command=detlist';
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillDetectorList);
  SetProgress('visible', 'detector list');
}
function FillDetectorList() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = eval('(' + request.responseText + ')');
        var rows = response.dets;
        FillSelectBoxJSON(rows, 'dettagid', 0);

        RequestRunList();
      }
      catch (err) {
        alert ("FillDetectorList: Error detail: " + err.message);
      }
    }
    else {
      alert("FillDetectorList: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestRunList() {
  var dtype = GetDetectorType();
  if (dtype == 'All Detectors') dtype = 'all';
  var queryString = 'command=runlist&dtype='+dtype;

  var filter = GetFilter();
  if (filter != '?') queryString += '&filter='+filter;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillRunList);
  SetProgress('visible','run list');
}
function FillRunList() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = eval('(' + request.responseText + ')');
        var rows = response.runs;
        FillSelectBoxJSON(rows, 'runlistid', 0);
        var label = document.getElementById('entries');
        if (label != null) {
          label.innerHTML = rows.length;
        }

        RequestRunInfo();
      }
      catch (err) {
        alert ("FillRunList: Error detail: " + err.message);
      }
    }
    else {
      alert("FillRunList: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function FillSelectBoxJSON(rows, destObj, index) {
  // Run number select box
  var obj = document.getElementById(destObj);
  if (obj == null) {
    alert('Run option Object, '+destObj+ ' not found!');
    return;
  }
  obj.options.length = 0;

  for (var i = 0; i < rows.length; i++) {
    var name = rows[i];
    var option = new Option(name, name);
    try {
      obj.add(option, null);
    }
    catch (e) {
      obj.add(option, -1);
    }
  }
  if (index >-1 && index < obj.options.length)
    obj.options[index].selected = true;
}

function RequestRunInfo() {
  //RequestShifterSummaryInfo();
  StopAutoUpdate();
  RequestRunSummaryInfo();
}
function RequestShifterSummaryInfo() {
  var run = GetSelectedValue('runlistid');
  var queryString = 'command=shiftsummary&run='+run;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillShiftSummaryInfo);
}
function FillShiftSummaryInfo() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        var response = request.responseText;
        
        // We should call the next one here and so on
        RequestRunSummaryInfo();
      }
      catch (err) {
        alert ("FillShiftSummaryInfo: Error detail: " + err.message);
      }
    }
    else {
      alert("FillShiftSummaryInfo: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestRunSummaryInfo() {
  var run = GetSelectedValue('runlistid');
  var queryString = 'command=runsummary&run='+run;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillRunSummaryInfo);
  SetProgress('visible','run summary');
}
function FillRunSummaryInfo() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = request.responseText;
        FillTable(response);

        // We should call the next one here and so on
        RequestLocalRawFileInfo();
      }
      catch (err) {
        alert ("FillRunSummaryInfo: Error detail: " + err.message);
      }
    }
    else {
      alert("FillRunSummaryInfo: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestLocalRawFileInfo() {
  var run = GetSelectedValue('runlistid');
  var queryString = 'command=localraw&run='+run;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillLocalRawFileInfo);
  SetProgress('visible', 'local raw file information');
}
function FillLocalRawFileInfo() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = eval('(' + request.responseText + ')');
        var rows = response.files;
        FillTextFromArray('localrawid', 'nfillrid', rows);

        // We should call the next one here and so on
        RequestLocalEdmFileInfo();
      }
      catch (err) {
        alert ("FillLocalRawFileInfo: Error detail: " + err.message);
      }
    }
    else {
      alert("FillLocalRawFileInfo: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestLocalEdmFileInfo() {
  var run = GetSelectedValue('runlistid');
  var queryString = 'command=localedm&run='+run;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillLocalEdmFileInfo);
  SetProgress('visible', 'local edm file information');
}
function FillLocalEdmFileInfo() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = eval('(' + request.responseText + ')');
        var rows = response.files;
        FillTextFromArray('localedmid', 'nfilleid', rows);

        // We should call the next one here and so on
        RequestCastorRawFileInfo();
      }
      catch (err) {
        alert ("FillLocalEdmFileInfo: Error detail: " + err.message);
      }
    }
    else {
      alert("FillLocalEdmFileInfo: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestCastorRawFileInfo() {
  var run = GetSelectedValue('runlistid');
  var queryString = 'command=castorraw&run='+run;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillCastorRawFileInfo);
  SetProgress('visible', 'castor raw file information');
}
function FillCastorRawFileInfo() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = eval('(' + request.responseText + ')');
        var rows = response.files;
        FillTextFromArray('castorrawid', 'nfilcrid', rows);

        // We should call the next one here and so on
        RequestCastorEdmFileInfo();
      }
      catch (err) {
        alert ("FillCastorRawFileInfo: Error detail: " + err.message);
      }
    }
    else {
      alert("FillCastorRawFileInfo: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestCastorEdmFileInfo() {
  var run = GetSelectedValue('runlistid');
  var queryString = 'command=castoredm&run='+run;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillCastorEdmFileInfo);
  SetProgress('visible', 'castor edm file information');
}
function FillCastorEdmFileInfo() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = eval('(' + request.responseText + ')');
        var rows = response.files;
        FillTextFromArray('castoredmid', 'nfilceid', rows);

        // We should call the next one here and so on
        RequestDBSRawInfo();
      }
      catch (err) {
        alert ("FillCastorEdmFileInfo: Error detail: " + err.message);
      }
    }
    else {
      alert("FillCastorEdmFileInfo: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestDBSRawInfo() {
  var run = GetSelectedValue('runlistid');
  var queryString = 'command=dbsraw&run='+run;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillDBSRawInfo);
  SetProgress('visible', 'dbs information for edm');
}
function FillDBSRawInfo() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = request.responseText;
        FillText('dbsrawid', response);

        RequestDBSRecoInfo();
      }
      catch (err) {
        alert ("FillDBSRawInfo: Error detail: " + err.message);
      }
    }
    else {
      alert("FillDBSRawInfo: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestDBSRecoInfo() {
  var run = GetSelectedValue('runlistid');
  var queryString = 'command=dbsreco&run='+run;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillDBSRecoInfo);
  SetProgress('visible', 'dbs information for reco');
}
function FillDBSRecoInfo() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = request.responseText;
        FillText('dbsrecoid', response);

        // get update time
        RequestTimestampInfo();
      }
      catch (err) {
        alert ("FillDBSRecoInfo: Error detail: " + err.message);
      }
    }
    else {
      alert("FillDBSRecoInfo: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestTimestampInfo() {
  var run = GetSelectedValue('runlistid');
  var queryString = 'command=timestamp&run='+run;
  var url = BASE_URL+queryString;
  httpRequest("GET", url, true, FillTimestampInfo);
  SetProgress('visible', 'update time information');
}
function FillTimestampInfo() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        SetProgress('hidden');
        var response = request.responseText;
        var obj = document.getElementById('tslabelid');
        if (obj != null) obj.innerHTML = response;

        obj = document.getElementById('tsdivid');
        if (obj != null) obj.style.visibility = 'visible';

        // lastly set Autoupdate, if it is the most recent run
        if (IsOnline()) 
          autoUpdateTimerID = setTimeout('StartAutoUpdate()', autoUpdateInterval);
      }
      catch (err) {
        alert ("FillTimestampInfo: Error detail: " + err.message);
      }
    }
    else {
      alert("FillTimestampInfo: ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function FillTable(response) {
  var labels =
    new Array('runid', 
              'partitionid', 
              'runmodeid', 
              'starttimeid', 
              'stoptimeid', 
              'neventsid',
	      'statenameid', 
              'apvmodeid', 
              'fedmodeid', 
              'supermodeid', 
              'fedvid',
	      'fecvid', 
              'systemid');

  var values = response.split("\t");
  if (labels.length > values.length) {
    return;
  }
  for (var i = 0; i < labels.length; i++) {
    var obj = document.getElementById(labels[i]);
    if (obj != null) obj.innerHTML = values[i];
  }
}
function GetDetectorType() {
  return GetSelectedValue('dettagid');
}
function GetFilter() {
  return '?';
}
function getBaseURL() {
  var url = location.href;
  var indx = url.indexOf('//');
  var newurl;
  if (indx >-1)
    newurl = url.substring(indx+2,url.length);
  else
    newurl = url;

  a = newurl.split('/');
  if (indx >-1)
    url = url.substring(0,indx)+'//'+a[0];
  else
    url = a[0];

  return url;
}
function GetSelectedValue(id) {
  var obj = document.getElementById(id);
  if (obj == null || obj.selectedIndex<0) return '';
  var value = obj.options[obj.selectedIndex].value;

  return value;
}
function FillText(id, text) {
  var obj = document.getElementById(id);
  if (obj == null) return;
  if ("outerHTML" in obj) { // IE
    lines = text.split("\n");
    text = '';
    for (var i = 0; i < lines.length; i++) {
      text += lines[i] + '<br/>';
    }
  }
  obj.innerHTML = text;
}
function FillTextFromArray(tid, nid, rows) {
  var n = rows.length;
  var obj = document.getElementById(nid);
  if (obj == null) return;
  var cmnt = n + ' file';
  if (n > 1) cmnt += 's';
  obj.innerHTML = cmnt;

  obj = document.getElementById(tid);
  if (obj == null) return;

  var text = '';
  for (var i = 0; i < n; i++) {
    text += rows[i]; 
    if ("outerHTML" in obj) {
      text += '<br/>'; 
    }
    else {
      text += "\n";
    }
  }
  obj.innerHTML = text;
}
function SetProgress (option) {
  var progress = document.getElementById('progressbar');
  if (progress == null) return;
  var label = document.getElementById('datatypeid');
  if (label == null) return;
  var args = arguments[1]; 
  if (args != null && args.length > 0) { 
    label.innerHTML = args;
  } 
  progress.style.visibility = option; // "visible" or "hidden"
}
function StartAutoUpdate() {
  if (!IsOnline()) return;

  RequestRunInfo();
  autoUpdateTimerID = setTimeout('StartAutoUpdate()', autoUpdateInterval);
}
function StopAutoUpdate() {
  //if (!IsOnline()) return;
  if (autoUpdateTimerID != null) clearTimeout(autoUpdateTimerID);
  autoUpdateTimerID = null;
}
function IsOnline() {
  if (GetSelectedIndex('runlistid') == 0) return true;
  return false;
}
function GetSelectedIndex(id) {
  var obj = document.getElementById(id);
  if (obj == null) return -1;
  return obj.selectedIndex;
}
