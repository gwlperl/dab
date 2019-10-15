

package dockertags;

use strict;
use File::Find;
use File::Spec;
use Cwd;

use gitops;

sub add_docker_tags {

    my $docker = shift or return undef;
    my $buildnumber = $CONFIG::config->{build_number} // buildops::get_build_number();

    my $gitbranch = gitops::git_current_branch();

    # Pull this image to build and cache from.
    my $lpulltag = $docker->{SERVICE_NAME}.":".$CONFIG::config->{build_against_tag};
    print "Adding $lpulltag as pulltag for docker $docker \n";

    $docker->{PULLTAG} = registryops::add_registry_to_tag($lpulltag);

    # This is the url to push it to the registry.

    $docker->{PUSHTAGLIST} = [];
    $docker->{LOCALTAGLIST} = [];

    # Tags for the local respository.

    if ($buildnumber) {
	push @{$docker->{LOCALTAGLIST}}, join ':',$docker->{SERVICE_NAME},sanitize_tag($buildnumber);
    }

    if ($CONFIG::config->{tag}) {
	print "Using TAG: $CONFIG::config->{tag} \n";
	push @{$docker->{LOCALTAGLIST}}, join ':',$docker->{SERVICE_NAME},sanitize_tag($CONFIG::config->{tag});
    }
    if ($CONFIG::config->{master}) {
	push @{$docker->{LOCALTAGLIST}}, join ':',$docker->{SERVICE_NAME},sanitize_tag('master');
    }


    # tags for the remote registry.
    # if there's no registry defined then don't create these tags.

    if ($CONFIG::config->{PUSH_URL}) {
	print "Adding pushtags  for $CONFIG::config->{PUSH_URL} \n";
	push @{$docker->{PUSHTAGLIST}}, $CONFIG::config->{PUSH_URL}.'/'.$docker->{SERVICE_NAME}.':'.sanitize_tag($buildnumber) if $buildnumber;
	push @{$docker->{PUSHTAGLIST}}, $CONFIG::config->{PUSH_URL}.'/'.$docker->{SERVICE_NAME}.':'.sanitize_tag($CONFIG::config->{tag}) if $CONFIG::config->{tag};
    }
}


# docker tags have all sorts of restrictions.
# The biggest is that slashes have special meaning.
# No double dots or dashes.  No .- or -.
# This function attempts to create a "usable" tag name based on a string (branch name).

sub sanitize_tag {
    my $branch = shift;

    return "nobranch" unless $branch;

    $branch =~ s|^refs/heads/||;
    $branch =~ s|^remotes/origin/||;
    $branch =~ s|/|-|g;
    $branch =~ s|\.+|.|g;
    $branch =~ s|\-+|-|g;
    $branch =~ s|[.-/]+|.|g;
    $branch =~ s|[-./]+|.|g;
    if (length($branch) < 1) {
	print "Setting branch to randombranch because branch $branch was less than zero in length \n";
	$branch = 'randombranch';
    }
    return $branch;
}





1;
