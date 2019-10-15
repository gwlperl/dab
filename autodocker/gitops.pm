# 
package gitops;

use strict;
use Cwd;

sub get_git_diffs {
    my $gitdiffs = [];

    if (($CONFIG::config->{sourcebranch}) && ($CONFIG::config->{targetbranch})) {
	print "SOURCE: $CONFIG::config->{sourcebranch} \n";
	print "TARGET: $CONFIG::config->{targetbranch} \n";
    } else {
	return undef;	
    }

    open (GITDIFF, "git diff --name-only $CONFIG::config->{sourcebranch}..$CONFIG::config->{targetbranch} |");

    my $top = gitroot();
    while (<GITDIFF>) {
	chomp;
	push @{$gitdiffs},join '/',$top,$_;
    }
    close (GITDIFF);
    return $gitdiffs;
}

# More brut force O(n^2).  

sub get_git_changes {
    my $dockers = shift or return undef;

    if (gitops::grok_git_branch()) {
	print "Checkout to source branch: $CONFIG::config->{sourcebranch} succeeded. \n";
    } else {
	print "Checkout to $CONFIG::config->{sourcebranch} failed. \n";
	return undef;
    }

    my $gitdiffs = gitops::get_git_diffs();

    return undef unless $gitdiffs;

    my $filehash = {};
    foreach my $docker (keys %{$dockers}) {
	$filehash->{$dockers->{$docker}->{DIRECTORY_ABSOLUTE_PATH}} = $docker;
    }

    foreach my $changed_file (@{$gitdiffs}) {
	while ($changed_file) {
	    if ($filehash->{$changed_file}) {
		$dockers->{$filehash->{$changed_file}}->{NEEDS_BUILDING} = 1;
		$dockers->{$filehash->{$changed_file}}->{BUILD_REASON} .= ' changed in git. ';
		$dockers->{$filehash->{$changed_file}}->{NEEDS_PULLLING} = 1;
		last;
	    }
	    $changed_file =~ s|/[^/]*$||;
	}
    }
    return 1;
}


sub grok_git_branch {
    my $thisbranch = git_current_branch();

    if ($CONFIG::config->{sourcebranch}) {
	if ($thisbranch eq $CONFIG::config->{sourcebranch}) {
	    print "sourcebranch $CONFIG::config->{sourcebranch} set to current branch $thisbranch  \n";
	    return 1;
	} else {
	    print "sourcebranch $CONFIG::config->{sourcebranch} not checked out. \n";

	    if (gitops::checkout_branch($CONFIG::config->{sourcebranch})) {
		print "Checked out $CONFIG::config->{sourcebranch} \n";
		return 1;
	    } else {
		print "Checkout of CONFIG::config->{sourcebranch} failed.  \n";
		return undef;
	    }
	}
    } else {
	print "sourcebranch not set in config.  Seeting it to checked out branch $thisbranch\n";
	$CONFIG::config->{sourcebranch}=$thisbranch;
	return 1;
    }
}




sub checkout_branch {
    my $branch = shift or return undef;
    my $success = system("git checkout $branch");
    if ($success != 0) {
	print "Attempt to checkout $branch failed\n";
	return undef;
    } else {
	print "Checked out $branch succeeded \n";
	return 1;
    }
}

sub git_current_branch {
    my $gitline = `git symbolic-ref HEAD`;
    if ($? == 0) {
	$gitline =~s|^refs/heads/||;
	chomp $gitline;
	return $gitline;
    } else {
	return undef;
    }
}

sub gitroot {
    open (GIT, "git rev-parse --show-toplevel |");
    my $ret = <GIT>;
    close (GIT);
    chomp $ret;
    return $ret;
}


sub circle_branch {
    return $ENV{CIRCLE_BRANCH} // undef;
}



1;
