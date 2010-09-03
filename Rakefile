$LOAD_PATH.unshift File.dirname(__FILE__) + '/../../lib'
require 'resque/tasks'
require 'lib/job'

desc "Start the server using `rackup`"
task :start do
  exec "thin --rackup config.ru start"
end
