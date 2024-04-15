extends Resource

class_name SuspensionGeometry

func applyGeometryTransform(vehicle:KVVehicle, wheel:KVWheel, pivotNode:Node3D, wheelPivotPositionY):
	pivotNode.position.y = wheelPivotPositionY+wheel.wheelVisualPositionYOffset
