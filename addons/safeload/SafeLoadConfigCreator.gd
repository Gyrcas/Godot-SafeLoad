@tool
extends Control
class_name SafeLoadConfigCreator
## Scene script of the SafeLoadConfig creator.

@export var classes_hidden_by_search_label: Label = null

@export var allowed_classes_grid: GridContainer = null

@export var disallowed_classes_grid: GridContainer = null

@export var class_search_bar: LineEdit = null

@export var clear_search_button: Button = null

@export var save_config_button: Button = null

var config_uid: String = ""

var has_unsaved_changes: bool = false

signal config_created(config: SafeLoadConfig)

signal exited_with_unsaved_config(config: SafeLoadConfig, uid: String)

signal saved_unrecognized_uid(config: SafeLoadConfig)

func _ready() -> void:
	save_config_button.pressed.connect(on_save_config_pressed)
	class_search_bar.text_submitted.connect(on_class_search_bar_text_submitted)
	clear_search_button.pressed.connect(on_clear_search_pressed)
	var classes: PackedStringArray = get_all_classes()
	for classname in classes:
		create_class_button(classname)

func on_clear_search_pressed() -> void:
	class_search_bar.text = ""
	show_class_buttons()

func show_class_buttons_containing_text(text: String, class_buttons: Array[Node] = get_all_class_buttons()) -> void:
	classes_hidden_by_search_label.show()
	for class_button: Button in class_buttons:
		if text in class_button.text.to_lower():
			class_button.show()
		else:
			class_button.hide()

func show_class_buttons(class_buttons: Array[Node] = get_all_class_buttons()) -> void:
	classes_hidden_by_search_label.hide()
	for class_button: Button in class_buttons:
		class_button.show()

func on_class_search_bar_text_submitted(new_text: String) -> void:
	var class_buttons: Array[Node] = get_all_class_buttons()
	if new_text:
		show_class_buttons_containing_text(new_text.to_lower(), class_buttons)
	else:
		show_class_buttons(class_buttons)

func get_all_classes() -> PackedStringArray:
	var classes: PackedStringArray = ClassDB.get_class_list()
	for global_class in ProjectSettings.get_global_class_list():
		classes.append(global_class["class"])
	return classes

func create_class_button(classname: String) -> void:
	var class_button: Button = Button.new()
	class_button.text = classname
	class_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	class_button.pressed.connect(on_class_button_pressed.bind(class_button))
	disallowed_classes_grid.add_child(class_button)

func on_class_button_pressed(class_button: Button) -> void:
	has_unsaved_changes = true
	match class_button.get_parent():
		allowed_classes_grid:
			class_button.reparent(disallowed_classes_grid)
		disallowed_classes_grid:
			class_button.reparent(allowed_classes_grid)
		_:
			assert(false, "Invalid parent for class button! Parent is neither allowed or disallowed grid!")

func get_all_class_buttons() -> Array[Node]:
	return allowed_classes_grid.get_children() + disallowed_classes_grid.get_children()

func load_config(config: SafeLoadConfig) -> void:
	if has_unsaved_changes:
		has_unsaved_changes = false
		emit_exited_with_unsaved_config()
	class_search_bar.text = ""
	config_uid = ResourceUID.path_to_uid(config.resource_path)
	for class_button: Button in get_all_class_buttons():
		class_button.show()
		if class_button.text in config.allowed_nodes_and_subresources:
			class_button.reparent(allowed_classes_grid)
		else:
			class_button.reparent(disallowed_classes_grid)

func create_config() -> SafeLoadConfig:
	has_unsaved_changes = false
	var config: SafeLoadConfig = SafeLoadConfig.new()
	for class_button: Button in allowed_classes_grid.get_children():
		config.allowed_nodes_and_subresources.append(class_button.text)
	return config

func on_save_config_pressed() -> void:
	var path: String = ResourceUID.uid_to_path(config_uid)
	var config: SafeLoadConfig = create_config()
	if not path:
		saved_unrecognized_uid.emit(config)
		return
	ResourceSaver.save(config, path)
	config_created.emit(config)

func emit_exited_with_unsaved_config() -> void:
	exited_with_unsaved_config.emit(create_config(), config_uid)

func _exit_tree() -> void:
	if has_unsaved_changes:
		emit_exited_with_unsaved_config()
