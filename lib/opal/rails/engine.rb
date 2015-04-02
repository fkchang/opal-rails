require 'rails'
require 'opal/sprockets/server'
require 'opal/sprockets/processor'

module Opal
  module Rails
    class Engine < ::Rails::Engine
      config.app_generators.javascript_engine :opal

      config.opal = ActiveSupport::OrderedOptions.new
      # new default location, override-able in a Rails initializer
      config.opal.spec_location = "spec-opal"

      # Cache eager_load_paths now, otherwise the assets dir is added
      # and its .rb files are eagerly loaded.
      config.eager_load_paths

      config.before_initialize do |app|
        app.config.eager_load_paths = app.config.eager_load_paths.dup - Dir["#{app.root}/app/{assets,views}"]
      end

      initializer 'opal.asset_paths', :after => 'sprockets.environment', :group => :all do |app|
        Opal.paths.each do |path|
          app.assets.append_path path
        end
        app.assets.append_path "#{app.root}/#{config.opal.spec_config}"
      end

      config.after_initialize do |app|
        require 'opal/rails/haml_filter' if defined?(Haml)
        require 'opal/rails/slim_filter' if defined?(Slim)

        config = app.config
        config.opal.each_pair do |key, value|
          key = "#{key}="
          Opal::Processor.send(key, value) if Opal::Processor.respond_to? key
        end

        app.routes.prepend do
          if Opal::Processor.source_map_enabled
            prefix = app.config.assets.prefix
            maps_app = Opal::SourceMapServer.new(app.assets, prefix)
            mount Rack::Cascade.new([maps_app, app.assets]) => prefix
          end

          get '/opal_spec' => 'opal_spec#run'
          get '/opal_spec_files/*path' => 'opal_spec#file'
        end
      end

    end
  end
end
