# ==============================================================================
# button.gd
# 语言切换按钮脚本
# 扩展自Button类，负责在中文和英文之间切换游戏语言，并刷新相关UI显示
# ==============================================================================
extends Button

# ========== 变量定义 ==========
# 当前语言状态标志
var is_chinese = true
# 缓存的背包UI引用，避免重复查找节点
var inventory_gui: Node = null

# ========== 初始化方法 ==========
# 节点进入场景树时调用，初始化信号连接和引用缓存
func _ready() -> void:
	# 连接按钮点击信号到处理方法
	pressed.connect(_on_pressed)
	# 初始化按钮文本显示
	_update_button_text()
	
	# 缓存背包UI引用的优先级策略：
	# 1. 首先尝试通过组查询获取（更健壮，不依赖节点路径）
	# 2. 失败时尝试通过父节点递归查找（作为后备方案）
	inventory_gui = get_tree().get_first_node_in_group("inventory_gui")
	if not inventory_gui:
		inventory_gui = get_parent().find_child("InventoryGUI3D", true, false)

# ========== 事件处理方法 ==========
# 按钮点击事件处理
func _on_pressed() -> void:
	# 切换语言状态标志
	is_chinese = !is_chinese
	
	# 根据当前语言状态设置全局翻译服务器的语言
	# zh_CN: 简体中文
	# en: 英语
	if is_chinese:
		TranslationServer.set_locale("zh_CN")
	else:
		TranslationServer.set_locale("en")
	
	# 更新按钮自身的显示文本，反映下一次点击将切换的语言
	_update_button_text()
	
	# 刷新背包界面，确保所有物品名称也随之更新语言
	# 优化策略：优先使用缓存的引用
	if inventory_gui and is_instance_valid(inventory_gui) and inventory_gui.has_method("refresh"):
		inventory_gui.refresh()
	else:
		# 容错处理：如果缓存引用无效（可能场景结构已更改），尝试重新查找
		# 并更新缓存，确保功能正常
		inventory_gui = get_tree().get_first_node_in_group("inventory_gui")
		if not inventory_gui:
			inventory_gui = get_parent().find_child("InventoryGUI3D", true, false)
		
		# 再次检查引用有效性，防止空指针错误
		if inventory_gui and is_instance_valid(inventory_gui) and inventory_gui.has_method("refresh"):
			inventory_gui.refresh()

# ========== 辅助方法 ==========
# 更新按钮显示文本
# 按钮文本显示的是下一次点击将切换到的语言，而不是当前语言
func _update_button_text() -> void:
	if is_chinese:
		self.text = "English"  # 当前是中文，显示"English"表示点击后切换到英文
	else:
		self.text = "中文"      # 当前是英文，显示"中文"表示点击后切换到中文
