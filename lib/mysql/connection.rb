require 'mysql2'
require File.expand_path(File.dirname(__FILE__) + '/config')

module Snake
  module Mysql
    class Connection
      class << self
        def instance(options = {})
          options = Snake::Mysql::Config.new.merge(options).symbolize_keys
          
          client = Mysql2::Client.new(options)
        end
      end
    end
  end
end
