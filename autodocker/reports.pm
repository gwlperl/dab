

package reports;

use strict;
use Data::Dumper;
use Cwd;

sub show_dockers {
    my $dockers = shift or return undef;

    foreach my $docker (keys %{$dockers}) {
	print "$docker:  \n";
	print "   FROM:           $dockers->{$docker}->{DOCKERFROM} \n";
	print "   NEEDS_BUILDING: $dockers->{$docker}->{NEEDS_BUILDING}\n";
	print "\n";
    }
}

sub show_config {

    print "Docker build Configuration \n\n";
    foreach my $key (sort  {$a <=> $b} keys $CONFIG::config) {
	print "  $key -> $CONFIG::config->{$key} \n";
    }
    print "\n\n";
}


sub post_build_report {
    my $dockers = shift or return undef;
    my $success = 1;  
    
    print "Build report for all dockers \n\n";
    foreach my $docker (@{$CONFIG::config->{'build_order'}}) {
	if ($dockers->{$docker}->{BUILT}) {
	    print "$docker build succeeded \n";
	} else {
	    print "$docker build failed. \n";
	    $success = 0;
	}
    }
    return $success;
}


1;
