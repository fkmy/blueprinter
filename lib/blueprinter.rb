# frozen_string_literal: true

require_relative 'blueprinter/base'
require_relative 'blueprinter/configuration'
require_relative 'blueprinter/extension'

module Blueprinter
  class << self
    # @return [Configuration]
    def configuration
      @_configuration ||= Configuration.new
    end

    def configure
      yield(configuration) if block_given?
    end

    # Resets global configuration.
    def reset_configuration!
      @_configuration = nil
    end
  end
end
