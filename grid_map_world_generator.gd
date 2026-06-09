extends GridMap
class_name GridMapWorldGenerator

@export_category("Chunk Settings")
@export var CHUNK_SIZE: int = 16
# How many chunks in every direction to load around the player. 2 means a 5x5 chunk grid.
@export var CHUNK_RENDER_DISTANCE: int = 2 
@export var ENABLE_CHUNK_DESPAWNING: bool = true

@export_category("Terrain Settings")
@export var VERTICAL_AMPLITUDE: float = 7.0
@export var VERTICAL_SMOOTHNESS: float = 100.0 

var noise: FastNoiseLite
var player: Node3D

# We now track the player's position in CHUNKS, not individual blocks
var last_player_chunk = Vector2i(1000000, 1000000) # Set to arbitrary high number to force initial generation

# A dictionary to track which chunks are currently spawned
var active_chunks: Dictionary = {}

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

func _process(delta: float) -> void:
    # 1. Convert player world coordinates to Chunk Coordinates
    # We use floor() and float division to handle negative world coordinates correctly
    var current_chunk_x = floor(player.position.x / float(CHUNK_SIZE))
    var current_chunk_z = floor(player.position.z / float(CHUNK_SIZE))
    var current_chunk = Vector2i(current_chunk_x, current_chunk_z)
    
    # 2. Only update the world if the player crosses a chunk boundary
    if current_chunk != last_player_chunk:
        last_player_chunk = current_chunk
        update_chunks(current_chunk)

func update_chunks(player_chunk: Vector2i):
    var chunks_in_range = []
    
    # --- GENERATION PHASE ---
    # Loop through a grid of chunks centered on the player
    for cx in range(-CHUNK_RENDER_DISTANCE, CHUNK_RENDER_DISTANCE + 1):
        for cz in range(-CHUNK_RENDER_DISTANCE, CHUNK_RENDER_DISTANCE + 1):
            var target_chunk = player_chunk + Vector2i(cx, cz)
            chunks_in_range.append(target_chunk)
            
            # If the chunk isn't loaded yet, generate it
            if not active_chunks.has(target_chunk):
                generate_chunk(target_chunk)

    # --- DESPAWN PHASE ---
    if ENABLE_CHUNK_DESPAWNING:
        var chunks_to_remove = []
        
        # Check all currently loaded chunks
        for chunk in active_chunks:
            # If a loaded chunk is no longer in our local range, queue it for deletion
            if not chunk in chunks_in_range:
                despawn_chunk(chunk)
                chunks_to_remove.append(chunk)
                
        # Remove them from our tracking dictionary safely
        for chunk in chunks_to_remove:
            active_chunks.erase(chunk)

func generate_chunk(chunk_pos: Vector2i):
    # Convert chunk coordinates back to world coordinates for the start of the loop
    var start_x = chunk_pos.x * CHUNK_SIZE
    var start_z = chunk_pos.y * CHUNK_SIZE
    
    for x in range(start_x, start_x + CHUNK_SIZE):
        for z in range(start_z, start_z + CHUNK_SIZE):
            var generated_noise = noise.get_noise_2d(x, z)
            var float_y = generated_noise * VERTICAL_AMPLITUDE
            var grid_y = round(float_y * VERTICAL_SMOOTHNESS)
            
            if get_cell_item(Vector3i(x, grid_y, z)) == INVALID_CELL_ITEM:
                var block_id = get_block_id_from_noise(generated_noise)
                set_cell_item(Vector3i(x, grid_y, z), block_id)
                
    # Mark this chunk as active so we don't generate it again
    active_chunks[chunk_pos] = true

func despawn_chunk(chunk_pos: Vector2i):
    var start_x = chunk_pos.x * CHUNK_SIZE
    var start_z = chunk_pos.y * CHUNK_SIZE
    
    for x in range(start_x, start_x + CHUNK_SIZE):
        for z in range(start_z, start_z + CHUNK_SIZE):
            # Recalculate the Y position to find exactly where the block is to delete it
            var generated_noise = noise.get_noise_2d(x, z)
            var float_y = generated_noise * VERTICAL_AMPLITUDE
            var grid_y = round(float_y * VERTICAL_SMOOTHNESS)
            
            set_cell_item(Vector3i(x, grid_y, z), INVALID_CELL_ITEM)

func get_block_id_from_noise(noise_value: float) -> int:
    if noise_value <= -0.4: return BLOCK_RED
    elif noise_value <= -0.2: return BLOCK_GREEN
    elif noise_value <= 0: return BLOCK_BLUE
    elif noise_value <= 0.2: return BLOCK_GRAY
    else: return BLOCK_TEAL