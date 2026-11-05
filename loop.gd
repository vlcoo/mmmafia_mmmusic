extends Control

var PATH = "C:/parts/" if OS.is_debug_build() else "./parts/"
const DEFAULT_SEGMENT_NAMES = [
	"I move",
	"Quiet in the",
	"Fear",
]
const DEFAULT_BG_NAME = "Mafia Music.wav"
const TIME_WORD_MARGIN = 0.15
const TIME_VERSE = 3.83

var audio_fg: AudioStreamPlayer:
	get:
		if audio_fg1.playing: return audio_fg2
		return audio_fg1
@onready var audio_fg1: AudioStreamPlayer = $AudioVoice1
@onready var audio_fg2: AudioStreamPlayer = $AudioVoice2
@onready var audio_bg: AudioStreamPlayer = $AudioBackground
@onready var timer: Timer = $Timer
@onready var label: Label = $Label

var current_segment := 0
var max_segment := 2
var next_verse_pending := false
var last_modulo := 0.0
var verse_text := ""
var delay := 0.0
var just_looped := false


func _ready() -> void:
	var bg_path = PATH.path_join("background.wav")
	if not FileAccess.file_exists(bg_path):
		bg_path = PATH.path_join(DEFAULT_BG_NAME)
	if not FileAccess.file_exists(bg_path):
		err("no background music")
		return
	audio_bg.stream = AudioStreamWAV.load_from_file(bg_path, {
		"edit/loop_mode": 2,
		"edit/loop_end": -1,
		"edit/loop_begin": 127286,
	})
	#audio_bg.play()
	max_segment = DirAccess.get_directories_at(PATH).size() - 1
	if max_segment < 0:
		err("no parts")
	next()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"delay_more"):
		delay += 0.1
		label.text = "sync +" + str(delay)
	if event.is_action_pressed(&"delay_less"):
		delay -= 0.1
		label.text = "sync +" + str(delay)


func _process(_delta: float) -> void:
	if not next_verse_pending: return
	
	var pos = audio_bg.get_playback_position()
	var current_modulo = fmod(pos+0.68+delay, TIME_VERSE)
	if pos > audio_bg.stream.get_length() - 1.0 and not just_looped:
		just_looped = true
	if current_modulo < last_modulo:
		if just_looped:
			just_looped = false
		else:
			next_verse_pending = false
			next()
	last_modulo = current_modulo


func next() -> void:
	var next_path = PATH.path_join(str(current_segment))
	if not DirAccess.dir_exists_absolute(next_path):
		next_path = PATH.path_join(DEFAULT_SEGMENT_NAMES[current_segment])
	if not DirAccess.dir_exists_absolute(next_path):
		err("no next segment " + str(current_segment))
		return
	var random_segment = Array(DirAccess.get_files_at(next_path)).pick_random()
	if not random_segment:
		err("no segments")
		return
	var stream = AudioStreamMP3.load_from_file(next_path.path_join(random_segment))
	audio_fg.stream = stream
	audio_fg.play()
	label.text += humanize(random_segment) + " "
	current_segment += 1
	if current_segment > max_segment:
		current_segment = 0
		next_verse_pending = true
		await get_tree().create_timer(1.5).timeout
		label.text = ""
	else:
		timer.start(stream.get_length() - TIME_WORD_MARGIN)


func humanize(msg: String) -> String:
	return msg.replace(".wav", "").replace(".mp3", "").to_upper()


func err(msg: String) -> void:
	msg = "Impossible to start :[\n" + msg
	printerr(msg)
	label.text = msg


func _on_timer_verse_timeout() -> void:
	if not audio_bg.playing:
		audio_bg.play()
	next()
