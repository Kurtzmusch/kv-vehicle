extends MeshInstance3D


# Called when the node enters the scene tree for the first time.

func _enter_tree():
	get_parent().center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	get_parent().center_of_mass = position

func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
