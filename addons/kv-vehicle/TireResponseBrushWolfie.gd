extends TireResponse

## the interesting thing about this method is that it makes the buildup curve to be similar to a softer tire as normal load increases
## [br] this means that for smaller steering inputs, the weight transfer effect is smaller, but you can still get a lot of friction with more steering
class_name TireResponseBrushWolfie

## tire stiffness is internally multiplied by 500000 for convenience
@export var tireStiffness = 4


@export var contactPatchLength = 0.2


func getFrictionForces(localVelocity, radsPerSec, radius, slipAngle, desiredFrictionVec, gripMultiplier, normalForce, loadFactor, normalForceAtRest):
	var coeficients = getCoeficientsBrush(localVelocity, radsPerSec, radius, normalForce)
	var normalForceModified = normalForce
	var frictionForce
	if is_nan(coeficients.x): coeficients.x = coeficientOfFriction
	if is_nan(coeficients.z): coeficients.z = coeficientOfFriction
	# seems that wolfie brush implementation already handles adjusting the final vector direction
	# while the vector direction seems correct, clamping individual is still necessary
	frictionForce = clampIndividual(desiredFrictionVec, coeficients, gripMultiplier, normalForceModified )
	
	#frictionForce = dontClamp(desiredFrictionVec, coeficients, gripMultiplier, normalForceModified )
	return frictionForce

func dontClamp(desiredFrictionVec, coeficients, gripMultiplier, normalForce ):
	
	var xFriction = coeficients.x*gripMultiplier.x*normalForce
	var zFriction = coeficients.z*gripMultiplier.z*normalForce
	#zFriction = coeficients.z*gripMultiplier.x*maxedSuspensionForce
	#xFriction = coeficients.x*suspensionForceMagnitude
	xFriction *= sign(desiredFrictionVec.x)
	zFriction *= sign(desiredFrictionVec.z)
	
	return Vector3(xFriction, coeficients.y, zFriction)

func clampIndividual(desiredFrictionVec, coeficients, gripMultiplier, normalForce ):
	
	var xFriction = min(abs(desiredFrictionVec.x), coeficients.x*gripMultiplier.x*normalForce)
	var zFriction = min(abs(desiredFrictionVec.z), coeficients.z*gripMultiplier.z*normalForce)
	#zFriction = coeficients.z*gripMultiplier.x*maxedSuspensionForce
	#xFriction = coeficients.x*suspensionForceMagnitude
	xFriction *= sign(desiredFrictionVec.x)
	zFriction *= sign(desiredFrictionVec.z)
	
	return Vector3(xFriction, coeficients.y, zFriction)

func getCoeficientsBrush(localVelocity, radsPerSec, radius, normal):
	
	
	var relativeZSpeed = (radsPerSec*radius)-localVelocity.z
	var slipRatio = 0.000976562
	if not localVelocity.z == 0:
		slipRatio = relativeZSpeed / abs(localVelocity.z)
	var slip = Vector3.ZERO
	
	slip.x = localVelocity.signed_angle_to(Vector3.FORWARD, Vector3.UP)
	slip.z = -slipRatio
	
	
	#wolfe's brush implementation from https://www.gtplanet.net/forum/threads/gdsim-v0-4a-autocross-and-custom-setups.396400/#post-13395986
	#divided by normal to return a coeficient instead of raw force
	var stiffness = 500000 * tireStiffness * pow(contactPatchLength, 2)
 
	var friction = coeficientOfFriction * normal
	var deflect = sqrt(pow(stiffness * slip.z, 2) + pow(stiffness * tan(slip.x), 2))

	if deflect == 0:  return Vector3.ZERO
	else:
		var vector = Vector3.ZERO
		var crit_length = friction * (1 - slip.z) * contactPatchLength / (2 * deflect)
		if crit_length >= contactPatchLength:
			vector.z = stiffness * -slip.z / (1 - slip.z)
			vector.x = stiffness * tan(slip.x) / (1 - slip.z)
		else:
			var brushy = (1 - friction * (1 - slip.z) / (4 * deflect)) / deflect
			vector.z = friction * stiffness * -slip.z * brushy
			vector.x = friction * stiffness * tan(slip.x) * brushy
		vector = vector.abs()
		vector.y = vector.x #force feedback same as x coeficient for now
		return vector/normal
