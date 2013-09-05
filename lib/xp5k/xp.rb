require "json"
require "restfully"
require "fileutils"
require "term/ansicolor"

module XP5K
  class XP

    include Term::ANSIColor

    attr_accessor :jobs, :jobs2submit, :deployments, :todeploy, :connection, :roles
    attr_reader :starttime

    def initialize(options = {})
      @jobs        = []
      @jobs2submit = []
      @deployments = []
      @todeploy    = []
      @roles       = []
      @starttime   = Time.now
      @logger      = options[:logger] || Logger.new(STDOUT)
      XP5K::Config.load unless XP5K::Config.loaded?

      @connection = Restfully::Session.new(
        :configuration_file => "~/.restfully/api.grid5000.fr.yml",
        :logger => begin
          tmplogger       = ::Logger.new(STDERR)
          tmplogger.level = ::Logger::WARN
          tmplogger
        end
      )
    end

    def timer
      Time.now - self.starttime
    end

    def define_deployment(deployment_hash)
      deployment_hash[:jobs] ||= []
      deployment_hash[:roles] ||= []
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
        x[:roles].each do |rolename|
          x[:nodes] += role_with_name(rolename).servers
        end
        site = x[:site]
        x.delete(:site)
        x.delete(:roles)
        x.delete(:jobs)
        deployment = @connection.root.sites[site.to_sym].deployments.submit(x)
        self.deployments << { :uid => deployment["uid"], :site => deployment["site_uid"], :status => deployment["status"]}
      end
      logger.info "Waiting for all the deployments to be terminated..."
      finished = self.deployments.reduce(true){ |acc, d| acc && d[:status]!='processing'}
      while (!finished)
        sleep 10
        print "."
        self.deployments.each do |deployment|
          deployment[:status] = @connection.root.sites[deployment[:site].to_sym].deployments[deployment[:uid].to_sym].reload["status"]
        end
        finished = self.deployments.reduce(true){ |acc, d| acc && d[:status]!='processing'}
      end
      print(" [#{green("OK")}]\n")
    end

    def define_job(job_hash)
      self.jobs2submit << job_hash

      if File.exists?(".xp_cache")
        # Reload job
        datas = JSON.parse(File.read(".xp_cache"))
        uid = datas["jobs"].select { |x| x["name"] == job_hash[:name] }.first["uid"]
        unless uid.nil?
          job = @connection.root.sites[job_hash[:site].to_sym].jobs["#{uid}".to_sym]
          if (not job.nil? or job["state"] == "running")
            j = job.reload
            self.jobs << j
            create_roles(j, job_hash) unless job_hash[:roles].nil?
          end
        end
      end
    end

    def submit
      self.jobs2submit.each do |job2submit|
        job = self.job_with_name(job2submit[:name])
        if job.nil?
          job = @connection.root.sites[job2submit[:site].to_sym].jobs.submit(job2submit)
          self.jobs << { :uid => job.properties['uid'], :name => job.properties['name'] }
          update_cache
          logger.info "Waiting for the job #{job["name"]} ##{job['uid']} to be running at #{job2submit[:site]}..."
          while job.reload["state"] != "running"
            print(".")
            sleep 3
          end
          create_roles(job, job2submit) unless job2submit[:roles].nil?
          print(" [#{green("OK")}]\n")
        else
          logger.info "Job #{job["name"]} already submitted ##{job["uid"]}"
        end
      end
    end

    def create_roles(job, job_definition)
      count_needed_nodes = 0
      job_definition[:roles].each { |role| count_needed_nodes += role.size }
      if job['assigned_nodes'].length < count_needed_nodes
        self.clean
        raise "Job ##{job['uid']} require more nodes for required roles"
      end
      available_nodes = job['assigned_nodes'].sort
      job_definition[:roles].each do |role|
        role.servers = available_nodes[0..(role.size - 1)]
        available_nodes -= role.servers
        role.jobid = job['uid']
        self.roles << role
      end
    end

    def job_with_name(name)
      self.jobs.select { |x| x["name"] == name }.first
    end

    def role_with_name(name)
      self.roles.select { |x| x.name == name}.first
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
      cache = { :jobs => self.jobs.map { |x| { :uid => x[:uid], :name => x[:name] } } }
      open(".xp_cache", "w") do |f|
        f.puts cache.to_json
      end
    end

  end
end
