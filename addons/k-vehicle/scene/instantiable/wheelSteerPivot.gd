@tool
extends Node3D

## sets current Y position as rest extension
@export var setRest = false: set = doSetPositionAsRestExtension
## sets current Y position as max extension
@export var setMax = false: set = doSetPositionAsMaximumExtension

@export var restExtension = 0.0
@export var maxExtension = 0.0

func _ready():
	pass

func _process(delta):
	pass

func doSetPositionAsRestExtension(do):
	if !do: return
	restExtension = position.y

func doSetPositionAsMaximumExtension(do):
	if !do: return
	maxExtension = position.y
