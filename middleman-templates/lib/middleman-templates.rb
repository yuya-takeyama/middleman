# Setup our load paths
libdir = File.expand_path(File.dirname(__FILE__))
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

# Require Thor since that's what the whole CLI is built around
require 'thor'
require 'thor/group'

# Templates Module
module Middleman
  module Templates
    # Static methods
    class << self
      # Get list of registered templates and add new ones
      #
      #     Middleman::Templates.register(:ext_name, klass)
      #
      # @param [Symbol] name The name of the template
      # @param [Class] klass The class to be executed for this template
      # @return [Hash] List of registered templates
      def register(name = nil, klass = nil)
        @_template_mappings ||= {}
        @_template_mappings[name] = klass if name && klass
        @_template_mappings
      end

      # Middleman::Templates.register(name, klass)
      alias_method :registered, :register
    end

    # Base Template class. Handles basic options and paths.
    class Base < ::Thor::Group
      include Thor::Actions

      def initialize(names, options)
        super
        source_paths << File.join(File.dirname(__FILE__), 'middleman-templates')
      end

      # The gemfile template to use. Individual templates can define this class
      # method to override the template path.
      def self.gemfile_template
        'shared/Gemfile.tt'
      end

      # Required path for the new project to be generated
      argument :location, type: :string

      # Name of the template being used to generate the project.
      class_option :template, default: 'default'

      # Output a config.ru file for Rack if --rack is passed
      class_option :rack, type: :boolean, default: false

      # Write a Rack config.ru file for project
      # @return [void]
      def generate_rack!
        return unless options[:rack]
        template 'shared/config.ru', File.join(location, 'config.ru')
      end

      # Do not run bundle install
      class_option :'skip-bundle', type: :boolean, default: false

      # Write a Bundler Gemfile file for project
      # @return [void]
      def generate_bundler!
        template self.class.gemfile_template, File.join(location, 'Gemfile')
        return if options[:'skip-bundle']
        inside(location) do
          run('bundle install')
        end unless ENV['TEST']
      end

      # Output a .gitignore file
      class_option :'skip-git', type: :boolean, default: false

      # Write a .gitignore file for project
      # @return [void]
      def generate_gitignore!
        return if options[:'skip-git']
        copy_file 'shared/gitignore', File.join(location, '.gitignore')
      end
    end
  end
end

# Register all official templates
Dir.glob(File.expand_path('../middleman-templates/*.rb', __FILE__), &method(:require))

# Iterate over the directories in the templates path and register each one.
Dir[File.join(Middleman::Templates::Local.source_root, '*')].each do |dir|
  next unless File.directory?(dir)

  template_file = File.join(dir, 'template.rb')

  if File.exists?(template_file)
    require template_file
  else
    Middleman::Templates.register(File.basename(dir).to_sym, Middleman::Templates::Local)
  end
end
