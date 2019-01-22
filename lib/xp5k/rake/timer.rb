module XP5K
  module Rake
    class Timer

      @@initial_timer = nil
      @@current = nil
      @@ignore_summary = false

      attr_accessor :start_time, :stop_time, :task_name, :parent, :childs

      def initialize(name)
        @start_time = Time.now
        @stop_time = nil
        @parent = nil
        @childs ||= []
        @task_name = name
        @@initial_timer ||= self
        if @@current
          if @@current.stop_time
            @parent = @@current.parent
          else
            @parent = @@current
          end
        end
        @@current = self
      end

      def self.ignore_summary(value)
        @@ignore_summary = value
      end

      def stop()
        @stop_time = Time.now
        self.parent.childs << self if self.parent
        @@current = self.parent
      end

      def self.summary
        level = 1
        return if @@ignore_summary
        @@initial_timer.stop unless @@initial_timer.stop_time
        puts "|   " * (level - 1) + "|-- #{@@initial_timer.task_name} : #{self.duration(@@initial_timer)}"
        timer = @@initial_timer
        until (@@initial_timer.childs.count == 0 and level == 0) do
          if timer.childs.count > 0
            timer = timer.childs.shift
            level += 1
            puts "|   " * (level - 1) + "|-- #{timer.task_name} -> #{self.duration(timer)}"
          else
            level -= 1
            timer = timer.parent
          end
        end

      end

      private

      def self.duration(timer)
        Time.at(timer.stop_time - timer.start_time).utc.strftime("%Hh %Mm %Ss")
      end

    end
  end
end

