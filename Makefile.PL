use strict;
use warnings;
use ExtUtils::MakeMaker;

#WriteMakefile(
#    NAME                => 'App::Framework',
#    AUTHOR              => 'Steve Price <sdprice@cpan.org>',
#    VERSION_FROM        => 'lib/App/Framework.pm',
#    ABSTRACT_FROM       => 'lib/App/Framework.pm',
#    ($ExtUtils::MakeMaker::VERSION >= 6.3002
#      ? ('LICENSE'=> 'perl')
#      : ()),
#    PL_FILES            => {},
#    PREREQ_PM => {
#        'Test::More' => 0,
#    },
#    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
#    clean               => { FILES => 'App-Framework-*' },
#);


use inc::Module::Install;
  
# Define metadata
name           'App-Framework';
all_from       'lib/App/Framework.pm';
author         'Steve Price <sdprice@cpan.org>';
  
# Specific dependencies
requires       'File::Spec'  => '0.80';
test_requires  'Test::More'  => '0.42';
##recommends     'Text::CSV_XS'=> '0.50';
##no_index       'directory'   => 'demos';
##install_script 'myscript';
  
WriteAll;
