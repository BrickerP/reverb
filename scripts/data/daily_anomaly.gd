class_name DailyAnomaly
extends RefCounted

const ECHO_SURGE := &"echo_surge"
const RIFTFALL := &"riftfall"
const TWIN_HUNT := &"twin_hunt"
const FORTUNE := &"fortune"
const RIFTSTORM := &"riftstorm"
const ALL: Array[StringName] = [ECHO_SURGE, RIFTFALL, TWIN_HUNT, FORTUNE, RIFTSTORM]

const ECHO_BONUS := 0.15
const RIFT_WAVE := 8
const RIFT_INTERVAL := 14.0
const FORTUNE_DROP_MULT := 1.5
const RIFTSTORM_INTERVAL := 8.0


static func for_seed(seed_value: int) -> StringName:
	return ALL[absi(seed_value) % ALL.size()]


static func title_key(id: StringName) -> String:
	match id:
		ECHO_SURGE:
			return "daily.echo_surge"
		RIFTFALL:
			return "daily.riftfall"
		TWIN_HUNT:
			return "daily.twin_hunt"
		FORTUNE:
			return "daily.fortune"
		RIFTSTORM:
			return "daily.riftstorm"
		_:
			return "daily.echo_surge"
