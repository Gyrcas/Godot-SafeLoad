@abstract
extends Object
class_name SafeLoad

static var valid_files: PackedStringArray = get_valid_files("res://")

static var valid_classes: PackedStringArray = get_valid_classes()

const default_forbidden_classes: PackedStringArray = [
	"GDScript"
]

static func get_valid_classes() -> PackedStringArray:
	var classes: PackedStringArray = ClassDB.get_class_list()
	for forbidden_class in default_forbidden_classes:
		classes.erase(forbidden_class)
	for custom_class in ProjectSettings.get_global_class_list():
		classes.append(custom_class["class"])
	return classes

static func get_valid_files(dir: String) -> PackedStringArray:
	var new_valid_files: PackedStringArray = []
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	for file_name in files:
		if file_name.get_extension() == "remap":
			file_name = file_name.rstrip(".remap")
		new_valid_files.append(dir + file_name)
	var dirs: PackedStringArray = DirAccess.get_directories_at(dir)
	for dir_name in dirs:
		new_valid_files += get_valid_files(str(dir, dir_name, "/"))
	return new_valid_files

static func get_markers_in_data(data: String) -> Array[PackedStringArray]:
	var markers: Array[PackedStringArray] = []
	var last_marker_find: int = 0
	while true:
		var start_index: int = data.find("[", last_marker_find)
		if start_index == -1:
			break
		var end_index: int = data.find("]", start_index)
		if end_index == -1:
			break
		last_marker_find = end_index + 1
		var marker: String = data.substr(start_index + 1, end_index - start_index - 1)
		var parts: PackedStringArray = marker.split(" ", false)
		markers.append(parts)
	return markers

static func get_marker_attribute(marker: PackedStringArray, attribute_name: String) -> Variant:
	var attribute: String = ""
	for value in marker:
		if value.begins_with(attribute_name + "="):
			attribute = value
			break
	if not attribute:
		push_error("Could not find attribute in marker!")
		return null
	var split: PackedStringArray = attribute.split("=", false, 1)
	if split.size() != 2:
		push_error("Incorrect formating of marker attribute! Check for any space in the attribute definition!")
		return null
	var value: String = split[1]
	if value.begins_with('"') and value.ends_with('"'):
		return value.lstrip('"').rstrip('"').strip_edges()
	return float(value)

static func is_external_resource_marker_safe(marker: PackedStringArray, config: SafeLoadConfig = null) -> bool:
	var path: String = get_marker_attribute(marker, "path")
	if not path:
		push_error("external resource marker is not safe! Could not find resource path!")
		return false
	if not is_file_safe(path, config):
		push_error("external resource marker is not safe! The resource path is not in the valid files and is not safe!")
		return false
	return true

static func check_marker_property_class(marker: PackedStringArray, property_name: String, config: SafeLoadConfig = null, marker_name: String = "Unknown") -> bool:
	var value: String = get_marker_attribute(marker, property_name)
	if not value:
		push_error(marker_name, " marker is not safe! Could not find ", property_name, "!")
		return false
	return is_class_name_valid(
		value, config, str(marker_name, " marker is not safe! ", property_name, " class is not valid! ")
	)

static func is_sub_resource_marker_safe(marker: PackedStringArray, config: SafeLoadConfig = null) -> bool:
	return check_marker_property_class(marker, "type", config, "sub_resource")

static func is_gd_resource_marker_safe(marker: PackedStringArray, config: SafeLoadConfig = null) -> bool:
	return check_marker_property_class(marker, "script_class", config, "gd_resource")

static func is_node_marker_safe(marker: PackedStringArray, config: SafeLoadConfig = null) -> bool:
	return check_marker_property_class(marker, "type", config, "node")

static func is_marker_safe(marker: PackedStringArray, config: SafeLoadConfig = null) -> bool:
	if "ext_resource" in marker:
		if not is_external_resource_marker_safe(marker, config):
			return false
	elif "sub_resource" in marker:
		if not is_sub_resource_marker_safe(marker, config):
			return false
	elif "gd_resource" in marker:
		if not is_gd_resource_marker_safe(marker):
			return false
	elif "node" in marker:
		if not is_node_marker_safe(marker, config):
			return false
	return true

static func get_file_text(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	return file.get_as_text()

static func is_resource_safe(path: String, config: SafeLoadConfig = null) -> bool:
	var data: String = get_file_text(path)
	var markers: Array[PackedStringArray] = get_markers_in_data(data)
	for marker in markers:
		if not is_marker_safe(marker, config):
			return false
	return true

static func is_class_name_valid(name: String, config: SafeLoadConfig = null, error_prefix: String = "") -> bool:
	if config and config.allowed_nodes_and_subresources and name not in config.allowed_nodes_and_subresources:
		push_error(error_prefix, "Class not allowed by config! Class: ", name)
		return false
	elif name not in valid_classes:
		push_error(error_prefix, "Class is not a valid class! Class: ", name)
		return false
	return true

static func is_gd_file_safe(path: String, config: SafeLoadConfig = null) -> bool:
	if path not in valid_files:
		push_error("Tried to load a script outside of the project! Path: ", path)
		return false
	var data: String = get_file_text(path)
	var lines: PackedStringArray = data.split("\n")
	for line in lines:
		if not line.begins_with("class_name "):
			continue
		var split: PackedStringArray = line.split(" ", false)
		if split.size() != 2:
			push_error("Unexpected class_name split count! Line: ", line)
			return false
		return is_class_name_valid(split[1], config)
	push_error("Could not find the class_name of script! Path: ", path)
	return false

static func is_file_safe(path: String, config: SafeLoadConfig = null) -> bool:
	var extension: String = path.get_extension()
	if extension == "gd":
		return is_gd_file_safe(path, config)
	elif extension in ["tres", "tscn"]:
		return is_resource_safe(path, config)
	push_error("SafeLoad does not accept files with extension: ", extension)
	return false

static func safe_load(path: String, config: SafeLoadConfig = null) -> Resource:
	if is_file_safe(path, config):
		return load(path)
	push_error("File not safe to load!")
	return null
