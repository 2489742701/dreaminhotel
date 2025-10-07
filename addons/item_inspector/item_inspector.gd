@tool
extends EditorInspectorPlugin

func _can_handle(object):
	return object is Item

func _parse_property(object, type, name, hint_type, hint_string, usage, wide):
	match name:
		"key_id":
			return true if object.kind == Item.Kind.KEY else false
		"consumable_effect":
			return true if object.kind == Item.Kind.CONSUMABLE else false
		_:
			return true   # 其他字段正常显示
