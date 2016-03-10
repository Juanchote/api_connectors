require "api_connector/version"
require 'api_connector/api_connector'
require 'active_support/core_ext/hash/keys'
require 'logger'

module ApiConnector
  def self.new(options={})
    @conn = Connectors::ApiConnector.new(options)
  end
end
