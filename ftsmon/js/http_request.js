var request  = null; 
var BASE_URL = getBaseURL()+'/cgi-bin/ftsmon/monitor.pl?';
var DEBUG    = false;
var SEC2MS   = 1000;
var MIN2SEC  = 60;
var autoUpdateInterval = 3*MIN2SEC*SEC2MS;  // 2 mins
var autoUpdateTimerID  = null;

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
        "initReq: The application cannot contact " + 
        "the server at the moment. " + 
        "Please try again in a few seconds.\\n" + 
        "Error detail: " + errv.message); 
  } 
}
//input field's event handlers 
window.onload=function() { 
  initTabs('dhtmlgoodies_tabView1', Array('Status Info','Storage Info'), 0, '99.5%','100%');
  RequestChannelList();
}
window.onunload=function() { 
  StopAutoUpdate();
}
window.onresize = scale;
function SetSelectedIndex(element_id, index) {
  var obj = document.getElementById(element_id);
  if (obj == null) {
    alert('ERROR. section box with id = ' + element_id + ' not found!');
    return;
  }
  obj.selectedIndex = index;
}
function GetSelectItem(element_id) {
  var obj = document.getElementById(element_id);
  if (obj == null) {
    alert('ERROR. section box with id = ' + element_id + ' not found!');
    return '';
  }
  var index = obj.selectedIndex;
  if (index < 0) {
    if (DEBUG) alert('ERROR. no items selected, index = ' + index);
    return '';
  }
  return obj.options[index].value;
}
function GetState() {
  var st  = '';
  var obj = document.getElementById('submittedcb');
  if (obj != null && obj.checked) st += '&state=Submitted';

  obj = document.getElementById('pendingcb');
  if (obj != null && obj.checked) st += '&state=Pending';

  obj = document.getElementById('activecb');
  if (obj != null && obj.checked) st += '&state=Active';

  return st;
}
function GetChannel() {
  return '&channel='+GetSelectItem('channelid');
}
function RequestChannelList() {
  var queryString = 'command=channellist'+GetState()+'&t='+Math.random();
  var url = BASE_URL+queryString; 
  httpRequest("GET", url, true, FillChannelList); 
  ClearSelectBox('channelid');
  ClearSelectBox('fileid');
  ClearSelectBox('jobid');
}
function FillChannelList() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        var doc = request.responseXML;
        var root = doc.documentElement;
        var rows = root.getElementsByTagName('channel');
        FillSelectBox(rows, 'channelid', -1);
        StartAutoUpdate();
      }
      catch (err) {
        alert ("FillChannelList: Error detail: " + err.message); 
      }
    } 
    else {
      alert("FillChannelList:  ERROR:"+request.readyState+", "+request.status); 
    }
  }
}
function RequestTimestamp() {
  var queryString = 'command=timestamp&t='+Math.random();
  var url = BASE_URL+queryString; 
  httpRequest('GET', url, true, FillTimestamp); 
}
function FillTimestamp() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        var text = request.responseText;
        UpdateTimestamp(text);
      }
      catch (err) {
        alert ("FillTimestamp: Error detail: " + err.message);
      }
    }
    else {
      alert("FillTimestamp:  ERROR:"+request.readyState+", "+request.status);
    }
  }
}
function RequestJobList() { 
  var queryString = 'command=joblist'+GetState()+GetChannel()+'&t='+Math.random();
  var url = BASE_URL+queryString; 
  httpRequest('GET', url, true, FillJobList); 
} 
function FillJobList() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        var doc = request.responseXML;
        var root = doc.documentElement;
        var rows = root.getElementsByTagName('job');
        FillSelectBox(rows, 'jobid', -1);
      }
      catch (err) {
        alert ("FillJobList: Error detail: " + err.message); 
      }
    } 
    else {
      alert("FillJobList:  ERROR:"+request.readyState+", "+request.status); 
    }
  }
}
function RequestFileList() { 
  var queryString = 'command=filelist&jobid='+GetSelectItem('jobid')+'&t='+Math.random();
  var url = BASE_URL+queryString; 
  httpRequest('GET', url, true, FillFileList); 
} 
function FillFileList() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        var doc = request.responseXML;
        var root = doc.documentElement;

        // First of all, fill information on the request ID
        var labels = new Array('channel', 'dn', 'submitted', 'status', 'voname', 'nfiles', 'priority');
        var tags =   new Array('channelName', 'clientDN',  'submitTime', 
                               'jobStatus', 'voName', 'numFiles', 'priority');
        FillTableInfo(doc, labels, tags);

        // Fill the file list select box
        var rows = root.getElementsByTagName('file');
        FillSelectBox(rows, 'fileid', -1);

        // Finally show the number of files present in the collection
        ShowNFiles(rows.length);
      }
      catch (err) {
        alert ("FillFileList: Error detail: " + err.message); 
      }
    } 
    else {
      alert("FillFileList:  ERROR:"+request.readyState+", "+request.status); 
    }
  }
}
function RequestFileStatus() { 
  var queryString = 'command=filestatus';

  // File name
  var fid = GetSelectItem('fileid');
  var arr = fid.split(" [");
  if (arr.length>1) fid = arr[0];
  if (fid == null && fid.length == 0) return;
  queryString += '&filename='+fid;

  // Job ID (needed to identify a file uniquely)
  var jid = GetSelectItem('jobid');
  if (jid.length == 0 ) {
    var narr = arr[1].split(':');
    if (narr.length>1) jid = narr[0];
  }
  queryString += '&jobid='+jid;  

  url = BASE_URL+queryString + '&t='+Math.random();
  httpRequest('GET', url, true, FillFileStatus); 
} 
function FillFileStatus() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        var doc = request.responseXML;
        var labels = new Array('source', 'dest', 'state', 'duration', 'nfail', 'reason',
                               'path', 'pool','lupdate','progress','rate', 'tstatus', 'pnfsid',
                               'door','rhost', 'user');
        var tags   = new Array('sourceSURL', 'destSURL',  'transferFileState', 'duration', 
                               'numFailures', 'reason', 'Path', 'Pool', 'Since',
                               'Progress', 'Rate', 'Status', 'PnfsId', 'Door','RemoteHost', 'User');
        FillTableInfo(doc, labels, tags);
      }
      catch (err) {
        alert ("FillFileStatus: Error detail: " + err.message); 
      }
    } 
    else {
      alert("FillFileStatus:  ERROR:"+request.readyState+", "+request.status); 
    }
  }
}
function FillSelectBox(rows, destObj, index) {
  // Run number select box
  var obj = document.getElementById(destObj);
  if (obj == null) {
    alert('Run option Object, '+destObj+ ' not found!');
    return;
  }
  obj.options.length = 0;

  for (var i = 0; i < rows.length; i++) {
    var name   = rows[i].childNodes[0].nodeValue;
    var option = new Option(name, name);
    try {
      obj.add(option, null);
    }
    catch (e) {
      obj.add(option, -1);
    }
  }
  if (index > -1 && index < obj.options.length) 
    obj.options[index].selected = true;
}
function FillTableInfo(doc, labels, tags) {
  var root = doc.documentElement;
  for (var i = 0; i < tags.length; i++) {
    var name = '';
    var rows = root.getElementsByTagName(tags[i]);
    if (rows.length > 0) {
      var name = rows[0].childNodes[0].nodeValue;
      name = name.replace('<', '&lt;');
      name = name.replace('>', '&gt;');
    }
    var obj = document.getElementById(labels[i]);
    if (obj != null) obj.innerHTML = BreakLine(name, 120);
  }
}
function BreakLine(name, at) {
  var len = name.length;
  if (len <= at) return name;
  var newname = name.substring(0,at);
  do {
    name = name.substring(at);
    len  = name.length;
    if (len <= at) at = len;
    newname += '<br/>' + name.substr(0,at);
  }
  while (len>at);

  return newname;
}
function ClearSelectBox(destObj) {
  // Run number select box
  var obj = document.getElementById(destObj);
  if (obj == null) {
    alert('Select box object, '+destObj+ ' not found!');
    return;
  }
  obj.options.length = 0;
}
function UpdateTimestamp(text) {
  var label = document.getElementById('lastupdate');
  if (label != null) {
    label.innerHTML = text;
  }
}
function StopAutoUpdate() {
  if (autoUpdateTimerID != null) {
    clearTimeout(autoUpdateTimerID); 
  }
}
function StartAutoUpdate() {
  RequestTimestamp();
  if (GetSelectItem('fileid').length != 0)
    setTimeout('RequestFileStatus()', 10*SEC2MS);

  autoUpdateTimerID = setTimeout('StartAutoUpdate()', autoUpdateInterval);
}
function GetRadioItem() {
  var index = -1; 
  for (var i = 0; i < document.Form1.allstaterb[i].length; i++) {
    if (document.Form1.allstaterb[i].checked == true) index = i;
  }
  return index;
}
function RequestAllFiles(state) {
  SetSelectedIndex('jobid', -1);
  var queryString = 'command=allfiles&state='+state+'&t='+Math.random();
  var url = BASE_URL+queryString; 
  httpRequest('GET', url, true, FillAllFileList); 
} 
function FillAllFileList() {
  if (request.readyState == 4) {
    if (request.status == 200) {
      try {
        var doc  = request.responseXML;
        var root = doc.documentElement;

        var rows = root.getElementsByTagName('file');
        FillSelectBox(rows, 'fileid', -1);

        // Finally show the number of files present in the collection
        ShowNFiles(rows.length);
      }
      catch (err) {
        if (DEBUG) alert ("FillAllFileList: Error detail: " + err.message); 
      }
    } 
    else {
      alert("FillAllFileList:  ERROR:"+request.readyState+", "+request.status); 
    }
  }
}
function ShowNFiles(n) {
  // Finally show the number of files present in the collection
  var obj = document.getElementById('fileentries');
  if (obj) {
    obj.innerHTML = n;
  }
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
