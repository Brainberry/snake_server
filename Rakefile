require File.expand_path('../lib/application', __FILE__)
require 'rake'
require 'resque/tasks'

desc "Start the server using `rackup`"
task :start do
  exec "thin --rackup config.ru start"
end
