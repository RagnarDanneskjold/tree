tree v0.1
====

Tree is the software that powers the Bonsai Wallet automated Bitcoin e-mail payment system. Please use, change and contribute to this project as you see fit.

Installation
====

Network configuration
* Requires a dedicated IMAP account
* Requires access to an outbound SMTP relay (do not put this on the same machine as the Tree software)
* Tree must run on its own dedicated "banking terminal" machine that is not on the external Internet

Global Dependancies
* python 2.7
* perl 5.10 (ActivePerl windows with PPM is easiest)
* perl dependancies
  Mail::IMAPClient
  MIME::Parser
  IO::Socket::SSL
  Digest::SHA3
  Net::SMTP
  MIME::Lite
* node.js
* npm install bitcoin
* npm install qrpng
* ImageMagick: http://www.imagemagick.org/script/binary-releases.php
* ZBAR: http://zbar.sourceforge.net/

Linux Dependancies
* Install Perl dependencies via perl -MCPAN -e shell

Windows Dependancies
* Install Perl dependencies via ActivePerl Package Manager PPM
* Microsoft C++ 2010 Express (free) required for windows
