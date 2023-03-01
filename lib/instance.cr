require "session"
require "config"

class Instance
    property session : Session
    property config : Config

    def initialize()
        @session = Session.new()
        @config = Config.new()
    end
end