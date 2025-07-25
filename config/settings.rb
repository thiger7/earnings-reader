require 'settingslogic'

class Settings < Settingslogic
  source File.join(File.dirname(__FILE__), 'settings.yml')

  # 環境を自動検出
  def self.detect_environment
    return 'test' if defined?(RSpec)

    ENV['RAILS_ENV'] || ENV['RACK_ENV'] || 'development'
  end

  namespace detect_environment
  load!
end
