#!/usr/bin/env perl
use strict;
use warnings;
use Mail::IMAPClient;
use MIME::Parser;
use IO::Socket::SSL;
use Digest::SHA3 qw( sha3_512_base64 );
use Net::SMTP;
use MIME::Lite;

# TODO
# multi coin based on COINS.TXT
# USER multi line or multi folder address allocation
# bitcoind/bitcoin-qt 0.9 accounting compliance testing

if ( int( $ARGV[0] ) )
{
	# throttle IMAP hammer in seconds
	sleep( $ARGV[0] );
}
my $PATH      = 'C:\BONSAI';
my $USER      = 'my@bonsaiwallet.com';
my $SMTP      = '127.0.0.1';
my $IMAP      = 'imap.gmail.com';
my $IMAP_USER = 'my@bonsaiwallet.com';
my $IMAP_PASS = ',>WuMeh8N!';
my $COIN      = "Bitcoin";
my $COIN_SYMB = "BTC";

my $socket = IO::Socket::SSL->new(
	PeerAddr => $IMAP,
	PeerPort => 993,
	Timeout  => 1,
	)
	or die "SSL socket(): $@";
my $client = Mail::IMAPClient->new(
	Socket   => $socket,
	User     => $IMAP_USER,
	Password => $IMAP_PASS,
	)
	or die "IMAPClient new(): $@";

if ( $client->IsAuthenticated() )
{
	$client->select("INBOX");
	my @unread = $client->unseen or warn "Could not find unseen msgs: $@\n";
	foreach my $seqno (@unread)
	{
		my ( $ack, $hashref, $email, $subject, $address );

		my $body_string = $client->body_string( $seqno );
		if ( $body_string =~ m/Reply to this message to/ )
		{
			$ack = 1;
		}

		$hashref = $client->parse_headers( $seqno, "From" );
		$$hashref{From}[0] =~ s/.*<|>.*//g;
		$email = lc( $$hashref{From}[0] );

		$hashref = $client->parse_headers( $seqno, "Subject" );
		$$hashref{Subject}[0] =~ s/.*<|>.*//g;
		$subject = $$hashref{Subject}[0];

		if ( email_valid( $email ) )
		{
			if ( $subject =~ m/register/i && ! -e "$PATH\\USER\\$email")
			{
				# register
				my $slurp = `node get_address.js $email`;
				$slurp =~ m/'(.*)'/;
				$address = $1;
				open( FILE, ">$PATH\\USER\\$email" );
				print FILE $address;
				close( FILE );
				`node send_from.js alpha\@cascorp.net $address 10`;
				`node qr.js $address`;
				`mogrify -sample 300 qr.png`;
				send_multipart_mail( $email, $address );
			}
			elsif( $subject =~ m/Confirm Transfer/i && $ack )
			{
				# acknolwedge send request and create transaction
				if ( $body_string =~ m/(T[a-f0-9]{32})/ )
				{
					if ( -e $PATH . '\PEND\\' . $1 )
						{
							open( ORD,$PATH . '\pending\\'.$1);
							my $order='';
							$order .= $_ while <ORD>;
							close( ORD );
							`rm -f $PATH\\pending\\$1`;
							chdir( $PATH );
							chomp( $order );
							my @do_send = split/\t/,$order;
							`node send_from.js $email $do_send[0] $do_send[1]`;
						}
				}
				else
				{
					error($email,  "Unable to confirm transfer. Body of confirmation containing authentication code not found." );
				}
			}
			elsif ( $subject =~ m/balance|deposit|help/i )
			{
				if ( -e "$PATH\\USER\\$email" )
				{
					my $check_balance = `node get_address_balance.js $email | sed -e 's/null //g'`;
					$check_balance =~ s/ |\n|\r//g;
					open( FILE, "$PATH\\USER\\$email" );
					my $address = <FILE>;
					chomp( $address );
					close( FILE );
					`node qr.js $address`;
					`mogrify -sample 300 qr.png`;
					balance( $email, $check_balance . " $COIN_SYMB", $address );
				}	
			}
			elsif ( $subject =~ m/send/i )
			{
				my $check_address = address_exists( $subject );
				my $check_email   = email_exists( $subject );

				if ( $check_address )
				{
					$address = $check_address;
				}
				elsif ( $check_email )
				{
					# TODO check for presence of coin currency in subject after QTY
					if ( -e  "$PATH\\USER\\$email" )
					{
						open( SEND_EMAIL_TO, "$PATH\\USER\\$address" );
						$address = <SEND_EMAIL_TO>;
						chomp( $address );
						close( SEND_EMAIL_TO );
					}
				}
				else
				{
					$address = qr_decde( $client->message_string($seqno) );
				}

				# send confirm email for valid user
				if ( $address && -e "$PATH\\USER\\$email" )
				{
					my $nonce = rand();
					my $time = time;
					my $qty = $subject;
					my @parts = split/ +/,$qty;
					$qty = $parts[1];
					$qty =~ s/[a-z]|[A-Z]| |://g;
					if ( $qty > 0 )
					{
						chdir( $PATH );
						my $check_balance = `node get_address_balance.js $email | sed -e 's/null //g'`;
						$check_balance =~ s/ |\n|\r//g;
						if ( ( $qty + 0.01 ) <= $check_balance )
						{
							printf( join("\t"), $email, $subject, $address, "\n" );
							my $digest = "T" . sha3_512_base64( $nonce . $time . $qty . $email );
							open( FILE, ">$PATH\\PEND\\$digest" ) or die ( $digest . ' ' . $@ );
							print FILE join( "\t", $address, $qty );
							close( FILE );
							send_multipart_mail_simple( $email, $address, $qty, $digest );
						}
						else
						{
							error($email, "<big>Insufficient Funds</big><br><br><b>Current balance:</b> $check_balance<br><br>Please note there are transaction fees from the $COIN network to empty your account." );
						}
					}
					else
					{
						error($email, "QTY not found in subject." );
					}
				}
				elsif ( -e "$PATH\\USER\\$email" )
				{
					error($email, "Address not found.");
				}
			}
			else
			{
				print "Commands not found in subject. Please try again.\n";
			}
		}
	}
}



