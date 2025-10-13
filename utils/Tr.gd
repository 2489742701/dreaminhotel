# ==============================================================================
# Tr.gd
# 翻译工具脚本
# 提供物品名称翻译功能，方便游戏实现多语言支持
# 使用中文作为ID，支持CSV翻译文件导入
# ==============================================================================

# 扩展自Node类，表示这是一个基本的场景节点
extends Node          # ← 必须加这一行

# 获取当前语言设置
func _get_current_locale() -> String:
	return TranslationServer.get_locale()

# 物品翻译方法
# @param key: String - 要翻译的文本键值（使用中文作为ID）
# @return: String - 翻译后的文本
func items(key: String) -> String:
	# 首先尝试使用Godot内置的翻译系统
	# 这将自动从CSV导入的翻译文件中查找翻译
	var translated = tr(key)
	
	# 如果翻译成功（不等于原始键值），返回翻译结果
	if translated != key:
		return translated
	
	# 否则返回原始键值
	return key
