# Garen
Small Havoc agent made for fun, PoC only

## Install
1) Clone https://github.com/HavocFramework/havoc-py and put it on your teamserver along with `Garen.py`
2) Modify the Teamserver IP in the `transport.cr` file
3) Compile main.cr using `crystal.exe build --link-flags "iphlpapi.lib" .\main.cr`, since cross compilation doesn't really exist in Crystal you have to compile it on a Windows machine
4) Start the Teamserver, the handler `Garen.py`, and the client `./Havoc`
5) Agent should connect back normally

## Available function
shell, download, upload

## References
- Havoc
- https://github.com/HavocFramework/Talon
- https://github.com/CodeXTF2/PyHmmm
