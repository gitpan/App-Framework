use strict;
use warnings;
use inc::Module::Install;
use File::Path ;
use Config;
  
# Define metadata
name            'App-Framework';
abstract_from	'lib/App/Framework.pm' ;
author_from		'lib/App/Framework.pm' ;
version_from	'lib/App/Framework.pm' ;
license_from	'lib/App/Framework.pm' ;
perl_version	'5.8.4' ;
##all_from       'lib/App/Framework.pm';
  
# Specific dependencies
requires       'Cwd'; 
requires       'File::Basename';
requires       'File::Path';
requires       'File::Temp';
requires       'File::Spec';
requires       'File::Find';
requires       'File::Copy';
requires       'File::DosGlob';
requires       'Pod::Usage'		=> 1.33 ;	# Need at least this version or -man won't work!
requires       'Date::Manip';
requires       'Getopt::Long';

recommends     'DBI' ;

test_requires  'Test::More'  => '0.42';
test_requires  'Test::Pod'  => '1.22';
test_requires  'Test::Pod::Coverage'  => '1.08';

no_index       'directory'   => 'examples';

##recommends     'Text::CSV_XS'=> '0.50';
##install_script 'myscript';


## create extra pod files
sub MY::postamble {

my $install = check_version() ;
if ($install)
{
	$install = 
"
install :: rm_oldinstall $install
	\$(NOECHO) \$(TOUCH) rm_oldinstall
";
}
else
{
	$install = "# null\n\n" ;
}

my $modpod = '
pure_all :: modpod

modpod: pm_to_blib $(TO_INST_PM)
	$(PERLRUN) -Mblib -MApp::Framework -e "modpod()"
	$(NOECHO) $(TOUCH) modpod
';

"$install\n\n$modpod\n";

}

## clean out old installation

WriteAll() ;


sub check_version
{
	my $remove = "" ;
	
	my $version ;
	eval {
		require App::Framework ;
		$version = $App::Framework::VERSION ;
	} ;
	if ($version && ($version < 0.90))
	{
		print "Need to clean existing installation\n" ;
		
		my @remove = (
			'Modules/*',
			'Modules', 
			'Base/Run.pm',
			'Base/Sql.pm',
			'Base/Object/Logged.pm',
			'Config.pm',
		) ;

		my @files ;
		my @dirs ;
		my $installsitelib = $Config{installsitelib} ;
		$installsitelib =~ s%\\%/%g ;
		foreach my $rm (@remove)
		{
			foreach my $f (glob("$installsitelib/App/Framework/$rm"))
			{
				if (-f $f)
				{
					push @files, $f ; 
				}
				if (-d $f)
				{
					push @dirs, $f ; 
				}
			}
		}
		
		## remove files first
		foreach my $f (@files)
		{
			$remove .= "\n\t\$(PERLRUN) -e \"unlink '$f'\"" ;
		}

		## remove dirs
		foreach my $d (@dirs)
		{
			$remove .= "\n\t\$(PERLRUN) -MFile::Path -e \"rmtree(['$d'])\"" ;
		}
	}

	return $remove ;
}