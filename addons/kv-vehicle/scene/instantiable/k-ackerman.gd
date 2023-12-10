extends Node
## computes and updates the ackermanRatio of [KVWheel]s

class_name KVAckerman

@export var steeringPair: Array[KVWheel]
@export var staticPair: Array[KVWheel]

func _ready():
	
	var frontRight = steeringPair[0]
	var frontLeft = steeringPair[1]
	var rearRight = staticPair[0]
	if rearRight.position.x < 0:
		rearRight = staticPair[1]
	if frontRight.position.x < 0:
		frontRight = steeringPair[1]
		frontLeft = steeringPair[0]
	
	var localFRPos = get_parent().to_local(frontRight.global_position)
	var localRRPos = get_parent().to_local(rearRight.global_position)
	
	var Zdist = abs(localFRPos.z - localRRPos.z)
	var maxAngle = frontRight.maxSteerAngle
	var xDist = tan(0.5*PI -maxAngle)*Zdist
	var pos = localFRPos
	pos.z += Zdist
	pos.x -= xDist
	pos.y -= 0.5
	
	var localFLPos = localFRPos
	localFLPos.x *= -1.0
	xDist = abs(localFLPos.x - pos.x)
	var hip = sqrt( pow(xDist, 2) + pow(Zdist, 2) )
	var angle = acos(Zdist/hip)
	angle = 0.5*PI-angle
	var ratio = angle/maxAngle
	
	for wheel in steeringPair:
		wheel.updateAckerman(ratio)


func _process(delta):
	pass
