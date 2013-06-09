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
      @deployed_nodes = {} 
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

    def get_sites_with_job(jobname)
      sites = []
      @xpsites.each do |site, xp|
        j = xp.job_with_name(jobname)
        if not j.nil?
          sites << site
        end
      end
      sites
    end

    def get_sites_with_jobs()
      sites = []
      @xpsites.each do |site, xp|
        unless xp.jobs.nil? or xp.jobs.empty?
          sites << site
        end
      end
      sites
    end

    def job_with_name(jobname)
      site = get_sites_with_job(jobname).first
      if not site.nil?
        @xpsites[site].job_with_name(jobname)
      end
    end

    def get_deployed_nodes(jobname, kavlan="-1")
      nodes = []
      @xpsites.each do |site, xp|
        site_deployed_nodes = xp.get_deployed_nodes(jobname)
        if not site_deployed_nodes.nil?
          nodes = nodes + xp.get_deployed_nodes(jobname)
        end
      end
      translate(nodes, kavlan)
    end

    def get_assigned_nodes(jobname, kavlan="-1")
      nodes = []
      @xpsites.each do |site, xp|
        site_assigned_nodes = xp.get_assigned_nodes(jobname)
        if not site_assigned_nodes.nil?
          nodes = nodes +  site_assigned_nodes
        end
      end
      translate(nodes, kavlan)
    end

    def translate(nodes, kavlan="-1")
      if (kavlan != "-1")
        tnodes =[]
        pp nodes
        nodes.each do |node|
          a = node.split('.')
          a[0] = a[0]+"-kavlan-#{kavlan}"
          tnodes << a.join(".")
        end
        return tnodes
      end
      return nodes
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
    end

    def clean
      puts blue("Cleaning all jobs")
      @xpsites.each do |site,xpsite|
        xpsite.clean
      end
      puts green(".")
    end

    def status()
      @xpsites.each do |site, xpsite|
        xpsite.status
      end 
    end

    private

    def logger
      @logger
    end

  end
end