# Say bye
$client->logout();



sub error
{
	my $to = shift;
	my $error = shift;
	my $smtp;

	if (not $smtp = Net::SMTP->new( $SMTP,
				    Port => 25,
				    Debug => 1)) {
	   die "Could not connect to server\n";
	}

	my $msg = MIME::Lite->new(
	    From    => $USER,
	    To      => $to,
	    Subject => 'Please Try Again',
	    Type    => 'multipart/mixed',
	);
	$msg->attach(
		Type => 'text/html',
		Data => qq{
		    <body><big>
			$error
		    </big></body>
		},
	);

	my $str = $msg->as_string;
	print $str;
	$smtp->mail( $USER . "\n" );
	$smtp->to( $to. "\n" );
	$smtp->data( );
	$smtp->datasend( $str );
	$smtp->dataend( );
	$smtp->quit;
}

sub balance 
{
	my $to      = shift;
	my $error   = shift;
	my $address = shift;
	my $smtp;

	if (not $smtp = Net::SMTP->new( $SMTP,
				    Port => 25,
				    Debug => 1)) {
	   die "Could not connect to server\n";
	}

	my $msg = MIME::Lite->new(
	    From    => $USER,
	    To      => $to,
	    Subject => 'Wallet Balance',
	    Type    => 'multipart/mixed',
	);
	$msg->attach(
		Type => 'text/html',
		Data => qq{
Balance: $error
<br><br>
Try these commands in the subject:
<ul>
<li>send QTY - attach photo of a QR code to send
<li>send QTY COIN EMAIL - transfer to another Bonsai Wallet (COIN = BTC, LTC, etc.)
<li>send QTY ADDRESS - if you don't have a QR code photo you can specify the address
<li>balance - provides your balance, deposit address, QR code and these instructions
</ul>
Deposit address is: $address
<br><br>
Deposit address QR code:
<br><br>
<img src="cid:png232323">
		},
	);
	$msg->attach(
	    Type     => 'image/png',
	    Path     => 'qr.png',
	    Filename => 'qr.png',
	    "Content-ID"=>'<png232323>'
	);

	my $str = $msg->as_string;
	print $str;
	$smtp->mail( $USER . "\n" );
	$smtp->to( $to. "\n" );
	$smtp->data( );
	$smtp->datasend( $str );
	$smtp->dataend( );
	$smtp->quit;
}



