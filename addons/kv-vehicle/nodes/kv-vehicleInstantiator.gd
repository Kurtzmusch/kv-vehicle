@tool
@icon("res://addons/k-vehicle/city-car.svg")
extends Node3D
## use this to instantiate a KVVehicle scene with its dependency tree 

class_name KVVehicleInstantiator
var scene = preload("res://addons/kv-vehicle/scene/instantiable/kv-vehicle.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _enter_tree():
	var newVehicle = scene.instantiate()
	
	get_parent().add_child(newVehicle)
	newVehicle.owner = get_tree().get_edited_scene_root()
	#get_parent().set_editable_instance(newKWheel, true);
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
