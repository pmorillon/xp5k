require "rubygems"
require "json"
require "restfully"
require "fileutils"
require "term/ansicolor"
require "pp"

module XP5K
  class XP
    include Term::ANSIColor

    attr_accessor :jobs, :jobs2submit, :deployments, :todeploy, :connection
    attr_reader :starttime

    def initialize(options = {})
      @jobs = []
      @jobs2submit = []
      @deployments = []
      @todeploy = []
      @starttime = Time.now
      @logger = options[:logger] || Logger.new('xp.log')
      @logger.level = options[:logger_level] || Logger::INFO

      XP5K::Config.load unless XP5K::Config.loaded?
      @site = options[:site] || XP5K::Config[:site]
      @cache = ".xp_cache."+@site

      @connection = options[:connection] || Restfully::Session.new(
        :configuration_file => "~/.restfully/api.grid5000.fr.yml",
        :logger => begin
          tmplogger = ::Logger.new(STDERR)
          tmplogger.level = ::Logger::WARN
          tmplogger
        end
      )
      logger.info "[#{@site}] XP5K session initialized"
    end

    def timer
      Time.now - self.starttime
    end

    def define_deployment(deployment_hash)
      logger.info "[#{@site}] define a new deployment"
      deployment_hash[:jobs].each do |jobname|
        job = self.look_for_job(jobname)
        if (!job.nil?)
          self.todeploy << deployment_hash
          break
        end
      end
    end
    
    def deploy(poll=true)
      deployments = []
      self.todeploy.each do |x|
        x[:nodes] ||= []
        # Get assigned resources to deploy
        x[:jobs].each do |jobname|
          job = self.job_with_name(jobname)
          if !job.nil?
            logger.info "[#{@site}] Adding the nodes from " + jobname
            x[:nodes] += job["assigned_nodes"]
            logger.info "[#{@site}] " +job["assigned_nodes"]*"," +" added"
          end
        end
        logger.info "[#{@site}] deployement on nodes " + x[:nodes]*","
        deployment = @connection.root.sites[@site.to_sym].deployments.submit(x)
        self.deployments << { :uid => deployment["uid"], :site => deployment["site_uid"] }
        update_cache
        logger.info "[#{@site}] Waiting for the deployment ##{deployment['uid']} to be terminated..."
        if poll
          poll_deployment(deployment)
        end
        
        deployments << deployment
      
      end
      return deployments
    end
    
    def deployments_terminated()
      self.deployments.each do |deployment|
        # maybe we should swirch to restfully
        depl = @connection.root.sites[@site.to_sym].deployments[deployment[:uid].to_sym]
        terminated = depl["status"]=="terminated"
        if (not terminated)
          logger.info "[#{@site}] Deployment ##{deployment[:uid]} not terminated"
          return false
        else
          logger.info "[#{@site}] Deployment ##{deployment[:uid]} terminated"
          deployment["result"]=depl["result"]
        end
      end
      logger.info "[#{@site}] All deployments terminated"
      return true
    end

    def jobs_running()
      self.jobs.each do |job|
        if job.reload["state"] != "running"
          logger.info "[#{@site}] Job ##{job["name"]} not running"
          return false
        end
      end
      logger.info "[#{@site}] All jobs running"
      update_cache
      return true
    end

    def define_job(job_hash)
      job_hash[:site] = @site
      self.jobs2submit << job_hash

      if File.exists?(@cache)
        # Reload job
        logger.info "[#{@site}] Reload job from local cache"
        datas = JSON.parse(File.read(@cache))
        uid = datas["jobs"].select { |x| x["name"] == job_hash[:name] }.first["uid"]
        unless uid.nil?
          job = @connection.root.sites[job_hash[:site].to_sym].jobs["#{uid}".to_sym]
          unless (job.nil? or job["state"] != "running")
            j = job.reload
            self.jobs << j
          end
        end
      else
        logger.info "[#{@site}] New job defined"
      end
    end

    def submit(poll=true)
      jobs = []
      self.jobs2submit.each do |job2submit|
        job = self.job_with_name(job2submit[:name])
        if job.nil?
          puts job2submit[:site].to_sym
          job = @connection.root.sites[job2submit[:site].to_sym].jobs.submit(job2submit)
          self.jobs << job
          jobs << job 
          update_cache
          logger.info "[#{@site}] Waiting for the job #{job["name"]} ##{job['uid']} to be running ..."

          if poll
            poll_job(job)
          end
        end
      end
      logger.info "[#{@site} #{jobs.length} submitted]"
      return jobs
    end
    def look_for_job(name)
      job = job_with_name(name)
      if job.nil?
        job = self.jobs2submit.select { |x| x[:name] == name }.first
      end
      return job
    end

    def job_with_name(name)
      self.jobs.select { |x| x["name"] == name }.first
    end

    def status
      self.jobs.each do |job|
        logger.info "[#{@site}] Job #{job["name"]} ##{job["uid"]} status : #{job["state"]}"
      end
    end

    def clean
      self.jobs.each do |job|
        if job.reload["state"] == "running"
          job.delete
          logger.info "[#{@site}] Job ##{job["uid"]} deleted !"
        end
      end
      begin
        FileUtils.rm(@cache)
      rescue => e
      end
    end

    private

    def logger
      @logger
    end

    def update_cache
      cache = { :jobs => self.jobs.collect { |x| x.properties },
                :deployments => self.deployments
      }
      open(@cache, "w") do |f|
        f.puts cache.to_json
      end
    end

    def poll_job(job)
      while job.reload["state"] != "running"
        print(".")
        sleep 3
      end
      print(" [#{green("OK")}]\n")
      update_cache
    end

    def poll_deployment(deployment)
      while deployment.reload['status'] == 'processing'
        print(".")
        sleep 10
      end
      print(" [#{green("OK")}]\n")
      update_cache
    end
  end
end
