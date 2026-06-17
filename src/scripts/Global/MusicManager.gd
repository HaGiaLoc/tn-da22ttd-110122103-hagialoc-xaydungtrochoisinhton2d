extends AudioStreamPlayer

@export var tracks: Dictionary = {} ## Key: Tên tình huống (String), Value: File nhạc (AudioStream)

var _fade_tween: Tween

enum MusicState {
	MENU,
	WIN,
	LOSE,
	DAY,
	COMBAT
}

var current_state: MusicState = MusicState.MENU
var day_index: int = 1
var combat_index: int = 1

var enemies_detecting_player: int = 0

var _delay_timer: Timer

func _ready() -> void:
	bus = &"Music"
	process_mode = Node.PROCESS_MODE_ALWAYS
	finished.connect(_on_track_finished)

func play_state(new_state: MusicState, fade_duration: float = 1.0) -> void:
	print("[MusicManager] play_state called with state: ", MusicState.keys()[new_state])
	current_state = new_state
	_play_current_state_track(fade_duration)

func _play_current_state_track(fade_duration: float = 1.0) -> void:
	if _delay_timer and not _delay_timer.is_stopped():
		print("[MusicManager] Stopping 30s delay timer to play new track immediately.")
		_delay_timer.stop()

	var track_name = ""
	match current_state:
		MusicState.MENU: track_name = "menu"
		MusicState.WIN: track_name = "win"
		MusicState.LOSE: track_name = "lose"
		MusicState.DAY: track_name = "day_" + str(day_index)
		MusicState.COMBAT: track_name = "combat_" + str(combat_index)
	
	play_track(track_name, fade_duration)

func _on_track_finished() -> void:
	print("[MusicManager] Track finished: ", stream.resource_path if stream else "Unknown")
	if current_state == MusicState.DAY:
		day_index += 1
		if day_index > 3:
			day_index = 1
		_queue_next_track_with_delay(30.0)
	elif current_state == MusicState.COMBAT:
		combat_index += 1
		if combat_index > 4:
			combat_index = 1
		_queue_next_track_with_delay(30.0)

func _queue_next_track_with_delay(delay: float) -> void:
	print("[MusicManager] Queuing next track in ", delay, " seconds...")
	if not _delay_timer:
		_delay_timer = Timer.new()
		_delay_timer.one_shot = true
		_delay_timer.timeout.connect(func(): 
			print("[MusicManager] 30s Delay finished. Playing next track.")
			_play_current_state_track(0.0)
		)
		add_child(_delay_timer)
		
	_delay_timer.start(delay)

func register_enemy_detection(is_detecting: bool) -> void:
	if is_detecting:
		enemies_detecting_player += 1
	else:
		enemies_detecting_player -= 1
		if enemies_detecting_player < 0:
			enemies_detecting_player = 0
			
	print("[MusicManager] register_enemy_detection: ", is_detecting, " | Total enemies tracking: ", enemies_detecting_player)
	_update_game_music_state()

func _update_game_music_state() -> void:
	if current_state == MusicState.DAY or current_state == MusicState.COMBAT:
		var target_state = MusicState.COMBAT if enemies_detecting_player > 0 else MusicState.DAY
		if current_state != target_state:
			print("[MusicManager] Switching state from ", MusicState.keys()[current_state], " to ", MusicState.keys()[target_state])
			current_state = target_state
			_play_current_state_track(1.0)

func play_track(track_name: String, fade_duration: float = 1.0) -> void:
	if not tracks.has(track_name):
		push_warning("MusicManager: Không có track tên là '%s'" % track_name)
		return
		
	var new_stream = tracks[track_name] as AudioStream
	if not new_stream:
		push_warning("MusicManager: Track '%s' bị trống (chưa gắn file nhạc)" % track_name)
		return
		
	if stream == new_stream and playing:
		print("[MusicManager] Track '", track_name, "' is already playing.")
		return
		
	print("[MusicManager] Playing track: ", track_name, " with fade: ", fade_duration)
		
	_crossfade_to(new_stream, fade_duration)

func _crossfade_to(new_stream: AudioStream, duration: float) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null
		
	if playing and duration > 0:
		_fade_tween = create_tween()
		_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_fade_tween.tween_property(self, "volume_db", -40.0, duration / 2.0)
		_fade_tween.tween_callback(func():
			stream = new_stream
			play()
		)
		_fade_tween.tween_property(self, "volume_db", 0.0, duration / 2.0)
	elif duration > 0:
		stream = new_stream
		volume_db = -40.0
		play()
		_fade_tween = create_tween()
		_fade_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_fade_tween.tween_property(self, "volume_db", 0.0, duration)
	else:
		stream = new_stream
		volume_db = 0.0
		play()

func stop_music(fade_duration: float = 1.0) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		
	if fade_duration > 0 and playing:
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "volume_db", -40.0, fade_duration)
		_fade_tween.tween_callback(stop)
		_fade_tween.tween_callback(func(): volume_db = 0.0) # Reset lại âm lượng
	else:
		stop()


