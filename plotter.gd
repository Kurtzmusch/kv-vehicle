extends Control

var normal = 2500
var patchLen = 0.2
var slipZ = 0.0
var ease = 0.2
var peakAngleDeg = 15.0
var tire_stiffness = 2.0

func redraw():
	$zero.clear_points()
	$kEase.clear_points()
	$brushWolfie.clear_points()
	$brushGanta.clear_points()
	
	$zero.add_point(Vector2(0, 270))
	$zero.add_point(Vector2(960, 270.0))
	
	var xScale = 1.0
	
	var step=8
	
	var yScale = 100.0
	
	var coeficientOfFriction = 1.0

	
	#$30dg.add_point(Vector2(30*, 270))
	for i in range(96*step):
		var slipAngleDeg = i/8.0
		#var slipAngle = deg_to_rad(slipAngleDeg)
		var forceX = kEase(normal, slipAngleDeg, coeficientOfFriction, patchLen).x
		var point = Vector2(i*xScale, 270-(forceX/normal*yScale) )
		$kEase.add_point( point )
		
		forceX = brushWolfie(normal, slipAngleDeg, coeficientOfFriction, patchLen).x
		point = Vector2(i*xScale, 270-(forceX/normal*yScale) )
		$brushWolfie.add_point( point )
		
		forceX = brushGanta(normal, slipAngleDeg, coeficientOfFriction, patchLen).x
		point = Vector2(i*xScale, 270-(forceX/normal*yScale) )
		$brushGanta.add_point( point )

func _ready():
	redraw()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func brushGanta(normal, slipAngleDeg, coeficientOfFriction, patchLen):
	# https://skill-lync.com/student-projects/Longitudinal-brush-tire-model-50471
	var stiffness = tire_stiffness*500000
	var alphaC = normal*coeficientOfFriction/(2*stiffness)
	var angleRads = deg_to_rad(slipAngleDeg)
	var forces = Vector3.ZERO
	var maxFriction = normal*coeficientOfFriction
	if angleRads < alphaC:
		forces.x = stiffness*angleRads
	else:
		forces.x = maxFriction - pow(maxFriction, 2.0)/(4.0*stiffness*tan(angleRads))
	return forces

func kEase(normal, slipAngle, coeficientOfFriction, patchLen):
	
	var peakAngle = deg_to_rad(peakAngleDeg)
	var forces = Vector3.ZERO
	var normalizedAngle = clamp(deg_to_rad(slipAngle)/peakAngle, 0.0, 1.0)
	forces.x = normal*coeficientOfFriction*ease(normalizedAngle, ease)
	return forces

func brushWolfie(normal, slipAngle, coeficientOfFriction, patchLen):
	
	var slip = Vector3.ZERO
	slip.x = deg_to_rad(slipAngle)
	slip.y = slipZ
	
	
	var stiffness = 500000 * tire_stiffness * pow(patchLen, 2)
 
	var friction = coeficientOfFriction * normal
	var deflect = sqrt(pow(stiffness * slip.y, 2) + pow(stiffness * tan(slip.x), 2))

	if deflect == 0:  return Vector2.ZERO
	else:
		var vector = Vector2.ZERO
		var crit_length = friction * (1 - slip.y) * patchLen / (2 * deflect)
		if crit_length >= patchLen:
			vector.y = stiffness * -slip.y / (1 - slip.y)
			vector.x = stiffness * tan(slip.x) / (1 - slip.y)
		else:
			var brushy = (1 - friction * (1 - slip.y) / (4 * deflect)) / deflect
			vector.y = friction * stiffness * -slip.y * brushy
			vector.x = friction * stiffness * tan(slip.x) * brushy
		return vector


func _on_spin_box_normal_value_changed(value):
	normal = value
	redraw()

func _on_spin_box_patch_len_value_changed(value):
	patchLen = value
	redraw()


func _on_spin_box_slip_z_value_changed(value):
	slipZ = value
	redraw()


func _on_spin_box_ease_value_changed(value):
	ease = value
	redraw()


func _on_spin_box_peak_value_changed(value):
	peakAngleDeg = value
	redraw()


func _on_spin_box_stiffness_value_changed(value):
	tire_stiffness = value
	redraw()
