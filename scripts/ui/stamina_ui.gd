# ==============================================================================
# stamina_ui.gd
# 玩家UI控制器 - 扩展功能版
# 负责管理和显示玩家的体力状态、物品名称、状态文本和字幕
# ==============================================================================

# 扩展自Control类，表示这是一个UI控制节点
extends Control

# ========== 节点引用 ==========
# @onready确保在节点准备好后再获取这些引用
@onready var 体力进度条: ProgressBar = $HBoxContainer/ProgressBar  # 体力进度条节点
@onready var 体力图标: TextureRect = $HBoxContainer/TextureRect  # 体力图标节点
@onready var 物品名称标签: Label = $物品名称标签  # 物品名称显示标签
@onready var 状态文本标签: Label = $状态文本标签  # 状态文本显示标签
@onready var 字幕文本区域: Label = $字幕文本区域  # 字幕文本显示区域

# ========== 变量定义 ==========
var 体力是否满: bool = true  # 体力是否满值的状态标志
var 当前物品名称: String = "空手"  # 当前持有的物品名称
var 当前状态文本: String = ""  # 当前状态文本
var 当前字幕文本: String = ""  # 当前字幕文本

# ========== 拥有者玩家系统 ==========

# 拥有此UI的玩家节点
var owner_player: Node = null

# 设置拥有者玩家
# @param player: 玩家节点
func set_owner_player(player: Node) -> void:
	owner_player = player

# 获取拥有者玩家
# @return: 玩家节点
func get_owner_player() -> Node:
	return owner_player

# ========== 分组消失控制变量 ==========
var 体力值计时器: float = 0.0  # 体力值不动的时间计时器
var 物品栏计时器: float = 0.0  # 物品栏不动的时间计时器
var 体力值消失时间: float = 3.0  # 体力值长时间不动后消失的时间（秒）
var 物品栏消失时间: float = 5.0  # 物品栏长时间不动后消失的时间（秒）
var 体力值需要消失: bool = false  # 体力值是否需要消失
var 物品栏需要消失: bool = false  # 物品栏是否需要消失
var 体力值最后活动时间: float = 0.0  # 体力值最后活动的时间
var 物品栏最后活动时间: float = 0.0  # 物品栏最后活动的时间

# ========== 初始化方法 ==========
func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	if Global and not Global.ui:
		Global.ui = self
	
	self.visible = true
	
	更新物品名称显示(当前物品名称)
	更新状态文本显示(当前状态文本)
	更新字幕文本显示(当前字幕文本)
	
	体力值最后活动时间 = Time.get_ticks_msec() / 1000.0
	物品栏最后活动时间 = Time.get_ticks_msec() / 1000.0

# ========== 核心功能方法 ==========

# 每帧更新计时器
func _process(_delta: float):
	# 更新当前时间
	var 当前时间 = Time.get_ticks_msec() / 1000.0
	
	# 检查体力值是否需要消失
	if 当前时间 - 体力值最后活动时间 >= 体力值消失时间:
		if not 体力值需要消失:
			体力值需要消失 = true
			_更新体力值显示状态()
	
	# 检查物品栏是否需要消失
	if 当前时间 - 物品栏最后活动时间 >= 物品栏消失时间:
		if not 物品栏需要消失:
			物品栏需要消失 = true
			_更新物品栏显示状态()

# 更新体力显示的方法
# @param 当前值: 当前体力值
# @param 最大值: 最大体力值
func 更新体力显示(当前值: float, 最大值: float):
	体力值最后活动时间 = Time.get_ticks_msec() / 1000.0
	体力值需要消失 = false
	_更新体力值显示状态()
	
	var 百分比 = (当前值 / 最大值) * 100
	var 新的满状态 = 百分比 >= 100
	
	if 新的满状态 != 体力是否满:
		体力是否满 = 新的满状态
		if 体力是否满:
			if 体力值需要消失:
				_隐藏体力值部分()
		else:
			_显示体力值部分()
	
	var 目标颜色: Color
	if 当前值 <= 30:
		目标颜色 = Color.RED
	elif 当前值 <= 60:
		目标颜色 = Color.ORANGE
	else:
		目标颜色 = Color.GREEN.lerp(Color.YELLOW_GREEN, 当前值 / 最大值)
	
	var 显示百分比 = round(百分比)
	
	体力进度条.value = 显示百分比
	体力进度条.modulate = 目标颜色

# 更新物品名称显示
# @param 物品名称: 要显示的物品名称
func 更新物品名称显示(物品名称: String):
	当前物品名称 = 物品名称
	物品名称标签.text = 物品名称
	
	# 重置物品栏活动计时器
	物品栏最后活动时间 = Time.get_ticks_msec() / 1000.0
	物品栏需要消失 = false
	_更新物品栏显示状态()

