// Some global variables to keep track of things.

var currentUsername = null;

// Utility function for inserting text at the caret in a textarea

function insertAtCaret(elem, text) {
  var txtarea = $(elem).get(0);
  var scrollPos = txtarea.scrollTop;
  var strPos = 0;
  var br = ((txtarea.selectionStart || txtarea.selectionStart == '0') ? 
    "ff" : (document.selection ? "ie" : false ) );
  if (br == "ie") { 
    txtarea.focus();
    var range = document.selection.createRange();
    range.moveStart ('character', -txtarea.value.length);
    strPos = range.text.length;
  }
  else if (br == "ff") strPos = txtarea.selectionStart;
  strPos = strPos || txtarea.value.length;

  var front = (txtarea.value).substring(0,strPos);  
  var back = (txtarea.value).substring(strPos,txtarea.value.length); 
  txtarea.value = front+text+back;
  strPos = strPos + text.length;
  if (br == "ie") { 
    txtarea.focus();
    var range = document.selection.createRange();
    range.moveStart('character', -txtarea.value.length);
    range.moveStart('character', strPos);
    range.moveEnd('character', 0);
    range.select();
  }
  else if (br == "ff") {
    txtarea.selectionStart = strPos;
    txtarea.selectionEnd = strPos;
    txtarea.focus();
  }
  txtarea.scrollTop = scrollPos;
}

// Detect if we are running fullscreen on an iPhone

function isFullScreen() {
  return window.navigator.userAgent.indexOf('iPhone') != -1 && window.navigator.standalone;
}

// If running fullscreen on an iPhone, use localStorage to restore to the last viewed page
// This is because everytime you switch into the website on a phone, it loses all state otherwise
// TODO: Besides which page was visible, we can also try to restore the position on the page.

if (isFullScreen() && window.localStorage) {
  $(document).one("pageinit", ".ui-page", function() {
    if (window.localStorage["lastPageVisited"]) {
      $.mobile.changePage(window.localStorage["lastPageVisited"]);
    }
  });
  $(document).on("pagechange", function(e) {
    window.localStorage["lastPageVisited"] = e.currentTarget.URL;
  });
  $(document).on("submit", function(e) {
    window.localStorage["lastPageVisited"] = '';
  });
}

// Specific for the editor:

$(document).delegate(".ui-page.editor", "pageinit", function() {
  var $page = $(this);
  console.log('hi');
  // Change the examples shown underneath the editor based on the template selected.
  $(this).find(".select-template").change(function() {
    var newTemplate = $(this).val();
    $page.find('.template-name').text(newTemplate);
    $page.find('.examples-active').fadeOut(function() {
      $(this).removeClass('examples-active');
      $page.find('.examples-'+newTemplate).addClass('examples-active').fadeIn();
    });
  });
  // Scroll the uploaded images list all the way to the right.
  $(this).find('.add-image-collapsible').click(function() {
    $page.find('.upload-list').scrollLeft(1000000);
  });
});

// Page-specific logic goes here.

// This updates the score for the PHQ-9, GAD-7, etc.
$(document).delegate(".ui-page:has(.assessment-form)", "pageinit", function() {
  var $page = $(this);
  $page.find(":radio").click(function() {
    var total = 0;
    $page.find(":checked").each(function() { total += parseInt($(this).val(), 10); });
    $page.find(".total-sum").text("Score: " + total);
  });
});

$(document).delegate(".ui-page:has(.formulary-list)", "pageinit", function() {
  $(this).find("[data-type=search]").attr("autocomplete", "off").attr("autocapitalize", "off");
});

// A method for removing ALL cached pages from the DOM.
// This is useful if the user does something like logging in or out that changes the content
// of all of them at once.
$(document).delegate(".ui-page", "cleardomcache", function() {
  $(this).siblings('.ui-page:not(.ui-page-active)').remove();
});

// This function takes care of changes in authentication state.
$(document).delegate(".ui-page", "pageinit", function() {
  // If there was an authentication flash message, show it but set a timer to fade it out after
  // 5 seconds.  Also, clear the DOM cache, since the authentication state has changed.
  var $flash = $(this).find(".auth-flash"),
    newCurrentUsername = $(this).data('current-username');
  if ($flash.length) {
    setTimeout(function() { $flash.fadeOut(); }, 5000);
    $(this).trigger("cleardomcache");
  } else {
    // If the username has changed on the new page, a login/logout event must have occurred.
    // This also requires us to clear the DOM cache.
    if (currentUsername !== null && currentUsername !== newCurrentUsername) {
      console.log(currentUsername, newCurrentUsername);
      $(this).trigger("cleardomcache");
    }
    currentUsername = newCurrentUsername;
  }
});

// Whenever the user tries to login, explode all cached pages
$(document).delegate(".login-form", "submit", function() {
  $(this).closest(".ui-page").trigger("cleardomcache");
});

//$('ul.history-list').listview()
$(document).delegate(".history-btn", "click", function() {
  window.location.replace("/"+page_name+"/history?commit="+this.id);
return false;});

