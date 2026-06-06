extends CanvasLayer

# CRT滤镜控制器
# 用于管理游戏中的CRT滤镜效果

@onready var crt_filter_node: ColorRect = $CRTFilterColorRect

# 滤镜参数
@export var 启用: bool = true:
	set(value):
		启用 = value
		_update_filter_visibility()

@export var 像素分辨率X: int = 1920:
	set(value):
		像素分辨率X = value
		_update_shader_parameter("pixel_resolution_x", value)

@export var 像素分辨率Y: int = 1080:
	set(value):
		像素分辨率Y = value
		_update_shader_parameter("pixel_resolution_y", value)

@export var 噪点强度: float = 0.1:
	set(value):
		噪点强度 = value
		_update_shader_parameter("grain_intensity", value)

@export var 扫描线强度: float = 0.2:
	set(value):
		扫描线强度 = value
		_update_shader_parameter("scanline_intensity", value)

@export var 暗角强度: float = 0.05:
	set(value):
		暗角强度 = value
		_update_shader_parameter("vignette_darkness", value)

@export var 色差强度: float = 0.003:
	set(value):
		色差强度 = value
		_update_shader_parameter("chromatic_aberration", value)

@export var 波动强度: float = 0.001:
	set(value):
		波动强度 = value
		_update_shader_parameter("warble_amount", value)

func _ready():
	# 确保着色器材质已正确设置
	if crt_filter_node and not crt_filter_node.material:
		crt_filter_node.material = ShaderMaterial.new()
		crt_filter_node.material.shader = load("res://shaders/crt_filter.gdshader")
	
	# 应用初始设置
	_update_filter_visibility()
	_update_all_shader_parameters()

func _update_filter_visibility():
	if crt_filter_node:
		crt_filter_node.visible = 启用

func _update_shader_parameter(param_name: String, value):
	if crt_filter_node and crt_filter_node.material:
		crt_filter_node.material.set_shader_parameter(param_name, value)

func _update_all_shader_parameters():
	if not crt_filter_node or not crt_filter_node.material:
		return
	
	_update_shader_parameter("pixel_resolution_x", 像素分辨率X)
	_update_shader_parameter("pixel_resolution_y", 像素分辨率Y)
	_update_shader_parameter("grain_intensity", 噪点强度)
	_update_shader_parameter("scanline_intensity", 扫描线强度)
	_update_shader_parameter("vignette_darkness", 暗角强度)
	_update_shader_parameter("chromatic_aberration", 色差强度)
	_update_shader_parameter("warble_amount", 波动强度)

# 公共方法
func set_filter_enabled(is_enabled: bool):
	启用 = is_enabled

func toggle_filter():
	启用 = !启用

func set_pixel_resolution(x: int, y: int):
	像素分辨率X = x
	像素分辨率Y = y

func set_intensity_settings(grain: float, scanline: float, vignette: float):
	噪点强度 = grain
	扫描线强度 = scanline
	暗角强度 = vignette

# 预设模式
func set_preset_modern():
	# 现代风格，轻微效果
	set_pixel_resolution(640, 480)
	set_intensity_settings(0.05, 0.1, 0.3)
	色差强度 = 0.003
	波动强度 = 0.001

func set_preset_retro():
	# 复古风格，强烈效果
	set_pixel_resolution(320, 240)
	set_intensity_settings(0.15, 0.3, 0.6)
	色差强度 = 0.005
	波动强度 = 0.002

func set_preset_extreme():
	# 极端效果，用于特殊场景
	set_pixel_resolution(160, 120)
	set_intensity_settings(0.25, 0.5, 0.8)
	色差强度 = 0.008
	波动强度 = 0.003