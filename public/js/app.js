$(document).delegate("#phq9,#phq9-spanish", "pageinit", function() {
  $(this).find(':radio').click(function() {
    var total = 0,
      $page = $(this).closest('#phq9,#phq9-spanish');
    $page.find(':checked').each(function() { total += parseInt($(this).val(), 10); });
    $page.find('.totalSum').text("Score: " + total);
  });
});

$(document).delegate('#formulary', 'pageinit', function() {
  $(this).find('[data-type=search]').attr('autocomplete', 'off').attr('autocapitalize', 'off');
})



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
//     $('#menu, .pages').live("swipeleft", function () {
//         if (menuStatus) {
//             $(".ui-page-active").animate({
//                 marginLeft: "0px",
//             }, 300, function () {
//                 menuStatus = false
//             });
//         }
//     });
//  
//     $('.pages').live("swiperight", function () {
//         if (!menuStatus) {
//             $(".ui-page-active").animate({
//                 marginLeft: "165px",
//             }, 300, function () {
//                 menuStatus = true
//             });
//         }
//     });
//  
//     $('div[data-role="page"]').live('pagebeforeshow', function (event, ui) {
//         menuStatus = false;
//         $(".pages").css("margin-left", "0");
//     });
//  
//     // Menu behaviour
//     $("#menu li a").click(function () {
//         var p = $(this).parent();
//         if ($(p).hasClass('active')) {
//             $("#menu li").removeClass('active');
//         } else {
//             $("#menu li").removeClass('active');
//             $(p).addClass('active');
//         }
//     });
// });
//  
