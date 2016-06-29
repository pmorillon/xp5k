module Rake
  class Task

    alias_method :rake_execute, :execute

    def execute(args=nil)
      timer = XP5K::Rake::Timer.new(name)
      puts "--> Execute task #{name}"
      rake_execute(args)
      timer.stop
    end

  end
end
