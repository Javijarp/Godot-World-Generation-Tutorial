extends Label

func _process(_delta: float) -> void:
    # Engine.get_frames_per_second() pulls the built-in frame rate counter
    text = "FPS: " + str(Engine.get_frames_per_second())
