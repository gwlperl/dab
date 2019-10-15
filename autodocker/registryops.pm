
package registryops;

use strict;

#  add a tag like localhost:5000/app123:master

sub add_registry_to_tag {
    my $image = {};
    my $tag = shift or return undef;

    $tag =~s/\s+//g; # image tags never have white space.

    $image->{REGISTRY_ADDRESS} = $CONFIG::config->{'docker-registry-address'};
    $image->{REGISTRY_PORT} = $CONFIG::config->{'docker-registry-port'};

    my $newtag = $image->{REGISTRY_ADDRESS}.':'.$image->{REGISTRY_PORT}.'/'.$tag;
    return $newtag;
}

sub push_to_registry {
    my $docker = shift or return undef;
    my @output;
    foreach my $tag (@{$docker->{PUSHTAGLIST}}) {
	my $result = system("docker push $tag ");
	push @output,"push result for $tag  : $result";
    }
    $docker->{PUSH_TO_REGISTRY_LOG} = \@output;
}


sub pull_from_registry {
    my $docker = shift or return undef;
    my @output;
    my $result;

    $result = system("docker pull $docker->{PULLTAG} ");
    if ($result == 0) {
	$docker->{PULLED_IMAGE} = $docker->{PULLTAG};
	push @output, "Docker pull of $docker->{PULLTAG} succeeded with $result";
    } else {
	push @output, "Docker pull of $docker->{PULLTAG} failed with $result";
    }

    $docker->{PULL_FROM_REGISTRY_LOG} = \@output;
    return $result,\@output;
}

1;
