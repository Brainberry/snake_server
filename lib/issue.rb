require 'digest/sha1'
require File.expand_path(File.dirname(__FILE__) + '/core_ext/hash')
require File.expand_path(File.dirname(__FILE__) + '/crypto')

module Snake
  class Issue
    attr_accessor :project_key
    attr_accessor :public_key
    attr_accessor :db_key, :db_count_key
    attr_accessor :attributes
    
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
    
    def project_id
      @project_id ||= self.class.parse(@project_key)      
      @project_id
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
    
    def has_project?
      !(project_id.nil? || project_id.zero?)
    end
    
    class << self
      def escape(value)
        value.blank? ? 'NULL' : value.inspect
      end
      
      def generate_key(*args)
        Digest::SHA1.hexdigest(args.compact.join('--'))
      end
      
      def count_key(db_key)
        "#{db_key}:count"
      end
      
      def parse(project_key)
        value = Crypto.decrypt(project_key)
        unless value.blank?
          arr = value.split(':')
          arr[1].to_i if arr.length == 3
        end
      rescue ArgumentError => e
        return nil
      end
      
      def from_xml(xml)
        return nil if xml.nil? || xml.length.zero?
        
        options = Hash.from_xml(xml)
        return nil if options['issue'].nil? || options['issue'].keys.empty?
        
        new(options['issue'])
      end
    end
  end
end
