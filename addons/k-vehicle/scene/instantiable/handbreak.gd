extends KVComponent
class_name KVHandbreak
## break that automatically presses the clutch

@export var wheels: Array[KVWheel]

## make it very strong on the rear wheels to help initiate a spin or drift
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
