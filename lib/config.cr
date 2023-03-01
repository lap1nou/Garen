require "config"
require "transport"

class Config
    property sleeping : LibC::DWORD
    property transport : Transport
    property magicId : String

    def initialize()
        @sleeping = LibC::DWORD.new(5)
        @transport = Transport.new()
        @magicId = String.new(Bytes[0x41, 0x41, 0x41, 0x41])
    end
end