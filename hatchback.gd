extends Label

@export var frontWheels: Array[KVWheel]
@export var drivetrain: KVDrivetrain
@export var centralLSD: KVCentralLSDifferential

var mode = 0
var centralLSDLimit
func _ready():
	centralLSDLimit = centralLSD.limit

func _process(delta):
	pass

func _unhandled_input(event):
	if event.is_action_pressed('toggle-rear-steering'):
		mode += 1
		mode %= 2
		if mode == 1:
			for wheel in frontWheels:
				drivetrain.poweredWheels.erase(wheel)
				wheel.powered = false
				centralLSD.limit = 1024*1024
			
		if mode == 0:
			for wheel in frontWheels:
				drivetrain.poweredWheels.append(wheel)
				centralLSD.limit = centralLSDLimit
			
		drivetrain.updatePoweredWheels()
		print(drivetrain.poweredWheels)
