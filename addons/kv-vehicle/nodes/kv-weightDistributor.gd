extends Node
## computes and updates the weightDistribution of [KVWheel]s

class_name KVWeightDistributor

@export var centerOfMass: KVCenterOfMass
@export var frontWheels: Array[KVWheel]
@export var rearWheels: Array[KVWheel]

func _ready():
	var total = frontWheels[0].to_local(rearWheels[0].global_position).z
	var com = frontWheels[0].to_local(centerOfMass.global_position).z
	var ratio = com/total
	print(ratio)
	for wheel in frontWheels:
		wheel.weightDistribution = 0.5*(1.0-ratio)
		wheel.updateWeightDistribution()
	for wheel in rearWheels:
		wheel.weightDistribution = 0.5*(ratio)
		wheel.updateWeightDistribution()
