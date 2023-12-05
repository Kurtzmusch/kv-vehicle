extends Node

class_name KVComponent

func _process(delta):
	pass

func _enter_tree():
	get_parent().register(_integrate)

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	return
