extends SceneTree
## The sound (GDD §15, TECH §8): every sample is 22 kHz mono and every ambience loops whole; the
## buses keep the suit's sounds clear of the vacuum low-pass; and out of the air, the Sound
## autoload muffles the world and turns the place's ambience down, then brings both back; in a
## jump's tunnel, its roar comes up in place of the hum.
##   tools/godot.sh --headless -s tests/test_audio.gd

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var paths := _files("res://assets/audio", ".wav")
	_check(not paths.is_empty(), "no sounds in assets/audio")
	for path in paths:
		var stream := load(path) as AudioStreamWAV
		_check(stream != null, "%s doesn't load" % path)
		if stream == null:
			continue
		_check(stream.mix_rate == 22050 and not stream.stereo, "%s isn't 22,050 Hz mono" % path)
	print("Checked %d sounds." % paths.size())

	var sound: Node = root.get_node("Sound")
	for stream: AudioStreamWAV in sound.AMBIENCE.values():
		var whole := roundi(stream.get_length() * stream.mix_rate)
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_begin == 0 and stream.loop_end == whole,
				"%s doesn't loop over its whole length" % stream.resource_path)

	var world := AudioServer.get_bus_index(&"World")
	var filter := AudioServer.get_bus_effect(world, 0) as AudioEffectLowPassFilter if world > 0 else null
	_check(filter != null, "the World bus has no vacuum low-pass")
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Ambient")) == &"World", "the ambience isn't heard through the air")
	_check(AudioServer.get_bus_send(AudioServer.get_bus_index(&"Suit")) == &"Master", "the suit's sounds go through the vacuum low-pass")

	if filter != null:
		for i in 60:
			sound._listen(1.0 / 30.0, &"lantern", true)
		_check(filter.cutoff_hz < 1000.0, "vacuum doesn't muffle the world (%d Hz)" % filter.cutoff_hz)
		_check(absf(sound._ambience[&"lantern"].volume_db - sound.AMBIENT_DB[&"lantern"] - sound.VACUUM_DB) < 1.0, "the hum isn't turned down in vacuum")
		_check(sound._ambience[&"derelict"].volume_db < -60.0, "the derelict's drone plays aboard")
		for i in 60:
			sound._listen(1.0 / 30.0, &"derelict", false)
		_check(filter.cutoff_hz > 15000.0, "the world stays muffled back in the air (%d Hz)" % filter.cutoff_hz)
		_check(absf(sound._ambience[&"derelict"].volume_db - sound.AMBIENT_DB[&"derelict"]) < 1.0, "the derelict's drone doesn't come up in a derelict")
		_check(sound._ambience[&"lantern"].volume_db < -60.0, "the hum carries on in a derelict")
		for i in 60:
			sound._listen(1.0 / 30.0, &"tunnel", false)
		_check(absf(sound._ambience[&"tunnel"].volume_db - sound.AMBIENT_DB[&"tunnel"]) < 1.0, "the tunnel's roar doesn't come up in a jump")
		_check(sound._ambience[&"derelict"].volume_db < -60.0 and sound._ambience[&"lantern"].volume_db < -60.0, "the drone or the hum carries on in the tunnel")

	print("test_audio: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)


func _files(folder: String, extension: String) -> Array[String]:
	var out: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(extension):
			out.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		out.append_array(_files(folder.path_join(sub), extension))
	return out


func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: ", message)
