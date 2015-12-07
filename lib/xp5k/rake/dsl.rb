require 'xp5k/role'
require 'net/ssh/multi'
require 'timeout'
require 'thread'

module XP5K
  module Rake
    module DSL

      private

      def role(*args, &block)
        hosts = []
        procblock = nil
        if block_given?
          raise 'Arguments not allowed with block' unless args[1].nil?
          procblock = block
        else
          case args[1]
          when String
            hosts = [args[1]]
          when Array
            hosts = args[1]
          else
            raise "Role <#{args.first}> argument must be a String or an Array"
          end
        end

        XP5K::Role.new(name: args.first, size: hosts.length, servers: hosts, proc: procblock).add

      end


      def roles(*args)
        hosts = []
        args.each do |rolename|
          hosts << XP5K::Role.findByName(rolename).servers
        end
        hosts.flatten!
      end

      #
      def on(hosts, *args, &block)

        logs = Hash.new { |h,k| h[k] = '' }
        errors = Hash.new { |h,k| h[k] = '' }
        ssh_session = {}
        current_server = ""
        all_connected = false
        failed_servers = []
        hosts = [hosts] if hosts.class == String

        XP5K::Config[:user] ||= ENV["USER"]
        XP5K::Config[:gateway] ||= XP5K::Config[:user] + "@access.grid5000.fr"

        commands = (args.last.class == String or args.last.class == Array) ? (args.last.class == String ? [args.pop] : args.pop ) : []
        options = args.last.class == Hash ? args.pop : {}
        options[:user] ||= 'root'
        options[:environment] ||= {}
        cmd_env = options[:environment].map do |key, value|
          "#{key}=#{value}"
        end

        if block_given?
          case result = yield
          when String
            commands << result
          when Array
            commands.push(result).flatten!
          else
            raise "<on> block must return String or Array"
          end
        end

        until all_connected
          failed = false
          gateway_options = {}
          gateway_options[:config] == XP5K::Config[:ssh_config] ? true : XP5K::Config[:ssh_config]
          gateway_user, gateway_host = XP5K::Config[:gateway].match(/^(?:([^;,:=]+)@|)(.*?)$/)[1,2]
          gateway = Net::SSH::Gateway.new(gateway_host, gateway_user)
          workq = Queue.new
          hosts.each{ |host| workq << host }
          workers = (0...10).map do
            Thread.new do
              begin
                while host = workq.pop(true)
                  begin
                    timeout(5) do
                      ssh_session[host] = gateway.ssh(host, options[:user])
                      puts "Connected to #{host}..."
                    end
                  rescue Timeout::Error, Net::SSH::Disconnect, Exception => e
                    puts "Removing #{host} (#{e.message})..."
                    hosts.delete host
                    failed_servers << host
                    failed = true
                  end
                end

              rescue ThreadError
              end

            end
          end; "ok"
          workers.map(&:join); "ok"

          all_connected = true if !failed
        end

        workq = Queue.new
        hosts.each{ |host| workq << host }
        workers = (0...10).map do
          Thread.new do
            begin
              while host = workq.pop(true)
                begin
                  commands.each do |command|
                    command.prepend(cmd_env.join(' ') + ' ') unless cmd_env.empty?
                    puts "[command][#{host}] #{command}"
                    ssh_session[host].exec!(command) do |channel, stream, data|
                      logs[host] << data
                      errors[host] << data if stream == :err
                      puts "[#{stream}][#{host}] #{data}" if data.chomp != ""
                    end
                  end
                rescue Exception => e
                  puts "[#{host}] " + e.message
                end
              end
            rescue ThreadError
            end
          end
        end; "ok"
        workers.map(&:join); "ok"

        # Print the result sorting by hostname
        errors.sort.each do |error|
          puts "---- stderr on #{error.first} #{"-" * (get_width - error.first.length - 16)} "
          puts "#{error[1]}"
        end
        logs.sort.each do |key, value|
          puts "---- #{key} #{"-" * (get_width - key.length - 6)}"
          puts value
        end
        puts "Servers unreachable : #{failed_servers.inspect}" if !failed_servers.empty?

        # Clean all ssh connections
        puts "Closing ssh connections..."
        hosts.each do |host|
          ssh_session[host].close
          gateway.close ssh_session[host].transport.port
        end
        gateway.shutdown!

      end

      def run(command)

      end

      def get_width
        result = `tput cols`
        result.to_i
      end

    end
  end
end