# 更新状态文本显示
# @param 状态文本: 要显示的状态文本（门状态、剩余水量等）
func 更新状态文本显示(状态文本: String):
	当前状态文本 = 状态文本
	状态文本标签.text = 状态文本
	
	# 如果状态文本为空，隐藏标签；否则显示
	状态文本标签.visible = !状态文本.is_empty()

# 更新字幕文本显示
# @param 字幕文本: 要显示的字幕文本
func 更新字幕文本显示(字幕文本: String):
	当前字幕文本 = 字幕文本
	字幕文本区域.text = 字幕文本
	
	# 如果字幕文本为空，隐藏区域；否则显示
	字幕文本区域.visible = !字幕文本.is_empty()

# 显示门状态文本
# @param 门名称: 门的名称
# @param 门状态: 门的状态（"门上锁"、"需要斧头"等）
func 显示门状态(_门名称: String, 门状态: String):
	var 状态文本 = ""
	
	# 根据门状态决定显示内容
	match 门状态:
		"", "已解锁", "可以打开", "E 推开":
			# 门可以打开时，什么都不显示
			状态文本 = ""
		"门上锁", "已上锁", "上锁", "需要钥匙":
			# 门上锁时，显示"门上锁"
			状态文本 = "门上锁"
		"需要斧头", "被木板封", "门已封住", "左键 劈砍":
			# 门被木板封时，显示"需要斧头"
			状态文本 = "需要斧头"
		_:
			# 其他状态，显示原始状态
			状态文本 = 门状态
	
	更新状态文本显示(状态文本)

# 显示剩余水量
# @param 当前水量: 当前剩余水量
# @param 最大水量: 最大水量
func 显示剩余水量(当前水量: float, 最大水量: float):
	var 状态文本 = "剩余水量: " + str(当前水量) + "/" + str(最大水量)
	更新状态文本显示(状态文本)

# 清除状态文本
func 清除状态文本():
	更新状态文本显示("")

# 清除字幕文本
func 清除字幕文本():
	更新字幕文本显示("")

# ========== 分组显示控制方法 ==========

# 更新体力值显示状态
func _更新体力值显示状态():
	if 体力值需要消失 and 体力是否满:
		_隐藏体力值部分()
	else:
		_显示体力值部分()

# 更新物品栏显示状态
func _更新物品栏显示状态():
	if 物品栏需要消失:
		_隐藏物品栏部分()
	else:
		_显示物品栏部分()

# 隐藏体力值部分（进度条和图标）
func _隐藏体力值部分():
	if 体力进度条:
		体力进度条.visible = false
	if 体力图标:
		体力图标.visible = false

# 显示体力值部分（进度条和图标）
func _显示体力值部分():
	if 体力进度条:
		体力进度条.visible = true
	if 体力图标:
		体力图标.visible = true

# 隐藏物品栏部分（物品名称标签和快捷栏）
func _隐藏物品栏部分():
	if 物品名称标签:
		物品名称标签.visible = false
	# 隐藏快捷栏
	var hotbar_ui = get_node_or_null("HotbarUI")
	if hotbar_ui:
		hotbar_ui.visible = false

# 显示物品栏部分（物品名称标签和快捷栏）
func _显示物品栏部分():
	if 物品名称标签:
		物品名称标签.visible = true
	# 显示快捷栏
	var hotbar_ui = get_node_or_null("HotbarUI")
	if hotbar_ui:
		hotbar_ui.visible = true
		# 强制刷新快捷栏内容
		if hotbar_ui.has_method("_refresh_hotbar"):
			hotbar_ui._refresh_hotbar()

# ========== UI显示控制方法（保持兼容性） ==========

# 当体力满时开始淡出UI（兼容旧版本）
func 开始淡出():
	# 立即设置节点为不可见
	self.visible = false

# 当体力不满时取消淡出，显示UI（兼容旧版本）
func 取消淡出():
	# 立即恢复UI可见性
	self.visible = true

# 显示整个UI（兼容旧版本）
func 显示UI():
	self.visible = true

# 隐藏整个UI（兼容旧版本）
func 隐藏UI():
	self.visible = false

# ========== 兼容性方法（保持向后兼容） ==========

# 兼容旧版本的update_stamina方法
func update_stamina(value: float, max_value: float):
	更新体力显示(value, max_value)

# ========== 工作原理说明 ==========
# 1. 当玩家体力变化时，外部代码调用更新体力显示方法
# 2. 计算体力百分比并处理满体力状态的显示逻辑
# 3. 根据体力值动态改变进度条颜色（绿色→橙色→红色）
# 4. 使用Tween实现平滑的数值和颜色过渡动画
# 5. 支持物品名称、状态文本和字幕文本的显示功能
# 6. 当体力满时自动隐藏UI，保持界面整洁
