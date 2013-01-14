## Capistrano sample

    require 'xp5k'
    
    XP5K::Config.load
    
    @myxp = XP5K::XP.new(:logger => logger)
    
    @myxp.define_job({
      :resources  => "nodes=1,walltime=1",
      :site       => XP5K::Config[:site] || 'rennes',
      :types      => ["deploy"],
      :name       => "job1",
      :command    => "sleep 86400"
    })
    
    @myxp.define_job({
      :resources  => "nodes=1,walltime=1",
      :site       => XP5K::Config[:site] || 'rennes',
      :types      => ["deploy"],
      :name       => "job2",
      :command    => "sleep 86400"
    })
    
    @myxp.define_deployment({
      :site           => XP5K::Config[:site] || 'rennes',
      :environment    => "squeeze-x64-nfs",
      :jobs           => %w{ job1 job2 },
      :key            => File.read(XP5K::Config[:public_key])
    })
    
    role :job1 do
      @myxp.job_with_name('job1')['assigned_nodes'].first
    end
    
    role :job2 do
      @myxp.job_with_name('job2')['assigned_nodes'].first
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


## _xp.conf_ sample file

    site        'rennes'
    public_key  '/Users/pmorillon/.ssh/id_rsa_g5k.pub'


