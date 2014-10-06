var Monitor = {
  refreshInterval: 120000, // 2 minutes
  refreshTimerID: null,
  getdoc: function() 
  {
    // request the global overview page
    Ext.Ajax.request({
      url: './overview.html',
      success: function(transport) {
        var adiv = document.createElement('div');
        adiv.innerHTML = transport.responseText;

        document.getElementById('overview').innerHTML 
          = adiv.getElementsByTagName('div')[0].innerHTML;
        JobView.init();

        // make the table sortables
        forEach(document.getElementsByTagName('table'), function(table) {
          if (table.className.search(/\bsortable\b/) != -1) {
            var id = table.getAttribute('id');
            if ( id != null && id.search(/\b(vo|ce|dn|user)-table\b/) != -1 ) 
              sorttable.makeSortable(table);
          }
        });
      },
      failure: function() {
        Ext.Msg.alert('Status', 'Unable to show LSF Global overview at this time, will try again soon.');
      }
    });
    // request the queue overview page
    Ext.Ajax.request({
      url: './overview.queue.html',
      success: function(transport) {
        var adiv = document.createElement('div');
        adiv.innerHTML = transport.responseText;

        document.getElementById('qoverview').innerHTML 
          = adiv.getElementsByTagName('div')[0].innerHTML;
        QueueView.init();

        // make the table sortables
        forEach(document.getElementsByTagName('table'), function(table) {
          if (table.className.search(/\bsortable\b/) != -1) {
            var id = table.getAttribute('id');
            if ( id != null && id.search(/\b(vo|ce|dn|user)-table\b/) != -1 ) 
              sorttable.makeSortable(table);
          }
        });
      },
      failure: function() {
        Ext.Msg.alert('Status', 'Unable to show LSF Queue overview at this time, will try again soon.');
      }
    });
  },
  StartAutoUpdate: function()
  {
    Monitor.refreshTimerID = setInterval('Monitor.getdoc()', Monitor.refreshInterval);
  },
  StopAutoUpdate: function() 
  {
    if (Monitor.refreshTimerID != null) clearInterval(Monitor.refreshTimerID);
    Monitor.refreshTimerID = null;
  }
};
Ext.onReady(function() {
  // basic tabs 1, built from existing content
  var tabs = new Ext.TabPanel({
           renderTo: 'tabs1',
              width: '100%',
          activeTab: 0,
         resizeTabs: true, // turn on tab resizing
        minTabWidth: 80,
           tabWidth: 110,
    enableTabScroll: true,
              frame: true,
           defaults: {autoHeight: true},
              items: [
                {contentEl: 'status',  title: 'Global Status'},
                {contentEl: 'qstatus', title: 'Queue Status'},
                {contentEl: 'l3hour',  title: 'Last 3 Hours'},
                {contentEl: 'l6hour',  title: 'Last 6 Hours'},
                {contentEl: 'l12hour', title: 'Last 12 Hours'},
                {contentEl: 'lday',    title: 'Last Day'},
                {contentEl: 'lweek',   title: 'Last Week'},
                {contentEl: 'lmonth',  title: 'Last Month'},
                {contentEl: 'l3month', title: 'Last 3 Months'},
                {contentEl: 'l6month', title: 'Last 6 Months'},
                {contentEl: 'lyear',   title: 'Last Year'},
                {contentEl: 'lfull',   title: 'Full Period'}
              ]
  });
  function handleActivate(tab) 
  {
    alert(tab.title + ' was activated.');
  }

  Monitor.getdoc();
  setTimeout('Monitor.StartAutoUpdate()', 10000);
});

