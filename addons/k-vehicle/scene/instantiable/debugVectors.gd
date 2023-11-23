extends MeshInstance3D

var im: ImmediateMesh
# Called when the node enters the scene tree for the first time.
func _ready():
	im = mesh

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	top_level = true
	global_transform = Transform3D()
	
func clear():
	im.clear_surfaces()

func addVector(globalPosition, vector, color=Color.MAGENTA):
	if !visible: return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(color)
	im.surface_add_vertex(globalPosition)
	im.surface_add_vertex(globalPosition+vector)
	im.surface_end()
