# ==============================================================================
# Item.gd - 游戏物品数据定义类
# ==============================================================================
@tool
class_name Item
extends Resource

# 物品类型枚举（恐怖游戏专用）
enum Kind { 
	KEY,        # 钥匙类物品
	WEAPON,     # 武器类物品（暂时未使用）
	CONSUMABLE, # 消耗品类物品
	TOOL,       # 工具类物品
	FLASHLIGHT, # 手电筒类物品
	SEAL_ITEM   # 封门物品类（用于封门的木板等）
}

# ========== 基础属性 ==========

# 关键点1：在 setter 中保留 notify_property_list_changed()
# 当你在编辑器改变类型时，必须通知引擎刷新属性列表，否则隐藏/显示不会立刻更新
@export var 物品类型: Kind = Kind.KEY:
	set(value):
		物品类型 = value
		notify_property_list_changed()

@export var 名称翻译键: String = ""
@export var 描述翻译键: String = ""
@export var 图标: Texture2D
@export var 模型: Mesh
@export var 名称颜色: Color = Color.WHITE

# 默认图标颜色 - 当物品没有图标时，使用此颜色生成默认图标
# 如果未设置，将根据物品类型自动选择颜色
@export var 图标颜色: Color = Color.TRANSPARENT  # 透明表示使用默认颜色

# ========== 特定类型物品属性 (全部保留 @export) ==========

# 注意：我们依然使用 @export，但是通过下方的 _validate_property 来控制它们是否显示
@export var 钥匙ID: int = -1

# 消耗品专用属性
@export var 消耗品效果: Resource # 建议使用 Resource 或你具体的 ConsumableEffect 类
@export var 可饮用次数: int = 1
@export var 最大饮用次数: int = 1  # 用于UI显示进度（如3/3）

# 手持动画属性（武器和消耗品专用）
@export var 手持动画: Resource # 使用 HandAnimation 资源类

# 武器攻击效果属性（武器专用）
@export var 武器攻击效果: Resource # 使用 WeaponAttackEffect 资源类

# 手电筒专用属性
@export var 电池容量: float = 100.0  # 电池最大容量
@export var 当前电量: float = 100.0  # 当前电量（0-100）
@export var 亮度: float = 1.0  # 光照强度
@export var 范围: float = 10.0  # 照射范围
@export var 射程: float = 15.0  # 最大射程
@export var 电量消耗率: float = 1.0  # 每秒电量消耗量

# ========== 核心逻辑：Godot 4.x 专用条件隐藏 ==========

# 引擎在显示每一个 @export 属性之前，都会调用这个方法
# 我们在这里修改 property 的 usage 标志位来隐藏它
func _validate_property(property: Dictionary):
	# 如果当前类型 不是 KEY，就隐藏 钥匙ID
	if property.name == "钥匙ID" and 物品类型 != Kind.KEY:
		property.usage = PROPERTY_USAGE_NO_EDITOR

	# 如果当前类型 不是 CONSUMABLE，就隐藏 消耗品效果、可饮用次数 和 最大饮用次数
	if (property.name == "消耗品效果" or property.name == "可饮用次数" or property.name == "最大饮用次数") and 物品类型 != Kind.CONSUMABLE:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	
	# 如果当前类型 不是 WEAPON、CONSUMABLE、TOOL 或 SEAL_ITEM，就隐藏 手持动画
	if property.name == "手持动画" and 物品类型 != Kind.WEAPON and 物品类型 != Kind.CONSUMABLE and 物品类型 != Kind.TOOL and 物品类型 != Kind.FLASHLIGHT and 物品类型 != Kind.SEAL_ITEM:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	
	# 如果当前类型 不是 WEAPON 或 TOOL，就隐藏 武器攻击效果
	# 武器类型：纯武器攻击效果
	# 工具类型：斧头等工具也有攻击效果（破门等）
	if property.name == "武器攻击效果" and 物品类型 != Kind.WEAPON and 物品类型 != Kind.TOOL:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	
	# 如果当前类型 不是 FLASHLIGHT，就隐藏手电筒专用属性
	if 物品类型 != Kind.FLASHLIGHT:
		var flashlight_props = ["电池容量", "当前电量", "亮度", "范围", "射程", "电量消耗率"]
		if property.name in flashlight_props:
			property.usage = PROPERTY_USAGE_NO_EDITOR

# ========== 编辑器辅助方法 (保留) ==========

func _get_preview_text() -> String:
	var tr_name = 名称翻译键
	# 简单的翻译检查逻辑
	if Engine.has_singleton("Tr"):
		tr_name = Engine.get_singleton("Tr").items(名称翻译键)
	
	if 物品类型 == Kind.KEY:
		return "%s #%d" % [tr_name, 钥匙ID]
	elif 物品类型 == Kind.CONSUMABLE:
		return "%s (x%d)" % [tr_name, 可饮用次数]
	elif 物品类型 == Kind.TOOL:
		return "%s [工具]" % tr_name
	elif 物品类型 == Kind.FLASHLIGHT:
		return "%s [手电筒] 电量:%.0f%%" % [tr_name, 当前电量]
	elif 物品类型 == Kind.SEAL_ITEM:
		return "%s [封门物品]" % tr_name
	
	return tr_name

# ========== 图标颜色辅助方法 ==========

# 获取物品的图标颜色
# @return: 图标颜色，如果未设置则返回Color.TRANSPARENT
func get_icon_color() -> Color:
	# 如果设置了自定义图标颜色且不是透明，则使用自定义颜色
	if 图标颜色 != Color.TRANSPARENT:
		return 图标颜色
	
	# 否则返回Color.TRANSPARENT，让调用方使用默认颜色
	return Color.TRANSPARENT

# 设置物品的图标颜色
# @param color: 要设置的图标颜色
func set_icon_color(color: Color) -> void:
	图标颜色 = color
