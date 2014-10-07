var JobView = 
{
  setCPUImage: function() {
    var period = ''; 
    var args = arguments[0]; 
    if (args != null && args.length > 0) { 
      period = args;
    } 
    else {
      var form = document.getElementById('form1');
      if (form != null) {
        for (var i = 0; i < form.cpu.length; i++) {
          if (form.cpu[i].checked == true) period = form.cpu[i].value;
        }
      }
    }
    if (period == '') return;

    var cname = 'canvas-cpuusage';
    var canvas = document.getElementById(cname);
    if (canvas == null) return;

    var url = 'images/l' + period + '_cpuwtime.png';
    canvas.src = JobView.addRandom(url);
  },
  setJobImage: function() {
    var period = ''; 
    var args = arguments[0]; 
    if (args != null && args.length > 0) { 
      period = args;
    } 
    else {
      var form = document.getElementById('form1');
      if (form != null) {
        for (var i = 0; i < form.job.length; i++) {
          if (form.job[i].checked == true) period = form.job[i].value;
        }
      }
    }
    if (period == '') return;

    var cname = 'canvas-jobusage';
    var canvas = document.getElementById(cname);
    if (canvas == null) return;

    var url = 'images/l' + period + '_jobwtime';

    var sbox = document.getElementById('select-group');
    if (sbox != null) {
      var group = sbox.options[sbox.selectedIndex].value; 
      if (group != 'all') url += '_' + group;
    }
    url += '.png';
    canvas.src = JobView.addRandom(url);
  },
  addRandom:  function (url) {
    return (url + '?t='+Math.random());
  },
  init: function() {
    var sbox = document.getElementById('select-group');
    if (sbox != null) sbox.selectedIndex = 0;

    var form = document.getElementById('form1');
    if (form == null) return;
    form.cpu[1].checked = true;
    JobView.setCPUImage('day');
  
    form.job[1].checked = true;
    JobView.setJobImage('day');
  }
};
