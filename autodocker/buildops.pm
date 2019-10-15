

package buildops;

use strict;
use Cwd;

use registryops;

sub check_build {
    my $build = shift or return undef;
}

sub run_hooks{
    my $build = shift or return undef;
    my $preorpost = shift;
    $preorpost = 'PREHOOKS' unless $preorpost;

    my $where = getcwd();  # save it so we can get back to where we were.    
    my @output;

    foreach my $script (@{$build->{$preorpost}}) {
	push @output, "Changing dir to $build->{DIRECTORY_ABSOLUTE_PATH}  ";
	chdir($build->{DIRECTORY_ABSOLUTE_PATH});

	if (-f $script) {
	    $script = './'.$script;
	    eval {
		if (open (RUNIT,"$script |")) {
		    push @output,"Running prehook script: $script  ";
		    while (<RUNIT>) {
			chomp;
			push @output,"$script $_ ";
		    }
		    close (RUNIT);
		    push @output,"End of script: $script  ";
		} else {
		    push @output, "Failed to open and run $script ";
		}
	    }
	} else {
	    push @output, "can not find $script -- huh? ";
	}
	chdir ($where);
    }
    chdir ($where);
    return \@output;
}

sub build_docker {
    
    my $docker = shift or return undef;
    print "Changing directory to: $docker->{DIRECTORY_ABSOLUTE_PATH} \n";
    chdir($docker->{DIRECTORY_ABSOLUTE_PATH});
    my @output;

    my $buildtagline = ' -t '.join ' -t ', @{$docker->{PUSHTAGLIST}},@{$docker->{LOCALTAGLIST}};
    $docker->{BUILDTAGLINE} = $buildtagline;
    my $docker_build_command = "docker build --progress plain ";

    if ($docker->{PULLED_IMAGE}) {
	$docker_build_command .= "--cache-from $docker->{PULLED_IMAGE} ";
    }

    $docker_build_command .= " $buildtagline -t $docker->{SERVICE_NAME}  .  ";
    print "Building docker with: $docker_build_command \n";
    
    my $success = system("$docker_build_command");

    if ($success == 0) {
	$docker->{BUILT} = 1;
	push @output, "Docker build of $docker->{SERVICE_NAME} succeeded ";
	my $pushed = registryops::push_to_registry($docker);

    } else {
	$docker->{BUILT} = 0;
	push @output, "ERROR: Docker build of $docker->{SERVICE_NAME} failed ";
    }
    return \@output;
}


sub discover_depenancies {
    my $dockers = shift;
    foreach my $docker (keys %{$dockers}) {
	buildops::get_from_list($dockers,$docker);
    }

    foreach my $docker (keys %{$dockers}) {
	buildops::get_docker_descendants($dockers,$docker);
    }
}

# Get the "from chain" for one docker.
# O(n^2) but the list is going to be small enough not to notice.

sub get_from_list {
    my $dockers = shift or return undef;
    my $service = shift;
    my @fromlist;
    my %fromhash;
    
    my $fromdocker = $dockers->{$service}->{DOCKERFROM};
    while ($fromdocker) {
	last unless $dockers->{$fromdocker};
	last unless $dockers->{$fromdocker}->{DOCKERFROM};
	unshift @fromlist,$fromdocker;
	$fromhash{$fromdocker} = 1;
	$fromdocker = $dockers->{$fromdocker}->{DOCKERFROM};
    }
    $dockers->{$service}->{FROMHASH} = \%fromhash;
    $dockers->{$service}->{FROMLIST} = \@fromlist;
    $dockers->{$service}->{FROMDEPTH} = $#fromlist +1;
}


# another horrible brute force O(n^2) hack.
sub get_docker_descendants {
    my $dockers = shift or return undef;
    my $service = shift or return undef;
    
    my @descendants;
    foreach my $docker ( keys %{$dockers}) {
	if (checkhash($dockers,[($docker,'FROMHASH',$service)])) {
	    push @descendants,$docker;
	}
    }
    $dockers->{$service}->{DESCENDENTS}  = \@descendants;
}


#
# Anything "after" or "under" a docker that's built also needs to be built
# 
sub mark_build_dependancies {
    my $dockers = shift or return undef;
    foreach my $docker (keys %{$dockers}) {
	if ($dockers->{$docker}->{NEEDS_BUILDING}) {
	    foreach my $prereq (@{$dockers->{$docker}->{DESCENDENTS}}) {
		$dockers->{$prereq}->{NEEDS_BUILDING} = 1;
		$dockers->{$prereq}->{BUILD_REASON} .= " descendent of $docker. ";
		$dockers->{$prereq}->{NEEDS_PULLING} = 1;
	    }
	    foreach my $pulldep (@{$dockers->{$docker}->{FROMLIST}}) {
		$dockers->{$pulldep}->{NEEDS_PULLING} = 1;
		# if we are not going to pull images, then build them.
		if (! $CONFIG::config->{pull}) {
		    $dockers->{$pulldep}->{NEEDS_BUILDING} = 1;
		    $dockers->{$pulldep}->{BUILD_REASON} .= " pull not set so building instead. ";
		}
	    }
	}
    }
}

# Perl autovivication.  Sure is fun.  Until someone puts an eye out.

sub checkhash {
    my( $hash, $keys ) = @_;
    
    return unless @$keys;
    foreach my $key ( @$keys ) {
	return unless eval { exists $hash->{$key} };
	$hash = $hash->{$key};
    }
    return 1;
}


sub docker_build_order {
    my $dockers = shift or return undef;
    my @build_order;
    foreach my $docker (sort {$dockers->{$a}->{FROMDEPTH} <=> $dockers->{$b}->{FROMDEPTH}} keys %{$dockers}) {
	push @build_order,$docker;
    }
    return \@build_order;
}

sub get_build_number {
    if ($CONFIG::config->{build_number}) {
	return $CONFIG::config->{build_number};
    } else {
	my $branch = gitops::git_current_branch();
	my $fbn = buildops::fake_build_number();
	my $bn = join '-',$branch,$fbn;
	return $bn;
    }

}

sub fake_build_number {
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
    $year += 1900;
    $mon  += 1;
    $mon =  sprintf("%02d",$mon);
    $mday = sprintf("%02d",$mday);
    my $end = ($hour*3600)+($min*60)+$sec;    
    return $year.$mon.$mday.'.'.$end;
}


    

1;