sub send_multipart_mail_simple
{
	my $to = shift;
	my $address = shift;
	my $amount = shift;
	my $md5 = shift;
	my $smtp;

	if (not $smtp = Net::SMTP->new( $SMTP,
				    Port => 25,
				    Debug => 1)) {
	   die "Could not connect to server\n";
	}

	my $msg = MIME::Lite->new(
	    From    => $USER,
	    To      => $to,
	    Subject => 'Confirm Transfer',
	    Type    => 'multipart/mixed',
	);
	$msg->attach(
		Type => 'text/html',
		Data => qq{
		    <body><big>
			Reply to this message to confirm by sending a blank email. By replying to this email you authorize sending the $COIN below.\n<br><br>  $md5 <br><br>
			Send $amount to $address
		    </big></body>
		},
	);

	my $str = $msg->as_string;
	print $str;
	$smtp->mail( $USER . "\n" );
	$smtp->to( $to. "\n" );
	$smtp->data( );
	$smtp->datasend( $str );
	$smtp->dataend( );
	$smtp->quit;
}



sub send_multipart_mail
{
	my $to = shift;
	my $address = shift;
	my $smtp;

	if (not $smtp = Net::SMTP->new( $SMTP,
				    Port => 25,
				    Debug => 1)) {
	   die "Could not connect to server\n";
	}

	my $msg = MIME::Lite->new(
	    From    => $USER,
	    To      => $to,
	    Subject => 'Registration Confirmed',
	    Type    => 'multipart/mixed',
	);
	$msg->attach(
		Type => 'text/html',
		Data => qq{
<b>Welcome to Bonsai Wallet!</b>
<br><br>
Balance: 0 $COIN_SYMB 
<br><br>
Try these commands in the subject:
<ul>
<li>send QTY - attach photo of a QR code to send
<li>send QTY COIN EMAIL - transfer to another Bonsai Wallet (COIN = BTC, LTC, etc.)
<li>send QTY ADDRESS - if you don't have a QR code photo you can specify the address
<li>balance - provides your balance, deposit address, QR code and these instructions
</ul>
Deposit address is: $address
<br><br>
Deposit address QR code:
<br><br>
<img src="cid:png232323">
		},
	);
	$msg->attach(
	    Type     => 'image/png',
	    Path     => 'qr.png',
	    Filename => 'qr.png',
	    "Content-ID" => "<png232323>"
    );

	my $str = $msg->as_string;
	print $str;
	$smtp->mail( $USER . "\n" );
	$smtp->to( $to. "\n" );
	$smtp->data( );
	$smtp->datasend( $str );
	$smtp->dataend( );
	$smtp->quit;
}
sub email_valid
{
	my $in = shift;
	if ( $in =~ m/^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/ )
	{
		return 1;
	}
	return 0;
}
sub email_extract
{
	my $in = shift;
	if ( $in =~ m/(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))/ )
	{
		my $out = join( '@', $2,$5);
		return $out;
	}
	return 0;
}
sub address_extract
{
	my $in = shift;
	# TODO support all coin prefixes (below is for Bitcoin only)
	if ( $in  =~ m/([1][1-9A-HJ-NP-Za-km-z]{26,33})/ )
	{
		return $1;
	}
	return 0;
}
sub qr_decode
{
	my $in = shift;
	my $out = 0;

	my $parser = MIME::Parser->new();
	$parser->output_dir( $PATH . '\IMGQ' );
	chdir( $PATH . '\IMGQ' );
	`rm -f *`;
	my $entity = $parser->parse_data( $in );
	`rm -f *.html`;
	`rm -f *.xml`;
	`rm -f *.txt`;

	# pre-process images
	`mogrify -contrast -contrast -contrast -contrast -contrast -contrast -contrast -colors 2 $PATH\\IMGQ\\*.*`;
	my $address_match = `"C:\\Program Files (x86)\\ZBar\\bin\\zbarimg" $PATH\\IMGQ\\*.*`;
	# TODO support all coin prefixes (below is for Bitcoin only)
	if ( $address_match =~ m/([1][1-9A-HJ-NP-Za-km-z]{26,33})/ )
	{
		$out = $1;
	}
	if ( ! $out )
	{
		`mogrify -resize 300  $PATH\\IMGQ\\*.*`;
		$address_match = `"C:\\Program Files (x86)\\ZBar\\bin\\zbarimg" $PATH\\IMGQ\\*.*`;
		# TODO support all coin prefixes (below is for Bitcoin only)
		if ( $address_match =~ m/([1][1-9A-HJ-NP-Za-km-z]{26,33})/ )
		{
			$out = $1;
		}
	}
	chdir( $PATH );
	return $out;
}
