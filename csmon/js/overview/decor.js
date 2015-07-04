var Decor =
{
  msg: ''
};
Decor.setMessage = function(e) 
{
  Decor.msg = '<h2 style="color:#fff;"><img src="images/wait.gif" /> Loading help, please wait ...</h2>';
  return true;
}
$(document).ready(function() {
  $('body').css('font-size','0.9em');
  $('body,div,span,a,p,label,input,textarea').addClass('ui-widget');
  $('select,textarea,fieldset,p').addClass('ui-widget-content');
  $('div,fieldset').addClass('ui-corner-all');
  $('h2').addClass('ui-default-state')
         .addClass('ui-corner-all')
         .css('color', '#000');
  $('div.h-panel').addClass('ui-widget-header').css('font-weight', 'normal');
  $('div.h-panel label').css('font-size', '1.1em');
  // set icon
  $('p.msg_head img').attr('src','icons/toggleopen-small.gif').attr('alt', 'open/close');

  // show all of the element with class msg_body
  $('.msg_body').hide();

  // set action for 'expand/collapse' all
  $('p#showhide').click(function() {
    if ($(this).hasClass('expand')) {
      $('.msg_body').show();
      $(this).removeClass('expand').addClass('collapse').html('Collapse All');
      $('p.msg_head img').attr('src','icons/toggleclose-small.gif');
    }
    else {
      $('.msg_body').hide();
      $(this).removeClass('collapse').addClass('expand').html('Expand All');
      $('p.msg_head img').attr('src','icons/toggleopen-small.gif');
    }          
  });
  // toggle the componenet with class msg_body
  $('.msg_head').click(function(){
    $(this).next('.msg_body').slideToggle(600);
    var imgsrc = $('p.msg_head img').attr('src');
    (imgsrc == 'icons/toggleopen-small.gif') 
      ? $('p.msg_head img').attr('src','icons/toggleclose-small.gif')
      : $('p.msg_head img').attr('src','icons/toggleopen-small.gif');
  });

  $('a.htips').each(function(index) {
    $(this).cluetip({
              width: '520px', 
             height: '360px',
             sticky: true, 
      closePosition: 'title', 
             arrows: true, 
          showTitle: true,
         activation: 'click',
        hoverIntent: {
          sensitivity:   1,
             interval: 750,
              timeout: 750    
        },
                 fx: {             
                        open: 'fadeIn', // can be 'show' or 'slideDown' or 'fadeIn'
                   openSpeed: 'normal'
                 },
        onActivate: Decor.setMessage,
         ajaxCache: false
    });
  })
  $('#tab-a1,#tab-a2,#tab-a3')
    .css('height', '167px')  // Note the height set
    .css('overflow','auto');
  $('#tabpanel-a').tabs({ selected: 2 });
  $('#tabpanel-b').tabs({ selected: 1 });
  $('#tabpanel-a span').css('font-weight', 'normal');
  $('#tabpanel-b span').css('font-weight', 'normal');
  $('#news').load('news.html');
});
