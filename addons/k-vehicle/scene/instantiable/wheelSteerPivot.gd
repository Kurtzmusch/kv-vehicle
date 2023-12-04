@tool
extends Node3D

## sets current Y position as rest extension
@export var setRest = false: set = doSetPositionAsRestExtension
## sets current Y position as max extension
@export var setMax = false: set = doSetPositionAsMaximumExtension

## y position of the wheel when the vehicle is resting on the ground
@export var restExtension = 0.0
## y position of the wheel when the vehicle is jumping or suspended in the air
@export var maxExtension = 0.0

func _ready():
	pass

func _process(delta):
	pass

func _physics_process(delta):
	get_node("../shapecastPivot").basis = basis

func doSetPositionAsRestExtension(do):
	if !do: return
	restExtension = position.y

func doSetPositionAsMaximumExtension(do):
	if !do: return
	maxExtension = position.y
