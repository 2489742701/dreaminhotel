@tool
extends Resource
class_name Item

# ========== 类型枚举 ==========
enum Kind { KEY, WEAPON, QUEST, CONSUMABLE }

@export var kind: Kind = Kind.KEY
@export var name: String = ""
@export_multiline var desc: String = ""
@export var can_equip: bool = true
@export var key_id: int = -1        # 仅钥匙用；-1=无效

# ========== 纯 Mesh 资源（无世界场景） ==========
@export var mesh: Mesh :            # 拖 .res 或内置圆柱/盒子即可
	set(val):
		mesh = val
		emit_changed()              # 让 @tool 实时刷新预览

@export var tint: Color = Color.WHITE  # 染色区分钥匙编号

# ========== 编辑器预览（@tool 可见） ==========
func _get_preview_text() -> String:
	# 在资源栏显示快速信息
	return "%s  #%d" % [name, key_id] if kind == Kind.KEY else name
