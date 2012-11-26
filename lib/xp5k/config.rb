module XP5K
  class Config
    # Create a singleton
    @@config = Hash.new

    @@config[:debug] = false
    @@config[:user] = ENV['USER']
    @@config[:public_key] = File.join(ENV['HOME'], ".ssh", "id_rsa.pub")

    @@config[:loaded] = false

    # Load the experiment configuration file
    def self.load
      if File.exist?(File.expand_path(File.join(XP5K::ROOT_PATH, "xp.conf")))
        file_path = File.expand_path(File.join(XP5K::ROOT_PATH, "xp.conf"))
        self.instance_eval(IO.read(file_path),file_path, 1)
      end
      @@config[:loaded] = true
    end # def:: self.load

    def self.loaded?
      @@config[:loaded]
    end

    # Configuration options getter
    def self.[](opt)
      @@config[opt.to_sym]
    end # def:: self.[](opt)

    # Configuration options setter
    def self.[]=(opt, value)
      @@config[opt.to_sym] = value
    end # def:: self.[]=(opt, value)

    # Using methods in configuration file and transform into hash keys
    def self.method_missing(method_symbol, *args)
      @@config[method_symbol] = args[0]
      @@config[method_symbol]
    end # def:: self.method_missing(method_symbol), *args)

  end # class:: Config
end # module:: XP
