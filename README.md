# Dream in Hotel

这是一个3D酒店探索游戏项目，使用Godot引擎开发。

## 项目简介

该项目是一个3D游戏，玩家可以在酒店环境中探索，与物品互动，管理体力，使用钥匙开门等。

## 主要功能

- 3D角色控制和动画系统
- 物品拾取和库存管理
- 体力系统和UI显示
- 钥匙和门交互系统
- 多语言支持

## 开发环境

- Godot Engine
- GDScript

## 项目结构

```
├── .gitattributes        # Git属性配置文件
├── .gitignore            # Git忽略文件配置
├── LICENSE               # 许可证文件
├── README.md             # 项目说明文档
├── assets/               # 游戏资源目录
│   ├── animations/       # 动画资源
│   │   ├── Jump.res      # 跳跃动画资源
│   │   └── animal_character/ # 动物角色动画
│   └── characters/       # 角色模型和纹理
│       └── main_character/ # 主角模型和材质
├── export_presets.cfg    # Godot导出配置
├── icon.svg              # 项目图标
├── project.godot         # Godot项目主文件
├── resources/            # 游戏资源文件
│   └── items/            # 物品资源文件
│       ├── drink.tres    # 饮料物品定义
│       └── key1.tres     # 钥匙物品定义
├── scenes/               # 场景文件目录
│   ├── characters/       # 角色相关场景
│   │   └── player.tscn   # 玩家角色场景
│   ├── items/            # 物品相关场景
│   │   ├── DroppableItem.tscn # 可掉落物品场景
│   │   ├── InventoryGUI3D.tscn # 3D背包界面场景
│   │   └── ItemPreviewGUI.tscn # 物品预览界面场景
│   ├── try.tscn          # 测试场景
│   ├── ui/               # UI相关场景
│   │   └── StaminaUI.tscn # 体力UI场景
│   └── world/            # 世界场景
│       └── hotel/        # 酒店场景和环境
├── scripts/              # 脚本文件目录
│   ├── Global.gd         # 全局脚本文件
│   ├── characters/       # 角色相关脚本
│   │   ├── inventory.gd  # 背包系统脚本
│   │   ├── player.gd     # 玩家控制脚本
│   │   └── skeleton_3d.gd # 骨骼动画控制脚本
│   ├── items/            # 物品相关脚本
│   │   ├── InventoryGUI3D.gd # 3D背包界面脚本
│   │   ├── Item.gd       # 物品基类脚本
│   │   ├── droppable_item.gd # 可掉落物品脚本
│   │   ├── effects/      # 物品效果脚本
│   │   └── item_preview_gui.gd # 物品预览界面脚本
│   ├── ui/               # UI相关脚本
│   │   └── stamina_ui.gd # 体力UI脚本
│   └── world/            # 世界相关脚本
├── translations/         # 翻译文件目录
│   └── items.csv         # 物品翻译文件
├── ui/                   # UI资源目录
└── utils/                # 工具类脚本
    └── Tr.gd             # 翻译工具脚本

## 如何运行

1. 使用Godot引擎打开项目
2. 运行主场景开始游戏

## 许可证

MIT License