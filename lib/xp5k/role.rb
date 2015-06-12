class XP5K::Role

  attr_accessor :name, :size, :desc, :servers, :jobid, :inner, :pattern

  @@roles = []

  def initialize(options = {})
    # Defaults
    @inner   = false
    @servers = []
    @desc    = ""

    # Required parameters
    %w{ name size }.each do |param|
      if options[param.to_sym].nil?
        raise XP5K::Exceptions::Role, "#{self.to_s}: #{param.to_sym} needed at initialization"
      else
        instance_variable_set("@#{param}", options[param.to_sym])
      end
    end

    # Optional parameters
    %w{ desc servers inner pattern }.each do |param|
      instance_variable_set("@#{param}", options[param.to_sym]) if options[param.to_sym]
    end
  end

  def add
    @@roles << self
  end

  def self.create_roles(job, job_definition)
    # Definition will return list of roles
    roles = []

    # Test if job contain enough nodes for all roles
    count_needed_nodes = 0
    job_definition[:roles].each { |role| count_needed_nodes += role.size if not role.inner }
    if job['assigned_nodes'].length < count_needed_nodes
      raise "Job ##{job['uid']} require more nodes for required roles"
    end

    # Sort nodes assigned to the job
    available_nodes = { 'job' => job['assigned_nodes'].sort }


    # Sort roles to manage inner roles at the end
    defined_roles = job_definition[:roles].sort do |x,y|
      a = x.inner ? 1 : 0
      b = y.inner ? 1 : 0
      a <=> b
    end

    # Sort roles to manage roles with pattern first
    defined_roles = defined_roles.sort do |x,y|
      a = x.pattern ? 0 : 1
      b = y.pattern ? 0 : 1
      a <=> b
    end

    # Attributes nodes to roles
    defined_roles.each do |role|
      next if self.exists?(role.name)
      if role.inner
        available_nodes[role.inner] ||= self.findByName(role.inner).servers
        role.servers = available_nodes[role.inner][0..(role.size - 1)]
        available_nodes[role.inner] -= role.servers
      else
        if not role.pattern
          role.servers = available_nodes['job'][0..(role.size - 1)]
        else
          filtered_nodes = available_nodes['job'].select { |x| x.match role.pattern }
          role.servers = filtered_nodes[0..(role.size - 1)]
        end
        available_nodes['job'] -= role.servers
      end
      role.jobid = job['uid']
      roles << role
      @@roles << role
    end
    return roles
  end

  def self.list()
    @@roles
  end

  def self.findByName(name)
    roles = @@roles.select { |x| x.name == name }
    roles.empty? ? nil : roles.first
  end

  def self.exists?(name)
    @@roles.select { |x| x.name == name }.empty? ? false : true
  end

end
