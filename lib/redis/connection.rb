require 'logger'
require 'redis'
require File.expand_path(File.dirname(__FILE__) + '/config')

module Snake
  module Redis
    class Connection
      class << self
        def instance(options = {})
          options = Snake::Redis::Config.new.merge(options)
          
          # Logger
          unless options[:logger]
            logfile = File.open(File.expand_path(File.dirname(__FILE__) + '/../../log/redis.log'), 'a')
            logfile.sync = true
            options[:logger] = Logger.new(logfile)
          end
          
          Resque.redis = ::Redis.new(options)
          ::Redis::Namespace.new(:snake, :redis => Resque.redis)
        end
      end
    end
  end
end
