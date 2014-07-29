class XP5K::Role

  attr_accessor :name, :size, :desc, :servers, :jobid

  def initialize(options = {})
    # Required parameters
    @name = ""
    @size = 0
    %w{ name size }.each do |param|
      if options[param.to_sym].nil?
        raise XP5K::Exceptions::Role, "#{self.to_s}: #{param.to_sym} needed at initialization"
      else
        instance_variable_set("@#{param}", options[param.to_sym])
      end
    end

    # Optional parameters
    %w{ desc servers }.each do |param|
      instance_variable_set("@#{param}", options[param.to_sym])
    end
  end

  def self.create_roles(job, job_definition)
    count_needed_nodes = 0
    roles = []
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
      next if not roles.select { |x| x.name == role.name }.empty?
      roles << role
    end
    return roles
  end

end
