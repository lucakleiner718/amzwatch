// This is a manifest file that'll be compiled into application.js, which will include all the files
// listed below.
//
// Any JavaScript/Coffee file within this directory, lib/assets/javascripts, vendor/assets/javascripts,
// or any plugin's vendor/assets/javascripts directory can be referenced here using a relative path.
//
// It's not advisable to add code directly here, but if you do, it'll appear at the bottom of the
// compiled file.
//
// Read Sprockets README (https://github.com/rails/sprockets#sprockets-directives) for details
// about supported directives.
//
//= require jquery
//= require jquery_ujs
//- require turbolinks

//= require bootstrap/js/bootstrap.min
//= require plupload/js/plupload.full.min.js
//= require plupload/js/moxie.min.js
//= require progressbar/progressbar.js
//= require jquery-ui
//= require datatable/media/js/jquery.dataTables.min.js
//= require moment/moment-with-locales.min.js
//= require canvasjs/jquery.canvasjs.min.js
//= require_self

Array.prototype.max = function(callback) {
  var max;
  for(var i=0; i<this.length; i++) {
    var val = callback(this[i]);
    if (max == null) {
      max = val;
    } else if (val > max) {
      max = val;
    }
  }

  return max;
}

Array.prototype.min = function(callback) {
  var min;
  for(var i=0; i<this.length; i++) {
    var val = callback(this[i]);
    if (min == null) {
      min = val;
    } else if (val < min) {
      min = val;
    }
  }

  return min;
}