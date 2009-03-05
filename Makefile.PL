use strict;
use warnings;
use inc::Module::Install;
  
# Define metadata
name           'App-Framework';
all_from       'lib/App/Framework.pm';
author         'Steve Price <sdprice@cpan.org>';
  
# Specific dependencies
requires       'Cwd'; 
requires       'File::Basename';
requires       'File::Path';
requires       'File::Temp';
requires       'File::Spec';
requires       'File::Find';
requires       'File::Copy';
requires       'File::DosGlob';
requires       'Pod::Usage';
requires       'Date::Manip';
requires       'Getopt::Long';

recommends     'DBI' ;

test_requires  'Test::More'  => '0.42';
test_requires  'Test::Pod'  => '1.22';
test_requires  'Test::Pod::Coverage'  => '1.08';

no_index       'directory'   => 'examples';

##recommends     'Text::CSV_XS'=> '0.50';
##install_script 'myscript';
  
WriteAll;
