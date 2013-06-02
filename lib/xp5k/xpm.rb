require "json"
require "restfully"
require "fileutils"
require "term/ansicolor"
require "pp"

module XP5K
  class XPM

    include Term::ANSIColor

    attr_accessor :jobs, :jobs2submit, :deployments, :todeploy, :connection
    attr_reader :starttime

    def initialize(options = {})
      @xpsites = {}
      @jobs = {}
      @deployed_nodes = []
      XP5K::Config.load unless XP5K::Config.loaded?
      @logger = Logger.new('xp.log')
      @logger.level = Logger::INFO
      @connection = Restfully::Session.new(
        :configuration_file => "~/.restfully/api.grid5000.fr.yml",
        :logger => begin
          tmplogger = ::Logger.new(STDERR)
          tmplogger.level = ::Logger::WARN
          tmplogger
        end
      )
      sites = @connection.root.sites
      sites.each do |site|
        @xpsites[site["uid"]] = XP5K::XP.new(:site => site["uid"], :connection => @connection) 
      end
      @logger.info "XP5K::XPM session initialized"
    end

    def timer
      Time.now - self.starttime
    end

    def define_deployment(deployment_hash)
      @logger.info "XP5K::XPM define a new deployment"
      @xpsites.each do |site, xpsite|
        xpsite.define_deployment(deployment_hash.clone)
      end
    end
    
    def deploy()
      sites_with_deployments = {}
      @xpsites.each do |site, xpsite|
        deployment = xpsite.deploy(poll=false)
        if !deployment.nil? and deployment != []
          sites_with_deployments[site] = false
        end
      end
      puts blue("Waiting for all the deployments to be finished ...")
      finished = true
      sites_with_deployments.each { |a,b| finished = (finished and b) }
      retries = 0
      while (not finished )
        if (retries % 10 == 0)
          sites_with_deployments.each do |site, finished|
            printf "%+10s", site
          end
          puts "\n"
        end
        sites_with_deployments.each do |site, finished|
          if @xpsites[site].deployments_terminated()
            printf "%10s", "OK"
            sites_with_deployments[site] = true
          else
            printf "%10s", "." 
          end
        end
        puts "\n"
        retries = retries + 1
        finished = true
        sites_with_deployments.each { |a,b| finished = (finished and b) }
        sleep 10
      end
      #update nodes_deployed
      puts green("All deployment finished")
    end

    def get_assigned_nodes(jobname,kavlan="-1")
      if (kavlan != "-1")
        nodes = []
        #translate nodes names ...
        jobs[jobname]["assigned_nodes"].each do |node|
          a = node.split('.')
          a[0] = a[0]+"-kavlan-#{kavlan}"
          nodes << a.join(".")
        end
        nodes
      else
        if jobs[jobname].nil?
          []
        else
          jobs[jobname]["assigned_nodes"]
        end
      end
    end

    def define_job(job_hash)
      i = 0
      nb_resource = job_hash[:resources].length
      job_hash[:sites].each do |site|
         job_site = job_hash.clone
         job_site[:site] = site
         job_site[:resources] = job_hash[:resources][i % nb_resource]
         i = i + 1 
         @xpsites[site].define_job(job_site)
         update_jobs(@xpsites[site].jobs)
       end
    end

    def submit
      puts blue("Waiting for all the jobs to be running ...") 
      sites_with_jobs = {}
      @xpsites.each do |site, xpsite|
        jobs = xpsite.submit(poll=false)
        if !jobs.nil? and jobs!=[]
          sites_with_jobs[site]=false
        end
      end 
      # poll jobs here
      retries = 0 
      finished = true
      sites_with_jobs.each { |a,b| finished = (finished and b) }
      retries = 0
      while (not finished)
        if retries % 10 == 0
          sites_with_jobs.each do |site, finished|
            printf "%+10s", site
          end
          puts "\n"
        end
        sites_with_jobs.each do |site, finished|
          if @xpsites[site].jobs_running 
            sites_with_jobs[site] = true
            printf "%10s", "OK"
          else
            printf "%10s", "." 
          end
        end
        puts "\n"
        retries = retries + 1
        finished = true
        sites_with_jobs.each { |a,b| finished = (finished and b) }
        sleep 3
      end
      puts green("All jobs submitted")

      #update the global jobs
      sites_with_jobs.each do |site, finished|
        update_jobs(@xpsites[site].jobs)
      end
    end

    def job_with_name(jobname)
      @jobs[jobname]
    end

    def clean
      puts blue("Cleaning all jobs")
      @xpsites.each do |site,xpsite|
        xpsite.clean
      end
      puts green(".")
    end

    private

    def logger
      @logger
    end

    def update_jobs(jobs)
      jobs.each do |job|
        @jobs[job["name"]] ||={}
        @jobs[job["name"]]["assigned_nodes"] ||=[]
        @jobs[job["name"]]["assigned_nodes"] += job["assigned_nodes"]
        @jobs[job["name"]]["assigned_nodes"].uniq!
        @jobs[job["name"]]["uid"] = job["uid"]
      end
    end
  end
end
