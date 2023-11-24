extends Resource

class_name TireResponse

@export var materialName: String
@export var gripMultiplier: float
@export var gripXCurve: Curve
@export var slipAngleBegin: float
@export var slipAngleEnd: float
@export var gripZCurve: Curve
@export var relativeZSpeedBegin: float
@export var relativeZSpeedEnd: float
@export var feedbackCurve: Curve

func getCoeficients(localVelocity, radsPerSec, radius):
	var slipAngleDeg = rad_to_deg(localVelocity.signed_angle_to(Vector3.FORWARD, Vector3.UP))
	var relativeZSpeed = (radsPerSec*radius)-localVelocity.z
	
	var xRange = slipAngleEnd-slipAngleBegin
	var xSamplePosition = clamp( abs(slipAngleDeg), slipAngleBegin, slipAngleEnd )
	xSamplePosition = (xSamplePosition-slipAngleBegin)/xRange
	
	var zRange = relativeZSpeedEnd-relativeZSpeedBegin
	var zSamplePosition = clamp( abs(relativeZSpeed), relativeZSpeedBegin, relativeZSpeedEnd )
	zSamplePosition = (zSamplePosition-relativeZSpeedBegin)/zRange
	
	var samplePosition = max(xSamplePosition, zSamplePosition)
	var x = gripXCurve.sample_baked(samplePosition)
	var z = gripZCurve.sample_baked(samplePosition)
	
	var feedbackRange = slipAngleEnd
	var feedbackSamplePosition = clamp( abs(slipAngleDeg), 0.0, slipAngleEnd )
	var feedback = feedbackCurve.sample_baked(feedbackSamplePosition/feedbackRange)
	
	return Vector3(x*gripMultiplier, feedback, z*gripMultiplier)
