# ==============================================================================
# Item.gd - 游戏物品数据定义类
# 这是一个纯数据类，用于定义游戏中的所有物品属性，不包含物品逻辑
# 适用于初学者：理解物品的基础数据结构是游戏开发的重要部分
# ==============================================================================

# @tool 注解表示此脚本可以在编辑器中运行，方便在编辑时预览
@tool
# 定义类名为Item，使其他脚本可以直接引用此类
class_name Item
# 扩展Resource类，表示这是一个资源类型，可在编辑器中作为资源文件保存
extends Resource

# 物品类型枚举 - 定义游戏中所有可能的物品类型
# KEY: 钥匙类物品，用于解锁
# WEAPON: 武器类物品，用于攻击
# QUEST: 任务类物品，用于完成任务
# CONSUMABLE: 消耗品类物品，使用后会产生效果并可能消失
enum Kind { KEY, WEAPON, QUEST, CONSUMABLE }

# ========== 基础属性 ==========

# 物品类型 - 决定物品的基本行为和用途
# 默认设置为钥匙类型
@export var kind: Kind = Kind.KEY

# 物品名称翻译键 - 用于从翻译系统获取本地化名称
# 例如: 如果设置为"item_key_1"，游戏会从翻译表中查找对应文本
@export var name_tr_key: String = ""        # 翻译键

# 物品描述翻译键 - 用于从翻译系统获取本地化描述
@export var desc_tr_key: String = ""

# 背包中显示的物品图标
@export var icon: Texture2D                 # 背包图标

# 3D世界中显示的物品模型
@export var mesh: Mesh                      # 3D 拾取模型

# 物品名称显示的颜色
# 默认使用白色(Color.WHITE)
@export var name_color: Color = Color.WHITE  # 物品名字颜色

# ========== 特定类型物品属性 ==========

# 钥匙专用属性 - 钥匙的唯一标识符
# 用于匹配门或其他需要钥匙的对象
# -1表示无效/未设置的钥匙ID
@export var key_id: int = -1

# 消耗品专用属性 - 使用物品时产生的效果
# 引用ConsumableEffect类型的资源，定义物品使用后的具体效果（如体力恢复）
# 具体效果通过继承ConsumableEffect基类并实现apply方法来创建
# 开发者可以在编辑器中直接拖放EffectRestoreStamina等具体效果资源到这里
@export var consumable_effect: ConsumableEffect

# ========== 编辑器辅助方法 ==========

# 编辑器预览文本方法 - 在资源面板中显示物品的友好名称
# 这是Godot引擎的特殊方法，用于在编辑器中提供更好的物品预览
func _get_preview_text() -> String:
	# 尝试获取翻译，如果游戏中有Tr单例则使用翻译后的名称
	var tr_name = ""
	if Engine.has_singleton("Tr"):
		tr_name = Engine.get_singleton("Tr").items(name_tr_key)
	else:
		# 如果没有翻译系统，就使用原始的翻译键作为名称
		tr_name = name_tr_key
	# 对于钥匙类物品，额外显示钥匙ID
	# 对于其他类型物品，只显示名称
	return "%s  #%d" % [tr_name, key_id] if kind == Kind.KEY else tr_name
