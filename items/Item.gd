# ==============================================================================
# Item.gd  －－ 纯数据，不带逻辑
@tool
class_name Item
extends Resource

enum Kind { KEY, WEAPON, QUEST, CONSUMABLE }

# --------- 基础 ---------
@export var kind: Kind = Kind.KEY
@export var name_tr_key: String = ""        # 翻译键
@export var desc_tr_key: String = ""
@export var icon: Texture2D                 # 背包图标
@export var mesh: Mesh                      # 3D 拾取模型
@export var name_color: Color = Color.WHITE  # 物品名字颜色

# --------- 钥匙专用 ---------
@export var key_id: int = -1

# --------- 消耗品专用 ---------
@export var consumable_effect: ConsumableEffect  # 拖个资源即可

# --------- 编辑器辅助 ---------
func _get_preview_text() -> String:
	# 尝试获取翻译，如果没有Tr单例则使用原始键
	var tr_name = ""
	if Engine.has_singleton("Tr"):
		tr_name = Engine.get_singleton("Tr").items(name_tr_key)
	else:
		tr_name = name_tr_key
	return "%s  #%d" % [tr_name, key_id] if kind == Kind.KEY else tr_name
