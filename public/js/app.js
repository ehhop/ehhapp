// Some global variables to keep track of things.

var currentUsername = null;

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
  $('#file-input-target').trigger('click');
});

$(document).delegate("#file-input-target", "change", function() {
  var filename = $("#file-input-target").val().replace(/^.*[\\\/]/, '')
  var args = {'filename':filename};
  var numLI = $("#upload-list li").length
  $("#upload-list").append('<li> To incorporate ' + filename + ', use the following: ![Descriptive Text]('+ (numLI + 1) +')</li>');
  var targ = $("#file-input-target")
  targ.after('<input type="file" name="tmp-image" id="file-input-target" class="input-hide"/>')
  targ.attr('id', 'image'+(numLI+1))
  targ.attr('name', 'image'+(numLI+1))
  $("#upload-list").listview('refresh');
  $("form").attr( "enctype", "multipart/form-data" ).attr( "encoding", "multipart/form-data" );
});

//$('.input-file-button').on('click', function(){$('.input-file-button input[type=file]').trigger('click');})

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
