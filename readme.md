# WIP - rpcoulets

I was given a Baytech RPC-2 (managed, rack-mounted PDU) for free, and I wanted to put it to use in my homelab. The problem was that the RPC-2 was made back in Y2K and integrating it into my lab was going to be a little tricky. 

## Hardware

I had to start by building a cable for it. It uses an RJ45 plug for a serial connection. While it looks similar to the ubiquitous blue cisco cables, the pinout is different, meaning I needed to build a custom one.  I found a PDF of the old Baytech manual, which luckily has some diagrams for both the DB9-RJ45 adaptor and the RJ45-RJ45 rollover cable. I was able to combine the two diagrams and create a single DB9-RJ45 cable. Which, it turns out, I accidentally built mirrored. After a few more attempts, I got the cable sorted out, and now that I had the physical connection made, the next step was to make a data connection. 

## Adventures in Serial Communication

I found picocom and set to work learning a little more about serial terminal communication. After a few failed attempts, I was finally greeted by the RPC-2 serial console!  I now had a fully functioning connection to the RPC-2, but controlling it required opening a terminal session on a system physically connected to the RPC-2, then opening the serial console, then finally typing out the commands. It's not the 2000s any more, and I really wanted a cleaner, simpler way to interface with the device. 

**My eventual goal was to integrate this into Home Assistant.**

I discovered that if I had picocom open in another terminal, I could echo a command to the /dev/tty device and then see the RPC-2 respond to that command in picocom. To anyone more experienced with serial devices, this shouldn't be surprising, but this was my first time attempting to directly interact with something over a serial console and it gave me a solid idea of what I needed to do next. 

I started by writing a perl script that would simply print a command to the /dev/tty device. After figuring out what line terminator is needed (newline? carraige return?), like the echo command, I could see the RPC-2 respond to the script in picocom. Since that seemed to work, I built out the script a little further to include passing the actions I wanted as command line arguments, like "rpcoutlets on 3" to turn on outlet 3. Everything seemed to be going well, until I closed picocom. Evidently, picocom was doing _something_ to help facilitate that serial communication, because when it was closed, the script stopped functioning. 

Apparently the computer needed to send some sort of signal to the device before it would listen for a command, and then that signal was removed when the connection was closed. As long as I had picocom connected, the RPC-2 would happily listen for and respond to commands, but as soon as picocom "hung up", the connection was closed and the RPC unit just ignored the serial port. I eventually concluded that I'd have to do something a little fancier than simply printing commands to a tty filehandle. 
Enter: "Device::SerialPort." This _is_ perl, after all, so of course there's a module I can use. Despite this, it still ended up taking a bit of trial and error, because I still didn't fully grasp the intricacies of serial communication. Regardless, I eventually was able to use the Device::SerialPort module to successfully open a connection to the RPC-2 and send the needed commands.  
Perfect, now just to integrate the command into Home Assistant…. 

## Home Assistant - Attempt 1

Well, after a LOT of swearing and frustration, I actually gave up (for a while) on trying to integrate it into Home Assistant. The problem was mostly due to the way Home Assistant OS operates. Everything runs in containers, and it wasn't clear to me at the time what was actually running where. I could SSH into the HA instance and run the command without issue, but when I tried to make Home Assistant itself call the command, it reported that the command wasn't found. Weird… Well, I'm stumped. Time to give up for a bit. 

## Good enough?

Anyway, since the perl script itself did work when called directly, I added a component into the script itself that would automate one of the functions that I had originally wanted Home Assistant to do: turn on my server rack's case fan when a system got too warm. Using lm_sensors, I added a case where if the script was called without any arguments at all, it would go into "service mode" and periodically poll the motherboard temperature and activate outlet 5 (the case fan) if it went over a certain threshold. I then added a systemd unit for the script and left it alone for a little while. While it was far from perfect, and it wasn't exactly what I wanted, it was good enough for the time. 

But good enough isn't good enough forever. 

## Home Assistant - Attempt 2 

I finally dove back into the mess more recently, stubbornly adamant that there _must_ be some way I could bring it into HA. 

Digging further into the inner-workings of HA, I found that HAOS is essentially a super stripped down distro that just runs a handful of docker containers. If you access the system through the console, you're accessing the base OS, which is _not_ where HA actually runs it's commands; rather, HA actually runs commands within a docker container called "homeassistant". 
To make matters _more_ confusing, if you SSH into the system, you're actually dropped into yet another, different container. So, if a command works fine when you're connected via console, that doesn't mean it will work over SSH or in HA. If a command works over SSH, it probably still won't work over a console connection or within HA. By the way, fun fact: both the SSH container and the HA container have perl, but the base OS doesn't, in case you were wondering.   

After finally starting to untangle the workings of HAOS; needlessly installing perl into the base OS and then needlessly installing cpan, gcc, and g++ in an attempt to build Device::SerialPort, not once, but twice _(only to later learn that it's available directly via "apk")_;  I finally got everything situated in the correct container and was able `docker exec` my script and watch the light on the RPC-2 turn on and off. 
And just like that, I was onto the last step of the puzzle. 

## Home Assistant - Attempt 2 - part B. 

Now, I just needed to bring this shell command into the HA interface somehow. My first attempt was via `Shell_Command` which lets you call a CLI command from a script or automation. I set:
```
shell_command:
    rpcoutlets: /usr/local/bin/rpcoutlets {{flip}} {{num}}
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
        command_on: '/usr/local/bin/rpcoutlets on 1'
        command_off: '/usr/local/bin/rpcoutlets off 1'
    - switch:
        name: RPC Outlet 2
        command_on: '/usr/local/bin/rpcoutlets on 2'
        command_off: '/usr/local/bin/rpcoutlets off 2'
```

**FINALLY**, I had an effective and _sane_ way to trigger my commands from the HA interface.

![My outlets in a Home Assistant "Glance" card](/ha-card.png)

## Next steps
Now that it's all working, the next step is deciding how to make this a persistent part of my HA instance. As mentioned, HA itself runs within a Docker container, so it's normal process of pulling a new image for each update means that my changes will get erased every time it updates. 

Either I build this out into a full-fledge integration... Or I just automate the process of installing perl and loading my script after each update. 
