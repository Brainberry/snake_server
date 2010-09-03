#require "lib/settingslogic"
require File.expand_path(File.dirname(__FILE__) + '/../core_ext/settingslogic')

module Snake
  module Redis
    class Config < Settingslogic
      source "config/redis.yml"
      #namespace Rails.env
    end
  end
end
