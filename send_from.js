var bitcoin = require('bitcoin');

var client = new bitcoin.Client({
  host: 'localhost',
  port: 9332,
  user: 'litecoinrpc',
  pass: '58B65vFVLoo7GUcZwQ9LbJpTDpzKjMD9XYMDs7ZEJ13s'
});

var account;
var recipient;
var amount;
process.argv.forEach(function (val, index, array) {
	if ( index == 2)
	{
		account = val;
	}
	if ( index == 3)
	{
		recipient = val;
	}
	if ( index == 4)
	{
		amount = parseFloat( val );
	}
});

client.cmd('sendfrom', account, recipient, amount, 6, function(err, val ){
if (err) return console.log(err);
	//console.log('null', val);
});

