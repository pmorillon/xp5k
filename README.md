## Capistrano sample

    require "rubygems"
    require "xp5k"

    # connection to the gateway parameters
    set :g5k_user, "msimonin"
    set :gateway, "#{g5k_user}@access.grid5000.fr"
    ssh_options[:keys]= [File.join(ENV["HOME"], ".ssh_cap", "id_rsa_cap")]
    
    
    @myxp = XP5K::XPM.new()
    
    @myxp.define_job({
      :resources  => ["nodes=1,walltime=1", "nodes=2,walltime=1"],
      :sites      => %w( toulouse lyon) ,
      :types      => ["deploy"],
      :name       => "job1",
      :command    => "sleep 3600"
    })
    
    @myxp.define_job({
      :resources  => ["nodes=1,walltime=1"],
      :sites      => %w(toulouse lille reims),
      :types      => ["deploy"],
      :name       => "job2",
      :command    => "sleep 3600"
    })

    
    @myxp.define_deployment({
      :site           => XP5K::Config[:site] || 'rennes',
      :environment    => "squeeze-x64-nfs",
      :jobs           => %w{ job1 job2 },
      :key            => File.read(XP5K::Config[:public_key])
    })
    
    role :job1 do
      @myxp.get_assigned_nodes("job1")
    end
    
    role :job2 do
      @myxp.get_assigned_nodes("job2")
    end
    
    desc 'Submit jobs'
    task :submit do
      @myxp.submit
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
    task :date, :roles => [:job1, :job2] do
      set :user, 'root'
      run 'date'
    end
