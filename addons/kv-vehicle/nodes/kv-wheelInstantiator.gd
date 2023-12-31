@tool
@icon("res://addons/k-vehicle/car-wheel.svg")
extends Node3D
## use this to instantiate a KVWheel scene with its dependency tree 
class_name KVWheelInstantiator
var scene = preload("res://addons/kv-vehicle/scene/instantiable/kv-wheel.tscn")

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.

func _enter_tree():
	var newKWheel = scene.instantiate()
	
	get_parent().add_child(newKWheel)
	newKWheel.owner = get_tree().get_edited_scene_root()
	#get_parent().set_editable_instance(newKWheel, true);
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
