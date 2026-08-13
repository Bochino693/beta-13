extends Node

const MUSIC_PATHS := {
	"intro": "res://assets/audio/intro_theme.wav",
	"menu": "res://assets/audio/menu_loop.wav",
	"battle": "res://assets/audio/battle_loop.wav",
	"victory": "res://assets/audio/victory_theme.wav"
}

const SFX_PATHS := {
	"move": "res://assets/audio/ui_move.wav",
	"confirm": "res://assets/audio/confirm.wav",
	"cancel": "res://assets/audio/cancel.wav",
	"coin": "res://assets/audio/coin.wav",
	"hit": "res://assets/audio/hit.wav",
	"special": "res://assets/audio/special.wav",
	"guard": "res://assets/audio/guard.wav",
	"knockout": "res://assets/audio/knockout.wav",
	"victory": "res://assets/audio/victory.wav",
	"dodge": "res://assets/audio/dodge.wav"
}

var _music_player: AudioStreamPlayer
var _ambience_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _music_theme := ""
var _stadium_ambience_enabled := false


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -10.0
	_music_player.finished.connect(_restart_music)
	add_child(_music_player)
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.volume_db = -23.0
	_ambience_player.finished.connect(_restart_stadium_ambience)
	add_child(_ambience_player)
	for _index in 8:
		var player := AudioStreamPlayer.new()
		player.volume_db = -4.0
		add_child(player)
		_sfx_players.append(player)


func start_music(theme: String) -> void:
	if not MUSIC_PATHS.has(theme):
		push_warning("Tema de música inexistente: %s" % theme)
		return
	if _music_theme == theme and _music_player.playing:
		return
	_music_theme = theme
	_play_current_music()


func stop_music() -> void:
	_music_theme = ""
	_music_player.stop()


func start_stadium_ambience() -> void:
	_stadium_ambience_enabled = true
	_play_stadium_ambience()


func stop_stadium_ambience() -> void:
	_stadium_ambience_enabled = false
	_ambience_player.stop()


func set_enabled(enabled: bool) -> void:
	if not enabled:
		_music_player.stop()
		_ambience_player.stop()
		for player in _sfx_players:
			player.stop()
	else:
		if not _music_theme.is_empty():
			_play_current_music()
		if _stadium_ambience_enabled:
			_play_stadium_ambience()


func ui_move() -> void:
	_play_sfx("move")


func ui_confirm() -> void:
	_play_sfx("confirm")


func ui_cancel() -> void:
	_play_sfx("cancel")


func dodge() -> void:
	_play_sfx("dodge", randf_range(0.96, 1.04), -1.0)


func beast_roar(creature: Dictionary) -> void:
	var creature_id := str(creature.get("id", ""))
	if creature_id.is_empty():
		return
	var path := "res://assets/audio/beasts/%s_roar.wav" % creature_id
	var weight := float(creature.get("weight_kg", 60.0))
	var pitch := clampf(1.10 - weight / 700.0, 0.78, 1.08)
	_play_path(path, pitch, 1.5)


func coin() -> void:
	_play_sfx("coin")


func hit(power: float = 1.0) -> void:
	_play_sfx("hit", clampf(0.88 + power * 0.12, 0.9, 1.08), linear_to_db(clampf(power, 0.65, 1.25)))


func special_hit() -> void:
	_play_sfx("special")


func guard() -> void:
	_play_sfx("guard")


func knockout() -> void:
	_play_sfx("knockout")


func victory() -> void:
	_play_sfx("victory")


func _play_current_music() -> void:
	if not GameState.sound_enabled or _music_theme.is_empty():
		return
	var path: String = MUSIC_PATHS[_music_theme]
	if not ResourceLoader.exists(path):
		push_error("Música não encontrada: %s" % path)
		return
	_music_player.stream = load(path) as AudioStream
	_music_player.play()


func _restart_music() -> void:
	if not _music_theme.is_empty() and GameState.sound_enabled:
		_music_player.play()


func _play_stadium_ambience() -> void:
	if not GameState.sound_enabled or not _stadium_ambience_enabled:
		return
	var path := "res://assets/audio/stadium_ambience.wav"
	if not ResourceLoader.exists(path):
		push_error("Ambiência não encontrada: %s" % path)
		return
	_ambience_player.stream = load(path) as AudioStream
	_ambience_player.play()


func _restart_stadium_ambience() -> void:
	if _stadium_ambience_enabled and GameState.sound_enabled:
		_ambience_player.play()


func _play_sfx(effect_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not GameState.sound_enabled or not SFX_PATHS.has(effect_name) or _sfx_players.is_empty():
		return
	var path: String = SFX_PATHS[effect_name]
	_play_path(path, pitch, volume_db)


func _play_path(path: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not GameState.sound_enabled or _sfx_players.is_empty():
		return
	if not ResourceLoader.exists(path):
		push_error("Efeito de áudio não encontrado: %s" % path)
		return
	var player := _sfx_players[_sfx_cursor]
	_sfx_cursor = (_sfx_cursor + 1) % _sfx_players.size()
	player.stop()
	player.stream = load(path) as AudioStream
	player.pitch_scale = pitch
	player.volume_db = -4.0 + volume_db
	player.play()
