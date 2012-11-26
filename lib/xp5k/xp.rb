require "json"
require "restfully"
require "fileutils"
require "term/ansicolor"

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
      @logger = options[:logger] || Logger.new(STDOUT)
      XP5K::Config.load unless XP5K::Config.loaded?

      @connection = Restfully::Session.new(
        :configuration_file => "~/.restfully/api.grid5000.fr.yml",
        :logger => begin
          tmplogger = ::Logger.new(STDERR)
          tmplogger.level = ::Logger::WARN
          tmplogger
        end
      )
    end

    def timer
      Time.now - self.starttime
    end

    def define_deployment(deployment_hash)
      self.todeploy << deployment_hash
    end

    def deploy
      self.todeploy.each do |x|
        x[:nodes] ||= []
        # Get assigned resources to deploy
        x[:jobs].each do |jobname|
          job = self.job_with_name(jobname)
          x[:nodes] += job["assigned_nodes"]
        end
        deployment = @connection.root.sites[x[:site].to_sym].deployments.submit(x)
        self.deployments << { :uid => deployment["uid"], :site => deployment["site_uid"] }
        update_cache
        puts "Waiting for the deployment ##{deployment['uid']} to be terminated..."
        while deployment.reload['status'] == 'processing'
          print(".")
          sleep 10
        end
        print(" [#{green("OK")}]\n")
        update_cache
      end
    end

    def define_job(job_hash)
      self.jobs2submit << job_hash

      if File.exists?(".xp_cache")
        # Reload job
        datas = JSON.parse(File.read(".xp_cache"))
        uid = datas["jobs"].select { |x| x["name"] == job_hash[:name] }.first["uid"]
        unless uid.nil?
          job = @connection.root.sites[job_hash[:site].to_sym].jobs["#{uid}".to_sym]
          unless (job.nil? or job["state"] != "running")
            j = job.reload
            self.jobs << j
          end
        end
      end
    end

    def submit
      self.jobs2submit.each do |job2submit|
        job = self.job_with_name(job2submit[:name])
        if job.nil?
          job = @connection.root.sites[job2submit[:site].to_sym].jobs.submit(job2submit)
          self.jobs << job
          update_cache
          logger.info "Waiting for the job #{job["name"]} ##{job['uid']} to be running at #{job2submit[:site]}..."
          while job.reload["state"] != "running"
            print(".")
            sleep 3
          end
          print(" [#{green("OK")}]\n")
          update_cache
        end
      end
    end

    def job_with_name(name)
      self.jobs.select { |x| x["name"] == name }.first
    end

    def status
      # self.jobs2submit.each do |job2submit|
      #   job = self.job_with_name(job2submit[:name])

      # end
      self.jobs.each do |job|
        logger.info "Job #{job["name"]} ##{job["uid"]} status : #{job["state"]}"
      end
    end

    def clean
      self.jobs.each do |job|
        if job.reload["state"] == "running"
          job.delete
          logger.info "Job ##{job["uid"]} deleted !"
        end
      end
      FileUtils.rm(".xp_cache")
    end

    private

    def logger
      @logger
    end

    def update_cache
      cache = { :jobs => self.jobs.collect { |x| x.properties },
                :deployments => self.deployments
      }
      open(".xp_cache", "w") do |f|
        f.puts cache.to_json
      end
    end

  end
end
