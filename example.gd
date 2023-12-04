extends WorldEnvironment


# Called when the node enters the scene tree for the first time.
func _ready():
	$world/Camera3D.vehicleUI = $UI
	$UI.setVehicle($world/Camera3D.target)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
