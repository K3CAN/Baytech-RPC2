# Background

This is for an older version, which I had orignally written in perl. 
I'm FAR more comfortable with perl than python, so it was my initial go-to. 

While this perl version works, the python version is easier to use within Home Assistant. 


--------------------------------------


# WIP - rpcoulets

I was given a Baytech RPC-2 (managed, rack-mounted PDU) for free, and I wanted to put it to use in my homelab. The problem was that the RPC-2 was made back in Y2K and integrating it into my lab was going to be a little tricky. 

## Hardware

I had to start by building a cable for it. It uses an RJ45 plug for a serial connection. While it looks similar to the ubiquitous blue cisco cables, the pinout is different, meaning I needed to build a custom one.  I found a PDF of the old Baytech manual, which luckily has some diagrams for both the DB9-RJ45 adaptor and the RJ45-RJ45 rollover cable. I was able to combine the two diagrams and create a single DB9-RJ45 cable. Which, it turns out, I accidentally built mirrored. After a few more attempts, I got the cable sorted out, and now that I had the physical connection made, the next step was to make a data connection. 

## Adventures in Serial Communication

I found picocom and set to work learning a little more about serial terminal communication. After a few failed attempts, I was finally greeted by the RPC-2 serial console!  I now had a fully functioning connection to the RPC-2, but controlling it required opening a terminal session on a system physically connected to the RPC-2, then opening the serial console, then finally typing out the commands. It's not the 2000s any more, and I really wanted a cleaner, simpler way to interface with the device. 

**My eventual goal was to integrate this into Home Assistant for automations.**

I discovered that if I had picocom open in another terminal, I could echo a command to the /dev/tty device and then see the RPC-2 respond to that command in picocom. To anyone more experienced with serial devices, this shouldn't be surprising, but this was my first time attempting to directly interact with something over a serial console and it gave me a solid idea of what I needed to do next. 

I started by writing a perl script that would simply print a command to the /dev/tty device. After figuring out what line terminator is needed (newline? carraige return?), like the echo command, I could see the RPC-2 respond to the script in picocom. Since that seemed to work, I built out the script a little further to include passing the actions I wanted as command line arguments, like "rpcoutlets on 3" to turn on outlet 3. Everything seemed to be going well, until I closed picocom. Evidently, picocom was doing _something_ to help facilitate that serial communication, because when it was closed, the script stopped functioning. 

Apparently the computer needed to send some sort of signal to the device before it would listen for a command, and then that signal was removed when the connection was closed. As long as I had picocom connected, the RPC-2 would happily listen for and respond to commands, but as soon as picocom "hung up", the connection was closed and the RPC unit just ignored the serial port. I eventually concluded that I'd have to do something a little fancier than simply printing commands to a tty filehandle. 
Enter: "Device::SerialPort." This _is_ perl, after all, so of course there's a module I can use. Despite this, it still ended up taking a bit of trial and error, because I still didn't fully grasp the intricacies of serial communication. Regardless, I eventually was able to use the Device::SerialPort module to successfully open a connection to the RPC-2 and send the needed commands.  
Perfect, now just to integrate the command into Home Assistant.

## Home Assistant

Now, I just needed to bring this shell command into the HA interface somehow. My first attempt was via `Shell_Command` which lets you call a CLI command from a script or automation. I set:
```
shell_command:
    rpcoutlets: config/my_scripts/rpcoutlets {{flip}} {{num}}
```
Then I created a "Helper" unit as a boolean called "rpc switch 1", followed by an automation that called:
```
 Shell_command.rpcoutlet
	Flip: on
	Num: 1
```
When the state of the boolean helper was turned "on".
…Then a *second* automation for when the switch was turned "off" 

That's one "helper" and two automations *per outlet*, or a full dozen automations for the single PDU. 

I thought that this seemed like a ridiculous amount of work and that there had to be an easier way.  I actually tried asking a generative AI for how they would accomplish this, and while their response didn't work at all (seemed to be based on an older version on HA), it _did_ show me something I missed: the `Command_Line` integration. 

While this _seems_ like it would essentially be an alias of `Shell Command`, it actually supports a native "switch" function, where you can automatically create a switch entity (no need for a "helper") and assign it commands for both on and off without any additional automations or shenanigans. 

Here's how that looked:
```
command_line:
    - switch:
        name: RPC Outlet 1
        command_on: 'config/my_scripts/rpcoutlets on 1'
        command_off: 'config/my_scripts/rpcoutlets off 1'
    - switch:
        name: RPC Outlet 2
        command_on: 'config/my_scripts/rpcoutlets on 2'
        command_off: 'config/my_scripts/rpcoutlets off 2'
```

**FINALLY**, I had an effective and _sane_ way to trigger my commands from the HA interface.

![My outlets in a Home Assistant "Glance" card](/physical/ha-card.png)
