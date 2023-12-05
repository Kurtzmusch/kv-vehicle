extends KVComponent

@export var wheels: Array[KVWheel]
@export var strength = 20000.0

var vehicle

func _ready():
	vehicle = get_parent()

func _process(delta):
	pass

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	
	if Input.is_action_pressed("handbreak"):
		for wheel in wheels:
			wheel.applyBreakTorque(strength, modDelta)
		vehicle.clutchInput = 1.0
	else:
		vehicle.clutchInput = 0.0
