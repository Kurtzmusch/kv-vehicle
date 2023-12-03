extends Camera3D

var vehicle
# Called when the node enters the scene tree for the first time.
func _ready():
	vehicle = get_parent()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if get_parent().freeze: return
	if Input.is_key_pressed(KEY_2):
		current = true
	var direction = vehicle.linear_velocity.normalized().slerp(-vehicle.global_transform.basis.z, 0.125)
	var bas = global_transform.basis
	look_at( global_position + direction )
	global_transform.basis = bas.slerp(global_transform.basis, 0.125)
