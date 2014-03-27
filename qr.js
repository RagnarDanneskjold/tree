var fs = require('fs');
var qr = require('qrpng');

process.argv.forEach(function (val, index, array) {
	if ( index == 2 )
	{
	console.log(index + ': ' + val);

	qr( val, function(err, png) {
	  // png contains the PNG as a buffer. You can write it to a file for example.

		fs.writeFile("qr.png", png, function(err) {
			if(err) {
				console.log(err);
			} else {
				//console.log("The file was saved!");
			}
		}); 
	});
	}
});
