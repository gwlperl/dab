
package dockerops;

use strict;
use File::Find;
use File::Spec;
use Data::Dumper;
use Cwd;

use config;

# given a top directory, find all subdirs that contain dockerfiles.

sub find_docker_directories {

    my @directorylist;
    my $dockerhash = {};
    
    find ({wanted=>\&getdirs},".");

    foreach my $dockerdir (@directorylist) {

	my $thisdir = File::Spec->catfile($CONFIG::config->{srcdir},$dockerdir);
	my ($volume,$directories,$file) = File::Spec->splitpath( $dockerdir);

	my $servicename = $file;

	$dockerhash->{$servicename} = {};
	$dockerhash->{$servicename}->{'DIRECTORY_ABSOLUTE_PATH'} = $dockerdir;

	my $dockerfilename = $dockerdir.'/'.'Dockerfile';

	$dockerhash->{$servicename}->{'DOCKERFILE_ABSOLUTE_PATH'} = $dockerfilename;
	$dockerhash->{$servicename}->{DOCKERFROM} = getfrom($dockerfilename);
	my ($pre,$post) = dockerops::gethooks($dockerdir);
	$dockerhash->{$servicename}->{PREHOOKS} = $pre;
	$dockerhash->{$servicename}->{SERVICE_NAME} = $servicename;
	$dockerhash->{$servicename}->{POSTHOOKS} = $post;
    }

    return $dockerhash;

    sub getdirs {
	my $thisdir = getcwd();
	if (m/^Dockerfile$/) {
	    push @directorylist, $thisdir;
	}
    }

}

sub getfrom {
    my $file = shift or return undef;
    open (FROM, "< $file") or return undef;
    while (<FROM>) {
	chomp;
	my $line = $_;
	if ($line =~s/^FROM//) {
	    $line =~s/\s+//g;
	    close FROM;
	    return $line;
	}
    }
    close FROM;
    return undef;
}

# 

sub gethooks {
    my $fqn = shift or return undef;

    return undef unless -d $fqn;
    return undef unless opendir (BUILDDIR,$fqn);
    my $prehook = $CONFIG::config->{'pre-build-hook'};
    my $posthook = $CONFIG::config->{'post-build-hook'};

    my $prehooks = [];
    my $posthooks = [];

    while (my $file = readdir(BUILDDIR)) {
	if ($file=~m/^$prehook\d*$/) {
	    push @{$prehooks},$file;
	    next;
	}

	if ($file=~m/^$posthook\d*$/) {
	    push @{$posthooks},$file;
	    next;
	}
	
    }
    closedir(BUILDDDIR);
    return $prehooks,$posthooks;
}


1;
