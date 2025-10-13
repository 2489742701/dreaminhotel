# ==============================================================================
# item_preview_gui.gd - 物品预览界面控制脚本
# 负责显示选中物品的3D模型预览、名称和描述，并支持模型旋转功能
# ==============================================================================

# 扩展自Control类，表示这是一个UI控制节点
extends Control
# 定义类名为ItemPreviewGUI，方便在其他脚本中引用
class_name ItemPreviewGUI

# ========== UI组件引用 ==========
# @onready装饰器确保节点在_ready()方法调用前完成初始化

# 3D视口，用于渲染3D模型
@onready var sub_viewport := $SubViewportContainer/SubViewport as SubViewport

# 3D相机，用于观察预览模型
@onready var camera := $SubViewportContainer/SubViewport/Camera3D as Camera3D

# 预览根节点，所有3D模型都将添加到这个节点下
@onready var preview_root := $SubViewportContainer/SubViewport/PreviewRoot as Node3D

# 物品名称标签
@onready var item_name_label := $VBoxContainer/ItemNameLabel as Label

# 物品描述标签
@onready var item_description_label := $VBoxContainer/ItemDescriptionLabel as Label

# 视口容器，用于检测鼠标交互区域
@onready var sub_viewport_container := $SubViewportContainer as SubViewportContainer

# ========== 核心变量 ==========

# 当前显示的物品
var current_item: Item = null

# 当前物品在背包中的索引
var current_item_index: int = -1

# 拖拽开始位置，用于模型旋转
var drag_start: Vector2 = Vector2()

# 模型绕X轴旋转角度
var rot_x: float = 0.0

# 模型绕Y轴旋转角度
var rot_y: float = 0.0

# ========== 生命周期函数 ==========

# 节点准备就绪时调用
func _ready():
	pass
# ========== 公共函数 ==========

# 设置要显示的物品
# @param it: 要显示的物品对象
# @param item_index: 物品在背包中的索引
# @param _is_equipped: 物品是否已装备（当前版本未使用）
func set_item(it: Item, item_index: int = -1, _is_equipped: bool = false):
	# 清除之前显示的模型
	# 遍历preview_root的所有子节点并释放它们
	for c in preview_root.get_children():
		c.queue_free()
	
	# 更新当前物品和索引
	current_item = it
	current_item_index = item_index
	
	# 安全检查：确保标签节点存在
	if not is_instance_valid(item_name_label) or not is_instance_valid(item_description_label):
		return
	
	# 如果没有物品，清空显示内容
	if it == null:
		item_name_label.text = ""
		item_description_label.text = ""
		return
	
	# 更新物品名称和描述文本，使用翻译系统
	# 获取翻译后的物品名称
	var translated_name = "未知物品"
	if it.name_tr_key:
		if Engine.has_singleton("Tr"):
			translated_name = Engine.get_singleton("Tr").items(it.name_tr_key)
		else:
			translated_name = it.name_tr_key
	item_name_label.text = translated_name
	# 应用物品名称颜色
	item_name_label.add_theme_color_override("font_color", it.name_color)
	# 获取翻译后的物品描述
	var translated_desc = "暂无介绍"
	if it.desc_tr_key:
		if Engine.has_singleton("Tr"):
			translated_desc = Engine.get_singleton("Tr").items(it.desc_tr_key)
		else:
			translated_desc = it.desc_tr_key
	item_description_label.text = translated_desc
	
	# 安全检查：确保物品有3D模型
	if not it.mesh:
		print("警告: 物品 ", it.name_tr_key, " 没有关联的3D模型")
		return
	
	# 创建3D模型实例
	var mesh_instance = MeshInstance3D.new()
	# 设置模型资源
	mesh_instance.mesh = it.mesh
	
	# 将模型添加到预览场景
	preview_root.add_child(mesh_instance)
	# 重置旋转角度
	rot_x = 0.0
	rot_y = 0.0
	# 应用初始旋转
	_apply_rotation()

# ========== 按钮事件处理 ==========

# 引导按钮按下事件处理函数
func _on_guide_button_pressed():
	# 发出信号，通知父节点处理引导操作
	# 信号携带当前物品索引信息
	emit_signal("guide_button_pressed", current_item_index)

# ========== 辅助方法 ==========

# 检查鼠标是否在预览区域内
# @param pos: 要检查的位置
# @return: 如果在区域内返回true，否则返回false
func is_mouse_in_preview_area(pos: Vector2) -> bool:
	# 安全检查：确保视口容器有效
	if not is_instance_valid(sub_viewport_container):
		return false
	# 获取视口容器的矩形区域
	var rect = sub_viewport_container.get_rect()
	# 检查点是否在矩形内
	return rect.has_point(pos)

# ========== 输入处理 ==========

# 处理输入事件（如鼠标拖拽）
func _input(event):
	# 安全检查：确保有物品且视口容器有效
	if not current_item or not is_instance_valid(sub_viewport_container):
		return
	
	# 只在鼠标位于预览区域内时处理拖拽旋转
	if is_mouse_in_preview_area(get_local_mouse_position()):
		# 处理鼠标按下/松开事件
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# 记录拖拽开始位置
				drag_start = event.position
			else:
				# 拖拽结束，重置开始位置
				drag_start = Vector2()
		
		# 处理鼠标移动事件（拖拽旋转）
		if event is InputEventMouseMotion and drag_start != Vector2():
			# 旋转灵敏度系数
			var rotation_sensitivity = 0.04
			# 计算水平旋转（绕Y轴）
			rot_y += event.relative.x * rotation_sensitivity
			# 计算垂直旋转（绕X轴），使用负数反转方向
			rot_x -= event.relative.y * rotation_sensitivity
			# 应用旋转
			_apply_rotation()

# ========== 旋转应用 ==========

# 应用计算好的旋转到预览模型
func _apply_rotation():
	# 创建新的变换矩阵
	# 先绕X轴旋转rot_x角度，再绕Y轴旋转rot_y角度
	preview_root.transform = Transform3D().rotated(Vector3.RIGHT, rot_x).rotated(Vector3.UP, rot_y)
