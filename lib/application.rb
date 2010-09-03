require File.expand_path('../boot', __FILE__)

require File.expand_path('../redis/connection', __FILE__)
require File.expand_path('../issue', __FILE__)
require File.expand_path('../job', __FILE__)

Bundler.require(:default, :production) if defined?(Bundler)

module Snake
  class Application
    def initialize(app = nil, options = {})
      @app = app
      @handler = Snake::Redis::Connection.instance(options)
      
      yield self if block_given?
    end
    
    def call(env, options={})
      request = ::Rack::Request.new(env)
      issue = Snake::Issue.new(request.params)
      
      return render_xml("<errors><error code='1'>Issue invalid</error></errors>", 422) unless issue.valid?
      
      begin
        if @handler.exists(issue.db_key)
          @handler.incr(issue.db_count_key)
        else
          @handler[issue.db_key] = issue.to_xml
        end
        
        Resque.enqueue(Job, issue.db_key)
        
        render_xml("<issue><state>Created</state></issue>")
	    rescue Errno::ECONNREFUSED
	      # If Redis-server is not running, instead of throwing an error, we simply do not throttle the API
	      # It's better if your service is up and running but not throttling API, then to have it throw errors for all users
	      # Make sure you monitor your redis-server so that it's never down. monit is a great tool for that.
	      render_xml("<errors><error code='2'>Redis-server is not running</error></errors>", 500)
	    end
    end
    
    def render_xml(xml, status = 200)
      [status, { 'Content-Type' => 'application/xml' }, "<?xml version='1.0' encoding='utf-8'?>#{xml}"]
    end
  end
end
