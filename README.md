#### Table of Contents

1. [Getting started](#getting-started)
  * [Gemfile](#gemfile)
  * [Restfully](#restfully)
  * [Ssh config](#ssh-config)
2. [Samples](#samples)
  * [Hello date](#hello-date)
  * [Xp5k Roles](#xp5k-roles)
  * [Nested roels](#nested-roles)
  * [Patterns](#patterns)
  * [Get the deployed nodes](#get-the-deployed-nodes)
  * [Automatic redeployment](#automatic-redeployment)
  * [Vlan support](#vlan-support)
  * [Non deploy jobs](#non-deploy-jobs)

# Getting started

A typical project architecture using ```xp5k``` and ```capistrano``` looks like :

```bash
.
├── Capfile   # deployment logic
├── Gemfile   # gem dependencies description
├── LICENSE   # License of utilization
└── README.md # How to
```

## Gemfile

Add this to your application Gemfile:

```ruby
source "http://rubygems.org"

gem "xp5k"
gem "capistrano", "< 3.0.0"
```

and then run

```ruby
bundle install
```

Note : We encourage you to use [```xpm```](http://rvm.io/)


##  Restfully

```xp5k``` makes use of ```restfully``` to perform REST calls to the
[Grid'5000API](https://api.grid5000.fr).

Fill the ```~/.restfully/api.grid5000.fr.yml``` file with your credentials :
```bash
$) cat ~/.restfully/api.grid5000.fr.yml
base_uri: https://api.grid5000.fr/3.0
username: "###"
password: "###"
```

You are now ready to use ```xp5k``` and ```capistrano```.

You will find the documentation of capistrano in the following link :
https://github.com/capistrano/capistrano/wiki

## Ssh config

You can have a look at https://www.grid5000.fr/mediawiki/index.php/Xp5k

# Samples


## Hello date

Here is an example of a ```Capfile``` :

```ruby
require 'xp5k'
require 'capistrano'

set :g5k_user, "msimonin"
# gateway
set :gateway, "#{g5k_user}@access.grid5000.fr"
# These keys will used to access the gateway and nodes
ssh_options[:keys]= [File.join(ENV["HOME"], ".ssh", "id_rsa")]
# # This key will be installed on nodes
set :ssh_public,  File.join(ENV["HOME"], ".ssh", "id_rsa.pub")

XP5K::Config.load

@myxp = XP5K::XP.new(:logger => logger)

@myxp.define_job({
  :resources  => "nodes=2,walltime=1",
  :site       => 'rennes',
  :types      => ["deploy"],
  :name       => "job1",
  :command    => "sleep 86400"
})

@myxp.define_deployment({
  :site           => 'rennes',
  :environment    => "wheezy-x64-nfs",
  :jobs           => %w{ job1 },
  :key            => File.read("#{ssh_public}")
})

role :job1 do
  @myxp.job_with_name('job1')['assigned_nodes'].first
end

desc 'Submit jobs'
task :submit do
  @myxp.submit
  @myxp.wait_for_jobs
end

desc 'Deploy with Kadeplopy'
task :deploy do
  @myxp.deploy
end

desc 'Status'
task :status do
  @myxp.status
end

desc 'Remove all running jobs'
task :clean do
  logger.debug "Clean all Grid'5000 running jobs..."
  @myxp.clean
end

desc 'Run date command'
task :date, :roles => [:job1] do
  set :user, 'root'
  run 'date'
end
```

After filling the Capfile you can start working with Capistrano :

```bash
 ➤ cap -T
cap clean  # Remove all running jobs
cap date   # Run date command
cap deploy # Deploy with Kadeplopy
cap invoke # Invoke a single command on the remote servers.
cap shell  # Begin an interactive Capistrano session.
cap status # Status
cap submit # Submit jobs
```

For instance you can launch : ```cap submit deploy date```

## Xp5k Roles

You can define specific roles in you job submission.

```ruby
@myxp.define_job({
  :resources  => "nodes=6,walltime=1",
  :site       => XP5K::Config[:site] || 'rennes',
  :types      => ["deploy"],
  :name       => "job2",
  :roles      => [
    XP5K::Role.new({ :name => 'server', :size => 1 }),
    XP5K::Role.new({ :name => 'clients', :size => 4 }),
    XP5K::Role.new({ :name => 'frontend', :size => 1 })
],
:command    => "sleep 86400"
})

@myxp.define_deployment({
  :site           => 'rennes',
  :environment    => "wheezy-x64-nfs",
  :roles          => %w{ server frontend },
  :key            => File.read("#{ssh_public}")
})

@myxp.define_deployment({
  :site           => 'rennes',
  :environment    => "squeeze-x64-nfs",
  :roles          => %w{ clients },
  :key            => File.read("#{ssh_public}")
})


role :server do
  @myxp.role_with_name('server').servers
end

role :server do
  @myxp.role_with_name('frontend').servers
end

role :server do
  @myxp.role_with_name('clients').servers
end
```

## Nested roles

You can also define nested roles (only 1 level) :

```ruby
@myxp.define_job({
  :resources  => "nodes=4,walltime=1",
  :site       => XP5K::Config[:site] || 'rennes',
  :types      => ["deploy"],
  :name       => "ceph_cluster",
  :roles      => [
    XP5K::Role.new({ :name => 'ceph_nodes', :size => 4 }),
    XP5K::Role.new({ :name => 'ceph_monitor', :size => 1, :inner => 'ceph_nodes' }),
  ],
  :command    => "sleep 86400"
})

```

## Patterns

You can select nodes matching a pattern (`String` or `Regexp`) :

```ruby
roles = []
scenario['clusters'].each do |cluster|
  roles << XP5K::Role.new({
    :name    => "ceph_nodes_#{cluster['name']}",
    :size    => cluster['ceph_nodes_count'],
    :pattern => cluster['name']
  })
  roles << XP5K::Role.new({
    :name => "ceph_monitor_#{cluster['name']}",
    :size => 1,
    :inner => "ceph_nodes_#{cluster['name']}"
  })
end
```

## Get the deployed nodes

Some time nodes fail to be deployed. You can get the exact set
of nodes deployed in your xp5k job or role using the ```get_deployed_nodes```
method.

```ruby
role :clients  do
  @myxp.get_deployed_nodes('clients')
end
```

## Automatic redeployment

If some nodes fail to be deployed, ```xp5k``` will by default
retry to deploy them up to 3 times.
You can control this behaviour passing special keys in the deployment hash.

```ruby
# disable the retry
@myxp.define_deployment({
  ...
  :retry   => true | false   # enable / disable retry mechanism
                             # true by default
  :retries => 3              # number of retries

  :goal    => 2              # min number of deployed nodes wanted
                             # can be a percentage : "80%"
})
```

## Vlan support

```ruby
@myxp.define_job({
  :resources => "{type='kavlan'}/vlan=1,nodes=2,walltime=1",
  :site      => XP5K::Config['site'],
  :queue     => XP5K::Config[:queue] || 'default',
  :types     => ["deploy"],
  :name      => "xp5k_vlan",
  :command   => "sleep 186400"
})
```

```ruby
@myxp.define_deployment({
  :site          => "rennes",
  :environment   => "wheezy-x64-base",
  :roles         => %w{ xp5k_vlan },
  :key           => File.read("#{ssh_public}"),
  :vlan_from_job => 'xp5k_vlan',
  })
```

## Non deploy jobs

Here we fill the ```types``` field with ```allow_classic_ssh```.

```ruby
@myxp.define_job({
  :resources  => ["nodes=1, walltime=1"],
  :site       => "rennes",
  :retry      => true,
  :goal       => "100%",
  :types      => ["allow_classic_ssh"],
  :name       => "init" ,
  :command    => "sleep 86400"
  })

role :myrole do
   @myxp.job_with_name('init')['assigned_nodes']
end
```

You should be able to issue :
```cap invoke ROLES=myrole USER=<g5k-login> COMMAND=date``` to retrieve the date on all the nodes without deploying.