$(document).delegate("#history-more-btn", "click", function(e) {
  if($('.history-btn').length != 0){
    head_id = $('.history-btn').last()[0].id
    $.post("/"+page_name+"/history", $.param({head: head_id}), function(res){
      for (var i = 0; i < res.result.length; i++) {
        commit = res.result[i];
        console.log(commit)
        $li = $("<li>");
        if(commit.new_file){
          $btn = $("<button>", {'id':commit.id, 'class':'history-btn', 'data-theme':'a'});
          $('#history-more-btn').closest('li').remove()
        }else{
          $btn = $("<button>", {'id':commit.id, 'class':'history-btn'});
        }
        $btn.append("Editor: <span class='button-secondary'>" + commit.author + "</span>")
        $btn.append("Edited: <span class='button-secondary'>" + commit.authored + "</span><br/>")
        $btn.append("Commiter: <span class='button-secondary'>" + commit.commiter + "</span>")
        $btn.append("Committed: <span class='button-secondary'>" + commit.commited + "</span>")
        $li.append($btn)
        $('.history-btn').last().closest('li').after($li)
        $btn.button().button('refresh')
        //$('ul.history-list').listview('refresh');
      }
    }).fail(function(){console.log("more history error...");});
  }
  e.preventDefault();
});

// File input related stuff
$(document).delegate(".input-file-button", "click", function() {
  $(this).closest('form').find('.file-input-target').trigger('click');
});

$(document).delegate(".file-input-target", "change", function() {
  var filename = $(this).val().replace(/^.*[\\\/]/, ''),
    $form = $(this).closest('form'),
    $ul = $form.find(".upload-list"),
    numNewUploads = $ul.children('.new-upload').length + 1,
    $li = $('<li class="new-upload"/>').insertBefore($ul.find('.input-file-button').closest('li')),
    $a = $('<a data-role="button" data-shadow="false" class="insert-image"/>').appendTo($li);
  $a.button().data('img-href', numNewUploads.toString());
  $(this).after('<input type="file" name="tmp-image" class="file-input-target input-hide"/>');
  $(this).attr('name', 'upload' + numNewUploads).removeClass('file-input-target');
  if (FileReader) {
    var file = $(this).get(0).files[0],
      extension = file.name.split('.').pop();
    if (file.type.match(/image.*/)) {
      var reader = new FileReader();
      reader.onload = function(e) {
        var img = new Image();
        img.src = reader.result;
        $a.find('.ui-btn-text').append(img);
        $form.find('.upload-list').scrollLeft(1000000);
      }
      reader.readAsDataURL(file); 
    } else {
      var $img = $('<img class="file-icon"/>').attr('src', '/images/icons/' + extension + ".png"),
        $span = $('<span class="file-name"/>').text(file.name);
      $a.data('is-file', true);
      $a.find('.ui-btn-text').append($img).append($span);
    }
    $a.data('img-basename', file.name.replace(/([^.]+)\.\w+$/, '$1')).click();
  }
});

$(document).delegate(".insert-image", "click", function() {
  var $a = $(this),
    $form = $a.closest('form'),
    href = $a.data('img-href') || $a.find('img').eq(0).attr('src'),
    basename = $a.data('img-basename') || href.replace(/^.*[\\\/]/, ''),
    imgBang = $a.data('is-file') ? '' : '!';
  insertAtCaret($form.find('.mdown-editor'), imgBang + '['+basename+']('+href+')');
});

// Whenever the user clicks a back button in the top toolbar,
// if it would actually take us to the last page in history,
// perform that action instead.

$(document).delegate(".ui-header .ui-btn-left", "click", function(e) {
  var $link = $(this),
    prevHistory = $.mobile.urlHistory.getPrev(),
    prevScroll = (prevHistory && prevHistory.lastScroll) || 0;
  if ($link.is( ":jqmData(rel='back')")) { return; }
  if (prevHistory && $link.attr("href") == prevHistory.url) {
    e.preventDefault();
    e.stopPropagation();
    $.mobile.back();
    // TODO:
    // We should really just explode this and have it be so that going to any page
    // will scroll the page to the right position, assuming it was already loaded
    // and we have a prevScroll for it in $.mobile.urlHistory
    
    // The following is supposed to be accomplished by jQM itself:
    // $(document).one('pagechange', function() { window.scrollTop(prevScroll); });
    // There's some problem here where certain browsers (Chrome) don't restore
    // the prevScroll into window.scrollY, and hang in a state where they are
    // aware they are "supposed" to be at lastScroll (any scroll events "jump")
    // them to the right position but that is not what is painted.  IDK.
  }
});

// // Whenever the user edits the page, remove the editor page after the next page loads (as it is out of date)
// $(document).delegate(".editor-form", "submit", function() {
//   var $page = $(this).closest('.ui-page');
//   $(document).one("pageinit", ".ui-page", function() { if (this !== $page.get(0)) { $page.remove(); } });
// });
