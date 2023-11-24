extends Node

@export var wheels: Array[Node]
@export var strength = 20000.0
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _integrate(delta):
	if Input.is_action_pressed("handbreak"):
		for wheel in wheels:
			wheel.applyBreakTorque(strength, delta)
