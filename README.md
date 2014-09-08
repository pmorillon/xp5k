## Installation

Add this to your application Gemfile:

```ruby
gem "xp5k"
gem "capistrano", "< 3.0.0"
```

and then run

```ruby
bundle install
```

Configure restfully :

```bash
$) cat ~/.restfully/api.grid5000.fr.yml
base_uri: https://api.grid5000.fr/3.0
username: "###"
password: "###"
```

You are now ready to use ```xp5k``` and ```capistrano```.

You will find the documentation of capistrano in the following link :
https://github.com/capistrano/capistrano/wiki

## Sample

Here is an example of a ```Capfile``` :
```ruby
require 'xp5k'
require 'capistrano'

set :g5k_user, "msimonin"
# gateway
set :gateway, "#{g5k_user}@access.grid5000.fr"
# These keys will used to access the gateway and nodes
ssh_options[:keys]= [File.join(ENV["HOME"], ".ssh", "id_rsa"), File.join(ENV["HOME"], ".ssh", "id_rsa_insideg5k")]
# # This key will be installed on nodes
set :ssh_public,  File.join(ENV["HOME"], ".ssh", "id_rsa_insideg5k.pub")

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

## Extra features

### Xp5k Roles

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

### Get the deployed nodes

Some time nodes fail to be deployed. You can get the exact set
of nodes deployed in your xp5k job or role using the ```get_deployed_nodes```
method.

```ruby
role :clients  do
  @myxp.get_deployed_nodes('clients')
end
```

### Automatic redeployment

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
