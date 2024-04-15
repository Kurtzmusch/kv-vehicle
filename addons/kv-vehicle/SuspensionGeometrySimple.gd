extends SuspensionGeometry

class_name SuspensionGeometrySimple

@export var radsPerMeter = 0.75
@export var neutralCamber = 0.0

func applyGeometryTransform(vehicle:KVVehicle, wheel:KVWheel, pivotNode:Node3D, wheelPivotPositionY):
	pivotNode.position.y = wheelPivotPositionY+wheel.wheelVisualPositionYOffset
	var deltaFromRest = (wheel.restExtension-(-wheelPivotPositionY))
	var sideSign = sign(wheel.position.x)
	pivotNode.rotation.z = (neutralCamber*sideSign)+( deltaFromRest*radsPerMeter*sideSign )
