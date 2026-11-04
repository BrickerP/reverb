class_name ExperienceHints
extends RefCounted

# Completed interactions, not animation play counts. These only control how
# prominently an existing result is introduced; they grant no run rewards.
const ALL: Array[StringName] = [
	&"buy", &"upgrade", &"replace", &"combine", &"evolve", &"first_echo",
	&"merge_skill", &"merge_repair", &"merge_power", &"retire",
	&"skill_looper", &"skill_solo", &"skill_mirror", &"skill_conductor",
	&"skill_mender", &"skill_overloader", &"combo_pin_press", &"combo_ink_arc",
	&"rescue", &"repair", &"archive",
]


static func normalize(value: Variant) -> Array[StringName]:
	var out: Array[StringName] = []
	if typeof(value) != TYPE_ARRAY or value.size() > ALL.size():
		return out
	for item: Variant in value:
		if typeof(item) not in [TYPE_STRING, TYPE_STRING_NAME]:
			continue
		var action := StringName(str(item))
		if ALL.has(action) and not out.has(action):
			out.append(action)
	return out
