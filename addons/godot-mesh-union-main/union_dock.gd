@tool
extends EditorPlugin

var dock:Control

func _enter_tree() -> void:
	# load dock scene and instantiate
	dock = preload("res://addons/godot-mesh-union-main/mesh_union.tscn").instantiate()
	
	# [修复点 1] 将 UndoRedo 管理器传递给子界面
	if dock.has_method("set_undo_redo"):
		dock.set_undo_redo(get_undo_redo())
	# 移除直接赋值，因为可能属性不存在或需要不同的方式设置
	
	# add loaded scene to the docks
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock)
	return

func _exit_tree() -> void:
	# remove the dock
	remove_control_from_docks(dock)
	
	# erase from memory
	dock.free()
	return
