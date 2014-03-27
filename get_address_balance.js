var bitcoin = require('bitcoin');

var client = new bitcoin.Client({
  host: 'localhost',
  port: 9332,
  user: 'litecoinrpc',
  pass: '58B65vFVLoo7GUcZwQ9LbJpTDpzKjMD9XYMDs7ZEJ13s'
});


process.argv.forEach(function (val, index, array) {
	if ( index == 2)
	{
		client.cmd('getbalance', val, 6, function(err, balance){
 	 	if (err) return console.log(err);
			console.log('null', balance);
		});
	}
})
