# ==============================================================================
# Item.gd  —— 单机版 / 多语言 / 零代码新增消耗品
# ==============================================================================
@tool
class_name Item
extends Resource

enum Kind { KEY, WEAPON, QUEST, CONSUMABLE }

# ------------- 基础 -------------
@export var kind: Kind = Kind.KEY
@export var name_tr_key: String = ""        # 翻译键
@export var desc_tr_key: String = ""
@export var icon: Texture2D
@export var mesh: Mesh
@export var tint: Color = Color.WHITE

# ------------- 钥匙 -------------
@export var key_id: int = -1

# ------------- 消耗品 -------------
@export var consumable_effect: ConsumableEffect

# ------------- 编辑器预览 -------------
func _get_preview_text() -> String:
	var txt := Tr.items(name_tr_key)
	return "%s  #%d" % [txt, key_id] if kind == Kind.KEY else txt
