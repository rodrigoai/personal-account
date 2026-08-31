require_relative "boot"
require "rails/all"

Bundler.require(*Rails.groups)

module PersonalAccount
  class Application < Rails::Application
    config.load_defaults 7.2
    config.autoload_lib(ignore: %w[assets tasks])
    config.time_zone = "America/Sao_Paulo"
    config.generators.system_tests = nil
  end
end
