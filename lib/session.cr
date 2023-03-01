class Session
    property agentID : Int32
    property osArch : LibC::DWORD
    property connected : Bool
    property config : Config

    enum CommandId
        COMMAND_REGISTER = 0x100
        COMMAND_GET_JOB = 0x101
        COMMAND_NO_JOB = 0x102
        COMMAND_SHELL = 0x152
        COMMAND_UPLOAD = 0x153
        COMMAND_DOWNLOAD = 0x154
        COMMAND_EXIT = 0x155
        COMMAND_OUTPUT = 0x200
    end

    def initialize()
        @config = Config.new()
        @agentID = Random.rand(Int32::MAX - 1)
        @osArch = LibC::DWORD.new(0)
        @connected = false
    end

    def agentIDString() : String
        raw = uninitialized UInt8[4]
        IO::ByteFormat::BigEndian.encode(self.agentID, raw.to_slice)
        return String.new(raw.to_slice)
    end
end