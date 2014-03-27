var bitcoin = require('bitcoin');

var client = new bitcoin.Client({
  host: 'localhost',
  port: 8667,
  user: 'bonsai',
  pass: '1rdseQAYvWkPNRDus9EK9252qSJ1333'
});

process.argv.forEach(function (val, index, array) {
	if ( index == 2)
	{
      		//console.log(index + ': ' + val);
		client.getNewAddress( val, function( err, addy ){
 	 	if ( err ) return console.log( err );
			console.log( "'"+addy+"'" );
		});
	}
})

