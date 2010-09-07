require 'digest/sha1'
require File.expand_path(File.dirname(__FILE__) + '/core_ext/hash')
require File.expand_path(File.dirname(__FILE__) + '/mysql/connection')

module Snake
  class Issue
    attr_accessor :project_key
    attr_accessor :public_key
    attr_accessor :db_key, :db_count_key
    attr_accessor :attributes, :copies_count
    
    def initialize(options = {})
      @attributes = options.stringify_keys
      
      if valid?
        @project_key = @attributes['project_key']
        
        @public_key = @attributes['public_key'] if @attributes.key?('public_key')
        @public_key ||= self.class.generate_key(@attributes['exception']['class'], 
                                                @attributes['request']['url'],
                                                @attributes['controller'],
                                                @attributes['action'])
        
        @db_key = @attributes['db_key'] if @attributes.key?('db_key')
        @db_key ||= ["projects", @project_key, "issues", @public_key].join(':')
        
        @db_count_key = @attributes['db_count_key'] if @attributes.key?('db_count_key')
        @db_count_key ||= self.class.count_key(@db_key)
      end
    end
    
    def valid?
      @attributes.keys.size > 0
    end
    
    def save(copies_count = 1)
      @copies_count = copies_count
            
      if project_exists?
        update_counters
        if connection.affected_rows == 0
          create
        end
      end
    end
    
    def to_xml
      return nil if @attributes.keys.empty?
      
      @attributes['project_key'] = @project_key
      @attributes['public_key'] = @public_key
      @attributes['db_count_key'] = @db_count_key
      
      @attributes.to_xml(:root => "issue")
    end
    
    def to_json
      {
        :project_key => @project_key,
        :public_key => @public_key,
        :db_key => @db_key,
        :db_count_key => @db_count_key,
      }.to_json
    end
    
    def message
      @message ||= self.class.escape(@attributes['exception']['message'])
      @message
    end
    
    def namespace
      @namespace ||= self.class.escape(@attributes['exception']['class'])
      @namespace
    end
    
    def url
      @url ||= self.class.escape(@attributes['request']['url'])
      @url
    end
    
    def environment
      @environment ||= self.class.escape(@attributes['environment'])
      @environment
    end
    
    def request
      @request ||= self.class.escape(@attributes['request']['parameters'])
      @request
    end
    
    def session
      @session ||= self.class.escape(@attributes['session'])
      @session
    end
    
    def backtrace
      @backtrace ||= self.class.escape(@attributes['backtrace'])
      @backtrace
    end
    
    def host
      @host ||= self.class.escape(@attributes['request']['host'])
      @host
    end
    
    def controller_name
      @controller_name ||= self.class.escape(@attributes['controller'])
      @controller_name
    end
    
    def action_name
      @action_name ||= self.class.escape(@attributes['action'])
      @action_name
    end
    
    def project
      @project ||= (find_project || {})
      @project
    end
    
    def project_exists?
      !project.keys.empty?
    end
        
    class << self
      def escape(value)
        value.blank? ? 'NULL' : connection.escape(value).inspect
      end
      
      def generate_key(*args)
        Digest::SHA1.hexdigest(args.compact.join('--'))
      end
      
      def count_key(db_key)
        "#{db_key}:count"
      end
      
      def from_xml(xml)
        return nil if xml.nil? || xml.length.zero?
        
        options = Hash.from_xml(xml)
        return nil if options['issue'].nil? || options['issue'].keys.empty?        
        
        new(options['issue'])
      end
      
      def connection
        @@connection ||= Snake::Mysql::Connection.instance
        @@connection
      end
    end
    
    protected
    
      def connection
        self.class.connection
      end
      
      def escaped_project_key
        @escaped_project_key ||= connection.escape(self.project_key)
        @escaped_project_key
      end
      
      def escaped_public_key
        @escaped_public_key ||= connection.escape(self.public_key)
        @escaped_public_key
      end
      
      def find_project
        connection.query("SELECT id 
                       FROM `projects` 
                       WHERE public_key = '#{escaped_project_key}' LIMIT 1").first
      end
      
      def update_counters
        project_id = project.has_key?('id') ? project['id'].to_i : 'NULL'
        
        connection.query "UPDATE `issues` 
                         SET `copies_count` = COALESCE(`copies_count`, 0) + #{@copies_count},
                             `state` = 0,
                             `updated_at` = NOW()
                         WHERE `public_key` = '#{escaped_public_key}' AND `project_id` = #{project_id}"
      end
      
      def create
        values = []
            
        values << self.message
        values << self.namespace
        values << self.url
        values << self.environment
        values << self.request
        values << self.session
        values << self.backtrace
        values << project['id']
        values << escaped_public_key.inspect
        values << @copies_count
        values << "NOW()"
        values << "NOW()"
        values << self.controller_name
        values << self.action_name
        values << self.host
        
        connection.query("INSERT INTO `issues`(message, namespace, url, environment, 
                         request, session, backtrace, project_id, public_key, copies_count,
                         created_at, updated_at, controller_name, action_name, host) 
                         VALUES (#{values.join(',')})")
      end
    
  end
end
