
package config;

use strict;
use Getopt::Long;
use Cwd;

use YAML::Tiny;

sub getconfig {
    my $config = {};

    $config->{launch_directory} = getcwd();

    #  options on the command line override config file values.
    my $commandline_options = {};

    $commandline_options ->{sourcebranch} = '';
    $commandline_options ->{targetbranch} = 'master';

    my @imagelist;
    my $cstatus = GetOptions(
	"srcdir:s" => \$commandline_options->{srcdir},
	"configfile" => \$commandline_options->{configfile},

	"imagelist:s{,}" => \@imagelist,

	"all" => \$commandline_options->{all},
	"showdeps" => \$commandline_options->{showdeps},  # show dependancies in dockers.
	
	# Master is a special case.  All images are built and tagged with the
	# "master" tag. 
	"master" => \$commandline_options->{master},
	
	# build or dry run
	"build" => \$commandline_options->{build},        
	
	# post build, push the images to the registry (or not)
	"push" => \$commandline_options->{push},
	
	# pre build,  pull the images from the registry (or not)
	"pull" => \$commandline_options->{pull},
	
	# one script to run before all the docker builds.
	"pre-build-script:s" => \$commandline_options->{'pre-build-script'},
	
	# one script to run after all the docker builds.
	"post-build-script:s" => \$commandline_options->{'post-build-script'},
	
	# tag name to add to all images
	"tag:s" => \$commandline_options->{tag},
	
	# Use sourcebranch and targetbranch to determine what's changed.
	"targetbranch:s" => \$commandline_options->{targetbranch}, 
	"sourcebranch:s" => \$commandline_options->{sourcebranch},
	
	# set the build number here.
	"buildnumber:s" => \$commandline_options->{buildnumber},
	"verbose" => \$commandline_options->{verbose}
	);

    if (@imagelist) {
	$commandline_options->{imagelist} = \@imagelist;
    }

    die ("ERROR: options failed parse") unless $cstatus;


    # Config file location options.
    # We could get too clever here - so let

    # config file specified and it exists as is -- use it.


    # Order of config file search.
    # If it's named on the command line with --configfile  use that absolutely.  Fail if the file is not there.
    # If AUTODOCKER_CONFIGFILE is defined, use that, fail if the file does not exist.
    # 

    my $configfile = '';

    if ( -r $commandline_options->{configfile}) {
	$configfile = $commandline_options->{configfile};
	print "Using config file $configfile set by command line option \n";
    } else {
	
	if (-r $ENV{'AUTODOCKER_CONFIGFILE'}) {
	    $configfile = $ENV{'AUTODOCKER_CONFIGFILE'};
	    print "Using config file $ENV{'AUTODOCKER_CONFIGFILE'} set by environment variable AUTODOCKER_CONFIGFILE \n";
	} else {

	    if (-r $commandline_options->{srcdir}."/autodocker.yml") {
		$configfile = $commandline_options->{srcdir}."/autodocker.yml";
		print "Using config file $configfile from srcdir $config->{srcdir}  \n";
	    }  else {
		$configfile = 'autodocker.yml';  # In the current dir.
		print "Using config file $configfile from current dir. \n";
	    }
	}
    }
    
    my $config_file_options = {};
    if (-r $configfile) {

	my $yconfig = YAML::Tiny->read( $configfile )->[0];
	if ($yconfig) {
	    $config->{configfilefound} = 1;
	    foreach my $configitem (keys %{$yconfig}) {
		$config_file_options->{$configitem} = $yconfig->{$configitem};
	    }
	}
    }  else {
	print "No config file found.  Using default options\n";
    }




    # command line options override config file options.
    foreach my $configitem (keys %{$commandline_options},keys %{$config_file_options} ) {
	# if it was defined on the command line, over ride.
	$config->{$configitem} = $commandline_options->{$configitem} // $config_file_options->{$configitem} // undef;
    }


# docker-registry-address: localhost
# docker-registry-port: 5000

    print "Docker reg: $config->{'docker-registry-address'} $config->{'docker-registry-port'} \n";

    if ($config->{'docker-registry-address'} && $config->{'docker-registry-port'}) {
	$config->{PUSH_URL} =  $config->{'docker-registry-address'}.':'.$config->{'docker-registry-port'};
    } else {
	print "No docker registry defined. Pulls pushes and pulls are disabled. \n";
	$config->{PUSH} = 0;
	$config->{PULL} = 0;
    }

    if ($config->{master}) {
	$config->{all} = 1;
	$config->{sourcebranch} = 'master';
	$config->{pull} = 0;                  # build everything from scratch
	$config->{targetbranch} = '';         # this will disable git diffs
    }

    if (length($config->{srcdir}) == 0) {
	$config->{srcdir} = '.';
    }

    chdir($config->{srcdir});
    return $config;
}


1;
