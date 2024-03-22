

# Modular, Physics based vehicle addon for Godot 4

## Features:
- flexible
--physics tweaking allows you to make things ranging from arcade to lite-sim
- modular
--pick and choose which features you want
- extensible
--create your own vehicle components
- documented
--no guessing, most variables are documented, even the ones that are not exposed/exported in the godot editor.

## Implemented Components:
- engine
- drivetrain with analogue clutch
- basic infinite torque limited slip differential(can behave as open or locked)
- ls-differential between differentials
- breaks with abs toggle
- input handler(mouse steering, keyboard, or gpad)
- sway bar(anti-roll)

## Core Nodes/Resources

KVVehicle:
- helper physics functions that abstracts away some physics math
- anti-slip on slopes

TireResponse:
- use curves to define tire grip response
- handle audio response for rolling and slipping
- 'fake' surface bumps

KVWheel:
- responsible for applying suspension and tire forces
- helper sub-node to visually position rest-length and max supension travel
- raycast or shapecast(see limitations)

Helper Nodes and extra features:
- particle handler for common uses
- engine sfx audio handler
- center of mass overwriter for visually setting the center of mass
- ackerman ratio helper


## Limitations:
- suspension travels in a straight line, no real or fake suspension geometry yet
- no simracer hardware support yet
- godot's shapecast gets more broken the farther you get from world origin
- since the torque forces on the tires are a feedback system that uses data from the previous frame, some wheel or engine oscilations can happen, a substep sytem is implemented and other tweakable fixes. this is not an issue for arcade games that won't use the physical drivetrain or for low mass vehicles.

## Acknowledgments and similar projects
* [Dechode, open source implementation and sources](https://github.com/Dechode/Godot-Advanced-Vehicle/tree/main)
* [Wolfe, written tutorial of his GDSim vehicle physics](https://www.gtplanet.net/forum/threads/gdsim-v0-4a-autocross-and-custom-setups.396400/) -- [itch.io demo](https://lupine-vidya.itch.io/gdsim)
* [jreo, open source, feature rich simulator](https://github.com/jreo03/g-rcp2) -- [itch.io demo](https://jreo.itch.io/rcp4)

