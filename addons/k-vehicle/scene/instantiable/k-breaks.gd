extends KVComponent
## applies break torque to wheels
class_name KVBreak

@export var wheels: Array[KVWheel]

## torque applied to each wheel, tipically, front breaks are stronger, as the tractions increases in the front tires during breaking.
@export var strength = 2000.0

var vehicle
func _ready():
	vehicle = get_parent()

func _process(delta):
	pass

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	var str = vehicle.break2Input
	for wheel in wheels:
		wheel.applyBreakTorque(strength*str, modDelta)
