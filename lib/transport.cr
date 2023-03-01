class Transport
    property userAgent : String
    property host : String
    property port : UInt32
    property secure : UInt32

    def initialize()
        @userAgent = "Garen agent 1.0"
        @host = "$TS_IP"
        @port = 40056
        @secure = 40056
    end
end
