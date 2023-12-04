extends TextureRect

@export var vehicle: Node
var steerWheels = []
# Called when the node enters the scene tree for the first time.
func _ready():
	return

func _process(delta):
	steerWheels.clear()
	for wheel in vehicle.wheels:
		if wheel.steer:
			steerWheels.append(wheel)
	position.x = get_viewport_rect().size.x*0.5
	position.y = (get_viewport().get_mouse_position()).y
	var avgFeedback = 0.0
	if steerWheels.size() > 0:
		for wheel in steerWheels:
			avgFeedback += wheel.feedback
	avgFeedback/=steerWheels.size()
	if abs(avgFeedback) < 1.0:
		scale.x = 1.0+abs(avgFeedback)*12.0
		scale.y = 1.0
	else:
		scale.x = 1.0
		scale.y = 4.0
