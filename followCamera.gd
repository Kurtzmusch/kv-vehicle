extends Camera3D

@export var height = 1.5
@export var distance = 8.0
@export var lerpFactor = 0.125
@export var target: Node
@export var orbitSpeed = Vector3.ONE*1.0/1024.0

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			translate_object_local(Vector3(-event.velocity.x, event.velocity.y, 0.0)*orbitSpeed)

func _physics_process(delta):
	if Input.is_key_pressed(KEY_1): current = true
	var dir = global_position.direction_to(target.global_position)
	var dirOnVehicle = dir*target.global_transform.basis.inverse()
	dirOnVehicle*=distance
	dirOnVehicle.y = -height
	dir = dirOnVehicle*target.global_transform.basis
	var targetPosition = target.global_position-dir
	global_position = global_position.lerp(targetPosition, lerpFactor)
	look_at(target.global_position)
