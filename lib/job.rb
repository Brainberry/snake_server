require 'resque'
require File.expand_path(File.dirname(__FILE__) + '/redis/connection')
require File.expand_path(File.dirname(__FILE__) + '/issue')

module Snake
  module Job
    @queue = :issues
    
    def self.perform(db_key)
      @handler = Snake::Redis::Connection.instance
      
      db_count_key = Snake::Issue.count_key(db_key)
      
      xml = @handler[db_key]
      copies_count = @handler[db_count_key] || 1
      
      @handler.del(db_key)
      @handler.del(db_count_key)
      @handler.quit
      
      @issue = Snake::Issue.from_xml(xml)
      @issue.save(copies_count) if @issue
    end
  end
end
