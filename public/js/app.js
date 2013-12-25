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
}

// Specific for the editor:

$(document).delegate(".ui-page.editor", "pageinit", function() {
  var $page = $(this);
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

$(document).delegate("#phq9, #phq9-spanish", "pageinit", function() {
  $(this).find(":radio").click(function() {
    var total = 0,
      $page = $(this).closest("#phq9, #phq9-spanish");
    $page.find(":checked").each(function() { total += parseInt($(this).val(), 10); });
    $page.find(".totalSum").text("Score: " + total);
  });
});

$(document).delegate("#formulary", "pageinit", function() {
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

// File input related stuff
$(document).delegate(".input-file-button", "click", function() {
  $(this).closest('form').find('.file-input-target').trigger('click');
});

$(document).delegate(".file-input-target", "change", function() {
  var filename = $(this).val().replace(/^.*[\\\/]/, ''),
    $form = $(this).closest('form'),
    $ul = $form.find(".upload-list"),
    numNewImages = $ul.children('.new-image').length + 1,
    $li = $('<li class="new-image"/>').insertBefore($ul.find('.input-file-button').closest('li')),
    $a = $('<a data-role="button" data-shadow="false" class="insert-image"/>').appendTo($li);
  $a.button().data('img-href', numNewImages.toString()).click();
  $(this).after('<input type="file" name="tmp-image" class="file-input-target input-hide"/>');
  $(this).attr('name', 'image' + numNewImages).removeClass('file-input-target');
  if (FileReader) {
    var file = $(this).get(0).files[0];
    if (file.type.match(/image.*/)) {
      var reader = new FileReader();
      reader.onload = function(e) {
        var img = new Image();
        img.src = reader.result;
        $a.find('.ui-btn-text').append(img);
      }
      reader.readAsDataURL(file); 
    }
  }
});

$(document).delegate(".insert-image", "click", function() {
  var $form = $(this).closest('form'),
    href = $(this).data('img-href') || $(this).find('img').eq(0).attr('src'),
    basename = href.replace(/^.*[\\\/]/, '');
  insertAtCaret($form.find('.mdown-editor'), '![Description for '+basename+']('+href+')');
});

// // Whenever the user edits the page, remove the editor page after the next page loads (as it is out of date)
// $(document).delegate(".editor-form", "submit", function() {
//   var $page = $(this).closest('.ui-page');
//   $(document).one("pageinit", ".ui-page", function() { if (this !== $page.get(0)) { $page.remove(); } });
// });


// $(document).bind("mobileinit", function () {
//     $.mobile.pushStateEnabled = true;
// });
//  
// $(function () {
//     var menuStatus;
//  
//     // Show menu
//     $("a.showMenu").click(function () {
//         if (menuStatus != true) {
//             $(".ui-page-active").animate({
//                 marginLeft: "165px",
//             }, 300, function () {
//                 menuStatus = true
//             });
//             return false;
//         } else {
//             $(".ui-page-active").animate({
//                 marginLeft: "0px",
//             }, 300, function () {
//                 menuStatus = false
//             });
//             return false;
//         }
//     });
//  
//  
//     $("#menu, .pages").live("swipeleft", function () {
//         if (menuStatus) {
//             $(".ui-page-active").animate({
//                 marginLeft: "0px",
//             }, 300, function () {
//                 menuStatus = false
//             });
//         }
//     });
//  
//     $(".pages").live("swiperight", function () {
//         if (!menuStatus) {
//             $(".ui-page-active").animate({
//                 marginLeft: "165px",
//             }, 300, function () {
//                 menuStatus = true
//             });
//         }
//     });
//  
//     $("div[data-role="page"]").live("pagebeforeshow", function (event, ui) {
//         menuStatus = false;
//         $(".pages").css("margin-left", "0");
//     });
//  
//     // Menu behaviour
//     $("#menu li a").click(function () {
//         var p = $(this).parent();
//         if ($(p).hasClass("active")) {
//             $("#menu li").removeClass("active");
//         } else {
//             $("#menu li").removeClass("active");
//             $(p).addClass("active");
//         }
//     });
// });
//  
