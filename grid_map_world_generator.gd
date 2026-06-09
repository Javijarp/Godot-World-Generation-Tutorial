extends GridMap
class_name GridMapWorldGenerator

@export var GENERATION_BOUND_DISTANCE = 16
@export var VERTICAL_AMPLITUDE = 7
var noise
var player

var last_player_grid_pos = Vector2i.ZERO

const BLOCK_RED = 0
const BLOCK_GREEN = 1
const BLOCK_BLUE = 2
const BLOCK_GRAY = 3
const BLOCK_TEAL = 4

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	noise = FastNoiseLite.new()
	player = get_node("../Player")
	
	if not mesh_library:
		push_error("please assign your MeshLibrary (.tres) to this GridMap node in the inspector.")
	generate_new_cubes_from_position(last_player_grid_pos.x, last_player_grid_pos.y)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var current_grid_x = round(player.position.x)
	var current_grid_z = round(player.position.z)
	var current_grid_pos = Vector2i(current_grid_x, current_grid_z)
	
	if current_grid_pos != last_player_grid_pos:
		last_player_grid_pos = current_grid_pos
		generate_new_cubes_from_position(current_grid_x, current_grid_z)

func generate_new_cubes_from_position(player_x: int, player_z: int):
	var start_x = player_x - GENERATION_BOUND_DISTANCE
	var end_x = player_x + GENERATION_BOUND_DISTANCE
	var start_z = player_z - GENERATION_BOUND_DISTANCE
	var end_z = player_z + GENERATION_BOUND_DISTANCE

	for x in range(start_x, end_x):
		for z in range(start_z, end_z):
			generate_cube_if_new(x, z)

func generate_cube_if_new(x: int, z: int):
	# GridMap handles checking if a cell is empty natively via get_cell_item()
	# -1 means the grid coordinate is empty/unallocated
	var generated_noise = noise.get_noise_2d(x, z)
	var y_pos = round(generated_noise * VERTICAL_AMPLITUDE)
	
	if get_cell_item(Vector3i(x, y_pos, z)) == INVALID_CELL_ITEM:
		var block_id = get_block_id_from_noise(generated_noise)
		
		# Set_cell_item instantiates the mesh and the collision instantly 
		# without flooding your scene tree with unique nodes.
		set_cell_item(Vector3i(x, y_pos, z), block_id)

func get_block_id_from_noise(noise_value: float) -> int:
	if noise_value <= -0.4: return BLOCK_RED
	elif noise_value <= -0.2: return BLOCK_GREEN
	elif noise_value <= 0: return BLOCK_BLUE
	elif noise_value <= 0.2: return BLOCK_GRAY
	else: return BLOCK_TEAL
