extends Control
# 体力条UI控制器
# 功能：
# - 显示体力百分比
# - 颜色动态变化（绿->橙->红）
# - 平滑过渡动画

@onready var progress_bar: ProgressBar = $HBoxContainer/ProgressBar
@onready var stamina_icon: TextureRect = $HBoxContainer/TextureRect

var tween: Tween  # 用于实现动画效果
var is_full: bool = true  # 新增状态标志

func _ready():
	# 忽略所有鼠标事件
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	
	
 
 
func update_stamina(value: float, max_value: float):
	"""
	更新体力显示
	参数：
	- value: 当前体力值
	- max_value: 最大体力值
	特性：
	- 自动计算百分比
	- 颜色根据剩余比例渐变
	- 带有平滑过渡动画
	"""
	
	
	var percentage = (value / max_value) * 100  # 计算百分比
	
		# 判断是否处于满体力状态（考虑浮点误差）
	var new_is_full = percentage >= 100
	
		# 状态变化处理
	if new_is_full != is_full:
		is_full = new_is_full
		if is_full:
			start_fade_out()
		else:
			cancel_fade()
			
		
	# 停止之前的动画防止冲突
	if tween:
		tween.kill()
	
		# 颜色渐变逻辑
	var target_color: Color
	if value <= 30:
		target_color = Color.RED  # 完全耗尽时红色
	elif value <= 60:
		target_color = Color.ORANGE  # 低体力警告色
	else:
		# 正常状态颜色渐变（绿 -> 黄绿）
		target_color = Color.GREEN.lerp(Color.YELLOW_GREEN, value / max_value)
	
	
	# 创建并行动画
	tween = create_tween().set_parallel(true)
	tween.tween_property(progress_bar, "value", percentage, 0.3)
	tween.tween_property(progress_bar, "modulate", target_color, 0.5)
	
	
	# 数值变化动画（0.3秒完成）
	tween.tween_property(progress_bar, "value", percentage, 0.3)
	

		
	# 添加四舍五入处理
	var precise_percentage = (value / max_value) * 100
	var display_percentage = round(precise_percentage)
	progress_bar.value = display_percentage
	
	# 颜色变化动画（0.5秒完成）
	tween.tween_property(progress_bar, "modulate", target_color, 0.5)
	
# 新增淡出方法
func start_fade_out():
	# 立即设置节点为不可见
	self.visible = false



# 新增取消淡出方法
func cancel_fade():
	self.visible = true


	# 立即恢复可见
	self.visible = true
