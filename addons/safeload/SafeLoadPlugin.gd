@tool
extends EditorPlugin
class_name SafeLoadPlugin


func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass

var safe_load_config_creator: SafeLoadConfigCreator = null

var is_creator_shown: bool = false

signal confirmation_dialog_closed(confirmed: bool)

signal file_dialog_file_selected(path: String)

func _enter_tree() -> void:
	var packed_creator: PackedScene = load("res://addons/safeload/safeload_config_creator.tscn")
	safe_load_config_creator = packed_creator.instantiate()
	safe_load_config_creator.config_created.connect(on_safe_load_config_creator_config_created)
	safe_load_config_creator.exited_with_unsaved_config.connect(on_safe_load_config_creator_exited_with_unsaved_config)
	safe_load_config_creator.saved_unrecognized_uid.connect(on_safe_load_config_creator_saved_unrecognized_uid)
	EditorInterface.get_inspector().edited_object_changed.connect(on_inspector_edited_object_changed)

func on_safe_load_config_creator_saved_unrecognized_uid(config: SafeLoadConfig) -> void:
	push_warning("Could not find file from uid, please select a new file to save the config or discard the config")
	var path: String = await show_file_dialog(FileDialog.FILE_MODE_SAVE_FILE, ["*.res", "*.tres"])
	if not path:
		return
	ResourceSaver.save(config, path)
	safe_load_config_creator.config_uid = ResourceUID.path_to_uid(path)

func show_confirmation_popup(text: String, yes_text: String, no_text: String) -> bool:
	var popup: ConfirmationDialog = ConfirmationDialog.new()
	popup.dialog_text = text
	popup.cancel_button_text = no_text
	popup.ok_button_text = yes_text
	popup.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_PRIMARY_SCREEN
	popup.confirmed.connect(on_confirmation_dialog_confirmed)
	popup.canceled.connect(on_confirmation_dialog_canceled)
	EditorInterface.popup_dialog(popup)
	var result: bool = await confirmation_dialog_closed
	popup.queue_free()
	return result

func on_file_dialog_file_selected(path: String) -> void:
	file_dialog_file_selected.emit(path)

func on_file_dialog_canceled() -> void:
	file_dialog_file_selected.emit("")

func show_file_dialog(file_mode: FileDialog.FileMode, filters: PackedStringArray) -> String:
	var file_dialog: FileDialog = FileDialog.new()
	file_dialog.file_mode = file_mode
	file_dialog.filters = filters
	file_dialog.file_selected.connect(on_file_dialog_file_selected)
	file_dialog.canceled.connect(on_file_dialog_canceled)
	EditorInterface.popup_dialog(file_dialog)
	var path: String = await file_dialog_file_selected
	file_dialog.queue_free()
	return path

func on_safe_load_config_creator_exited_with_unsaved_config(config: SafeLoadConfig, config_uid: String) -> void:
	var result: bool = await show_confirmation_popup(
		"Your SafeLoadConfig has some unsaved changes. Do you want to save them?",
		"Yes", "No"
	)
	if not result:
		return
	var path: String = ResourceUID.uid_to_path(config_uid)
	if path:
		ResourceSaver.save(config, path)
	else:
		on_safe_load_config_creator_saved_unrecognized_uid(config)

func on_confirmation_dialog_canceled() -> void:
	confirmation_dialog_closed.emit(false)

func on_confirmation_dialog_confirmed() -> void:
	confirmation_dialog_closed.emit(true)

func on_safe_load_config_creator_config_created(config: SafeLoadConfig) -> void:
	var edited_config: SafeLoadConfig = EditorInterface.get_inspector().get_edited_object()
	edited_config.allow_unknown_external_files_if_verified = config.allow_unknown_external_files_if_verified
	edited_config.allowed_nodes_and_subresources = config.allowed_nodes_and_subresources

func show_creator(config: SafeLoadConfig) -> void:
	if not is_creator_shown:
		add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_UL, safe_load_config_creator)
		is_creator_shown = true
	safe_load_config_creator.load_config(config)

func hide_creator() -> void:
	if is_creator_shown:
		remove_control_from_docks(safe_load_config_creator)
		is_creator_shown = false

func on_inspector_edited_object_changed() -> void:
	var edited_object: Object = EditorInterface.get_inspector().get_edited_object()
	if edited_object is SafeLoadConfig:
		show_creator(edited_object)
	else:
		hide_creator()

func _exit_tree() -> void:
	hide_creator()
	safe_load_config_creator.queue_free()
