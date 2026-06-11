extends GridMap
class_name GridMapWorldGenerator

@export_category("Chunk Settings")
@export var CHUNK_SIZE: int = 16
@export var CHUNK_RENDER_DISTANCE: int = 4
@export var ENABLE_CHUNK_DESPAWNING: bool = true

@export_category("Terrain Settings")
@export var VERTICAL_AMPLITUDE: float = 7.0
@export var VERTICAL_SMOOTHNESS: float = 100.0 

var noise: FastNoiseLite
var player: Node3D

var last_player_chunk = Vector2i(1000000, 1000000)

var active_chunks: Dictionary = {}

# Tracking chunks currently being calculated on background threads
var active_tasks: Dictionary = {} 
# Holds the math data for chunks that are done calculating and ready to be built
var chunks_ready_to_build: Dictionary = {}

const BLOCK_RED = 0
const BLOCK_GREEN = 1
const BLOCK_BLUE = 2
const BLOCK_GRAY = 3
const BLOCK_TEAL = 4

func _ready() -> void:
	noise = FastNoiseLite.new()
	player = get_node("../Player")
	
	if not mesh_library:
		push_error("please assign your MeshLibrary (.tres) to this GridMap node in the inspector.")
		
	cell_size.y = 1.0 / VERTICAL_SMOOTHNESS

func _process(_delta: float) -> void:
	# 1. Update Player Position
	var current_chunk_x = floor(player.position.x / float(CHUNK_SIZE))
	var current_chunk_z = floor(player.position.z / float(CHUNK_SIZE))
	var current_chunk = Vector2i(current_chunk_x, current_chunk_z)
	
	if current_chunk != last_player_chunk:
		last_player_chunk = current_chunk
		update_chunks(current_chunk)

	# 2. Build ONE ready chunk per frame on the main thread
	# Notice how much cleaner this is now! No more checking task_ids.
	if chunks_ready_to_build.size() > 0:
		var chunk_pos = chunks_ready_to_build.keys()[0]
		var block_data = chunks_ready_to_build[chunk_pos]
		
		# Safety Check: Did the player run out of range while the thread was thinking?
		if is_chunk_in_range(chunk_pos, last_player_chunk):
			apply_chunk_to_gridmap(chunk_pos, block_data)
			
		chunks_ready_to_build.erase(chunk_pos)

func update_chunks(player_chunk: Vector2i):
	var chunks_in_range = []
	
	# --- QUEUEING PHASE ---
	for cx in range(-CHUNK_RENDER_DISTANCE, CHUNK_RENDER_DISTANCE + 1):
		for cz in range(-CHUNK_RENDER_DISTANCE, CHUNK_RENDER_DISTANCE + 1):
			var target_chunk = player_chunk + Vector2i(cx, cz)
			chunks_in_range.append(target_chunk)
			
			if not active_chunks.has(target_chunk) and not active_tasks.has(target_chunk) and not chunks_ready_to_build.has(target_chunk):
				queue_chunk_for_generation(target_chunk)

	# --- DESPAWN PHASE ---
	if ENABLE_CHUNK_DESPAWNING:
		var chunks_to_remove = []
		
		for chunk in active_chunks:
			if not chunk in chunks_in_range:
				despawn_chunk(chunk)
				chunks_to_remove.append(chunk)
				
		for chunk in chunks_to_remove:
			active_chunks.erase(chunk)

# Assigns the chunk to a background CPU core
func queue_chunk_for_generation(chunk_pos: Vector2i):
	# Mark it as active so we don't accidentally queue it twice
	active_tasks[chunk_pos] = true 
	WorkerThreadPool.add_task(thread_calculate_chunk.bind(chunk_pos), true)

# --- BACKGROUND THREAD LOGIC ---
func thread_calculate_chunk(chunk_pos: Vector2i):
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_z = chunk_pos.y * CHUNK_SIZE
	var block_data = []
	
	for x in range(start_x, start_x + CHUNK_SIZE):
		for z in range(start_z, start_z + CHUNK_SIZE):
			var generated_noise = noise.get_noise_2d(x, z)
			var float_y = generated_noise * VERTICAL_AMPLITUDE
			var grid_y = round(float_y * VERTICAL_SMOOTHNESS)
			var block_id = get_block_id_from_noise(generated_noise)
			
			block_data.append({
				"pos": Vector3i(x, grid_y, z), 
				"id": block_id
			})
			
	# THE FIX: Tell the main thread to run "_on_chunk_calculated" and hand it the Array safely
	call_deferred("_on_chunk_calculated", chunk_pos, block_data)

# --- NEW: MAIN THREAD RECEIVER ---
# This function receives the data from the background thread safely
func _on_chunk_calculated(chunk_pos: Vector2i, block_data: Array):
	active_tasks.erase(chunk_pos)
	chunks_ready_to_build[chunk_pos] = block_data

# --- MAIN THREAD BUILDER ---
func apply_chunk_to_gridmap(chunk_pos: Vector2i, block_data: Array):
	for block in block_data:
		if get_cell_item(block.pos) == INVALID_CELL_ITEM:
			set_cell_item(block.pos, block.id)
			
	active_chunks[chunk_pos] = true

func despawn_chunk(chunk_pos: Vector2i):
	var start_x = chunk_pos.x * CHUNK_SIZE
	var start_z = chunk_pos.y * CHUNK_SIZE
	
	for x in range(start_x, start_x + CHUNK_SIZE):
		for z in range(start_z, start_z + CHUNK_SIZE):
			var generated_noise = noise.get_noise_2d(x, z)
			var float_y = generated_noise * VERTICAL_AMPLITUDE
			var grid_y = round(float_y * VERTICAL_SMOOTHNESS)
			
			set_cell_item(Vector3i(x, grid_y, z), INVALID_CELL_ITEM)

func is_chunk_in_range(target_chunk: Vector2i, player_chunk: Vector2i) -> bool:
	var dist_x = abs(target_chunk.x - player_chunk.x)
	var dist_y = abs(target_chunk.y - player_chunk.y)
	return dist_x <= CHUNK_RENDER_DISTANCE and dist_y <= CHUNK_RENDER_DISTANCE

func get_block_id_from_noise(noise_value: float) -> int:
	if noise_value <= -0.4: return BLOCK_RED
	elif noise_value <= -0.2: return BLOCK_GREEN
	elif noise_value <= 0: return BLOCK_BLUE
	elif noise_value <= 0.2: return BLOCK_GRAY
	else: return BLOCK_TEAL
