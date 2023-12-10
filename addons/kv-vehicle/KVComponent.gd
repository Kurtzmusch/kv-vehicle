extends Node
## base class for creating vehicle components like breaks, drivetrains, etc
##
## components will register themselves to the parent vehicle when they _enter_tree.
## registerd components must overwrite _integrate, which is called in the vehicle's _integrate_forces callback

class_name KVComponent

func _process(delta):
	pass

func _enter_tree():
	get_parent().register(_integrate)

func _integrate(delta, oneByDelta, modDelta, oneBySubstep):
	return
