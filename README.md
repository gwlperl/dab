=
# The Docker Automatic Builder


The Docker Automatic Builder is a script to automatically build docker
images.  This script is designed for docker CI/CD pipelines and other
complex docker environments.


The Docker Automatic Builder will:

- Determines docker dependencies and proper build order
- Use git branches to determine what has changed and what will need to be built
- Tag images with usefull info
- Pull and push images to private docker registries

## Quickstart - Getting it to work

The dab is a perl script written for unixlike operating systems..  It
will work with any perl that's close to "modern".  No other perl
libraries are needed to be installed.

Extract the contents of this repo into a directory of your choice. You may
put that directory in your $PATH environment variable or call the
utility "dab" explicitly.  The dab is not yet in a proper package or
docker image.

The command is "dab" and it will properly build all the dockers it can
find in the current or specified directory.

```
dab --all --srcdir /foo/bar      # Build all the docker images it can find in /foo/bar
dab --all                        # Build all the docker images it can find in the current directory
```

### Specifying the config file


You may specify all options in a configfile.  You may specify the location of that configfile on the command line with


```
dab --configfile /some/where/config.yml
```

Or use an environment variable to point to the location

```
export AUTODOCKER_CONFIGFILE='/else/where/config.yml'
```

Or use the default which is 'autodocker.yml' which is to be found in the "srcdir" or current directory.



## Building Docker Images


### Docker's Dependancy Chain


Many docker development environments use a complex dependency chain of
docker images.  Changes to an image in the "middle" of the chain will
require that images that depend on it that are "downstream" must also
be built.  Images that are "upstream" will need to be either pulled or
built from scratch.

Docker's "build" file is the ubiquitous "Dockerfile".  The FROM directive
in any Dockerfile specifies the base layer of the image. While docker
now allows for multiple FROM statements, the DAB does not yet support or
deal with them and will only use the first FROM statement in any Dockerfile.

```
FROM ubuntu:18.04
```

This means that to build it, the image "ubuntu:18.01" must already be in
the local registry and will be incorporated in the image as the first
layer.   In this case, ubuntu:18.04 happens to be a standard image
that's in the docker.io repository.  Docker will check and download the
image automatically for you during a build.


There's no way to tell by looking at "ubuntu:18.04" if it's an image in
the standard docker repo or if it's a reference to a docker image that's
been loaded into the local repository.  From a build automation point of
view, this poses a problem.  Is ubuntu:18.04 something that needs to
be built or does it need to be pulled?


We get around this problem by avoiding it.   We only build images that
have a docker file.   References to other dockers (like ubuntu:18.04 in
this case) will be pulled automatically if they are referenced by other
docker files.


In order for a complex docker build to work, the dockers must be built in the
proper order.  In many environments, a chain of dependencies will be
created, each adding additional images and layers.


Here's an example.

```
     ubuntu:18.04
       -->  webserver   FROM ubuntu:18.04
           ->  app_server  - FROM webserver)
       ->  AWS-server-west    -    FROM app_server
               ->  AWS-server-east    -    FROM app_server
```

Here, ubuntu:18.01 is base image and will automatically be pulled from
the main docker repository docker.io.  If you want a different behaviour
you can use a hook to do this.  The script won't try to do anything
special here, it will simply issue a "docker build" in the directory.


The "webserver" image will depend on ubuntu, and the app_server image
will depend on "webserver".


If you make a change to the "app_server" image you need to have the latest
versions of ubuntu:18.01 and webserver, and after you build it you'll
need to rebuild AWS-server-west and AWS-server-east, as they incorporate
the layers from webserver.




For efficiency, it is desirable to build against images that are pulled
from a common registry, using docker's "--cache-from".  So you'll need
to manage and automate pulling of the correct images to build against.
The DAB automatically adds this to the docker options.  If there is no
image to cache against, this will not break the build, it'll simply be
ignored.




### Docker service names


The DAB uses the convention of setting the "service" name to be that of
the directory that the Dockerfile is found in.  If you have a directory
called "appserver" the docker image built in that directory will be
named "appserver".   And if "appserver" has a "FROM" directive of
"ourwebserver" a dependancy will be created, and "ourwebserver" will be
built or pulled before "appserver" is built.


For FROM directives that refer to images that are not found in the FROM
directives in the local docker files, the DAB assumes that these images
will already in in the local docker cache.  Use a pre-build hook to
ensure that this image is properly pulled before the dockers are built.
An example of this is in example_dockers directory.


## Git operations


