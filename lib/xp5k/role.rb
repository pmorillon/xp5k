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

end
