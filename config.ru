#!/usr/bin/env ruby
require File.expand_path('../lib/application', __FILE__)
require 'resque/server'

use Rack::Lint
use Rack::ShowExceptions
use Rack::Reloader, 0
use Rack::ContentLength

resque_app = Rack::Auth::Basic.new(Resque::Server.new) do |username, password|
  'secret' == password
end

resque_app.realm = 'Snake Application'

run Rack::URLMap.new("/" => proc {|env| [200, {"Content-Type" => "text/html"}, "Hello my friend!"]},
                     "/issues" => Snake::Application.new, 
                     "/resque" => Rack::ShowStatus.new(resque_app))

