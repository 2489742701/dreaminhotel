# ==============================================================================
# stamina_ui.gd
# 体力条UI控制器
# 扩展自Control类，负责管理和显示玩家的体力状态
# 适用于初学者：了解如何实现游戏中的UI元素，包括进度条、动画和状态管理
# ==============================================================================

# 扩展自Control类，表示这是一个UI控制节点
extends Control

# ========== 节点引用 ==========
# @onready确保在节点准备好后再获取这些引用
@onready var progress_bar: ProgressBar = $HBoxContainer/ProgressBar  # 体力进度条节点
@onready var stamina_icon: TextureRect = $HBoxContainer/TextureRect  # 体力图标节点

# ========== 变量定义 ==========
var tween: Tween  # 用于实现平滑动画效果的补间对象
var is_full: bool = true  # 体力是否满值的状态标志

# ========== 初始化方法 ==========
func _ready():
	# 设置鼠标过滤模式为忽略，防止UI节点拦截鼠标事件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 初始设置为不可见（满体力时不显示体力条）
	self.visible = false

# ========== 核心功能方法 ==========
# 更新体力显示的方法
# @param value: 当前体力值
# @param max_value: 最大体力值
# 初学者提示：这个方法是外部调用的主要入口，用于更新UI显示
func update_stamina(value: float, max_value: float):
	# 计算体力百分比
	var percentage = (value / max_value) * 100
	
	# 判断是否处于满体力状态（考虑浮点误差）
	var new_is_full = percentage >= 100
	
	# 状态变化处理
	if new_is_full != is_full:
		is_full = new_is_full
		if is_full:
			start_fade_out()  # 体力满时隐藏UI
		else:
			cancel_fade()     # 体力不满时显示UI
	
	# 停止之前的动画防止冲突
	if tween:
		tween.kill()
	
	# 颜色渐变逻辑 - 根据剩余体力百分比改变颜色
	var target_color: Color
	if value <= 30:
		target_color = Color.RED  # 体力低于30%时显示红色（警告状态）
	elif value <= 60:
		target_color = Color.ORANGE  # 体力在30%-60%之间时显示橙色（注意状态）
	else:
		# 正常状态颜色渐变（绿 -> 黄绿）
		target_color = Color.GREEN.lerp(Color.YELLOW_GREEN, value / max_value)
	
	# 创建并行动画
	tween = create_tween().set_parallel(true)
	
	# 四舍五入处理，显示整数百分比
	var display_percentage = round(percentage)
	
	# 数值变化动画（0.3秒完成平滑过渡）
	tween.tween_property(progress_bar, "value", display_percentage, 0.3)
	
	# 颜色变化动画（0.5秒完成平滑过渡）
	tween.tween_property(progress_bar, "modulate", target_color, 0.5)

# ========== UI显示控制方法 ==========
# 当体力满时开始淡出UI
# 初学者提示：这个方法实现了UI的自动隐藏功能
func start_fade_out():
	# 立即设置节点为不可见
	# 注意：这里可以扩展为使用动画渐变淡出
	self.visible = false

# 当体力不满时取消淡出，显示UI
# 初学者提示：这个方法确保在需要时UI能立即显示
func cancel_fade():
	# 立即恢复UI可见性
	self.visible = true

# ========== 工作原理说明 ==========
# 1. 当玩家体力变化时，外部代码调用update_stamina方法
# 2. 计算体力百分比并处理满体力状态的显示逻辑
# 3. 根据体力值动态改变进度条颜色（绿色→橙色→红色）
# 4. 使用Tween实现平滑的数值和颜色过渡动画
# 5. 当体力满时自动隐藏UI，保持界面整洁