The DAB can use git branches and differences to determine what has
changed and needs building.  Specify options of sourcebranch and
targetbranch and DAB will do a git diff between them to find out what's
changed. If you specify an option of "sourcebranch" it will checkout
that branch from git, if necessary.  If you don't specify "--all",
"--imagelist" or "--master" it will attempt to determine "sourcebranch"
from the current branch of the source directory.


The options of sourcebranch and targetbranch are only used to determine
"what what changed", and "what needs to be built".


The use of git is optional, you may specify "--all" or specific images by
use of the "--imagelist" option.  The default is "--all".

The option of --master will set "--all --branch master --pull no".  


## How to use the DAB


At a minimum, DAB needs to know the directory that contains your source
dockers.  You pass it one directory with --srcdir and it will find and
build all the dockers under all the subdirectories.  For the purposes of
determining dependencies, the directory structure is mostly irrelevant,
only the chain of FROM lines matters.  The DAB does not yet handle
multiple source directories.




## DAB Options


```
dab --all
```

"--all" will build every docker, in the proper order, regardless of
what's changed.

```
dab --master
```

Implies "--all" and "--branch master" "--tag master" and "--pull no".  


```
dab --pull
```

Pull requisite docker images before building.  Specify the registy with
the config options  docker-registry-address and docker-registry-port.


```
dab --push
```

Push images to the registry after a successful build.

```
dab --srcdir my-dockers.
```

Search the directory "my-dockers" and find all sub directories that
contain a "Dockerfile".


```
dab --srcdir my-dockers --source_branch dev --target_branch beta123
```

This will cd to "my-dockers" and determine what to build by doing a git
diff between branches "dev" and "beta123".  However, if this git fails,
or the directly isn't a git repo, then "--all" will be used.


## Build hooks, before and after each docker build


The DAB can run scripts in each docker directory before and after
building the image.  Specify a "semi regular expression" for "pre-build-hook" and "post-build-hook" in
the config file.


One use case for a pre-build hook is to pull an image that is not part
of the build, such as "ubuntu:18.01" as noted above.


## Order of Operations


1. Get options from the command line and configuration file.
1. Find all Dockerfiles in the source directory.
1. Determine git environment and branches.
1. Determine the build order by following the "FROM" chain in each Dockerfile.
1. Determine what needs to be build from either "--all", "--image-list" or via a difference of git branches (sourcebranch and targetbranch).
1. Pull all prerequisites, if the --pull option is set.
1. Run the single script defined by the option "pre-build-script", if defined.
1. Build each docker by changing to the directory of each docker, running the optional "pre-build-hook", doing a "docker build", and then runningthe optional "post-build-hook". Local and "remote" (registry) Tags are applied here.
1. Run the single script defined by the option "post-build-script", if defined.
1. Push any dockers that need to be pushed to the registry.
1. Report on build success for each docker.  If any docker fails the script exits with a code of 1 (fail).  If they all suceed then it returns 0.

## Options


Command line options override config file options.


For command line options, use the --option convention.  For true/false
options, you may set 0 (false) and 1 (true) in the config file and
--option or --option no on the command line.




| Option  | autodocker.yml | Command line | Default | Use  |
|---------|----------------|--------------|---------|------|
|all      |  Y        |  Y        |  false  | Build all dockers, ignore git branches|
|imagelist |  Y   | Y            |  none   | Specify specific images to build|
|sourcedir|  Y  | Y  |  .       | Where to find dockers|
|master|   Y | Y|   false |  Implies --all and --branch master|
|build    |  Y     | Y        | true    | Actually build or dry run|
|buildnumber | Y  |  Y   |  use fake |  Set the build number. Otherwise it will make one up|
|push     |  Y       |      Y  |   true    | Push built images |
|pull     |  Y       |      Y  |   true    | Pull pre-reqs from the registry |
|sourcebranch   | Y  |Y  | current branch | To determine what needs to be built|
|targetbranch   | Y | Y  | master | To determine what needs to be built|
|pre-build-script| Y  |  Y | none | Name of one script to run before the entire build|
|post-build-script| Y  |  Y | none | Name of one script to run after the entire build|
|pre-build-hook| Y  |  Y | none | Semi-regex of scripts to run before building each docker|
|post-build-hook| Y |  Y  | none | Semi-regex of scripts to run after building each docker|
|docker-registry-address| Y | Y |  localhost| Address of the registry for pulls and pushes|
|docker-registry-port | Y   | Y | 5000| Port of the registry |


## Authorship
Gerry Lawrence gwlperl@gmail.com is the sole author.


## Bugs

Certainly numerous.

## License

The DAB is publised under the Perl Artistic License 2.9.
See LICENSE.TXT
Gerry Lawrence
