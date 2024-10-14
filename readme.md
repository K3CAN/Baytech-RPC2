# rpcoutlets
## Controling a Baytech RPC-2 from Home Assistant

![screenshot of Home Assistant Card](/ha-card.png)

This is a simple component to add switches for a Baytech RPC-2 PDU. 
Information about the physical connections can be found in the [/physical](/physical/) folder of this repo. 

## Install

Installation is as simple as adding the [script](/rpcoutlets.py) to the /config folder of Home Assistant (or a subdirectory) and then adding the individual commands to the configuation.yaml. 

Example configuration.yaml, assuming that the script was added to /congif/myscripts/

```
command_line:
    - switch:
        name: RPC Outlet 1
        command_on: '/config/my_scripts/rpcoutlets.py on 1'
        command_off: '/config/my_scripts/rpcoutlets.py off 1'
    - switch:
        name: RPC Outlet 2
        command_on: '/config/my_scripts/rpcoutlets.py on 2'
        command_off: '/config/my_scripts/rpcoutlets.py off 2'
    - switch:
        name: RPC Outlet 3
        command_on: '/config/my_scripts/rpcoutlets.py on 3'
        command_off: '/config/my_scripts/rpcoutlets.py off 3'
    - switch:
        name: RPC Outlet 5
        command_on: '/config/my_scripts/rpcoutlets.py on 5'
        command_off: '/config/my_scripts/rpcoutlets.py off 5'
    - switch:
        name: RPC Outlet 4
        command_on: '/config/my_scripts/rpcoutlets.py on 4'
        command_off: '/config/my_scripts/rpcoutlets.py off 4'
    - switch:
        name: RPC Outlet 6
        command_on: '/config/my_scripts/rpcoutlets.py on 6'
        command_off: '/config/my_scripts/rpcoutlets.py off 6'
```

## Outside of Home Assistant
Of course, this script also works fine outside of HA, if you just need a quicker way to access an RPC-2. The command line interface is simple:
`rpcoutlets [on|off|read] [1..6]`


## Limitations
Currently, there does not appear to be a reliable way to periodically poll for the status of each switch. My script can query the RPC-2 through the "read" argument, but because of how long the RPC-2 takes to process each command, polling too frequently can result in commands being missed entirely. 

If you would like to try adding polling to your instance, you can expand each line in the config like so: 

```
command_line:
  - switch:
      name: RPC Outlet 1
      command_on: "/config/my_scripts/rpcoutlets.py.py on 1"
      command_off: "/config/my_scripts/rpcoutlets.py.py off 1"
      command_state: '/config/my_scripts/rpcoutlets.py.py read 1'
      value_template: '{{ value == "On" }}'
      scan_interval: 500
```