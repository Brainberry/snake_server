require 'resque'
require 'mysql2'

require File.expand_path(File.dirname(__FILE__) + '/redis/connection')
require File.expand_path(File.dirname(__FILE__) + '/mysql/connection')
require File.expand_path(File.dirname(__FILE__) + '/issue')

module Snake
  module Job
    @queue = :file_serve
    
    def self.perform(db_key)
      @handler = Snake::Redis::Connection.instance
      @client = Snake::Mysql::Connection.instance
      
      db_count_key = Snake::Issue.count_key(db_key)
      
      xml = @handler[db_key]
      copies_count = @handler[db_count_key] || 1
      
      @handler.delete(db_key)
      @handler.delete(db_count_key)
      @handler.quit
      
      @issue = Snake::Issue.from_xml(xml)
      
      if @issue && @issue.has_project?
        @client ||= Snake::Mysql::Connection.instance
        
        # TODO escape public_key and other attributes
        @client.query "UPDATE `issues` 
                       SET `copies_count` = COALESCE(`copies_count`, 0) + #{copies_count},
                           `state` = 0,
                           `updated_at` = NOW()
                       WHERE `public_key` = #{@issue.public_key.inspect} AND `project_id` = #{@issue.project_id}"
                       
        if @client.affected_rows == 0
          values = []
          
          values << @issue.message
          values << @issue.namespace
          values << @issue.url
          values << @issue.environment
          values << @issue.request
          values << @issue.session
          values << @issue.backtrace
          values << @issue.project_id
          values << @issue.public_key.inspect
          values << copies_count
          values << "NOW()"
          values << "NOW()"
          values << @issue.controller_name
          values << @issue.action_name
          values << @issue.host
          
          @client.query("INSERT INTO issues (message, namespace, url, environment, 
                           request, session, backtrace, project_id, public_key, copies_count,
                           created_at, updated_at, controller_name, action_name, host) 
                          VALUES (#{values.join(',')})")
        end     
      end      
    end
  end
end
