require File.expand_path(File.dirname(__FILE__) + '/../core_ext/settingslogic')

module Snake
  module Mysql
    class Config < Settingslogic
      source "config/database.yml"
      #namespace Rails.env
    end
  end
end
