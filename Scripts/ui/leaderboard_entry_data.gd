@tool
extends Resource
class_name PixelLeaderboardEntryData

@export_range(1, 999, 1) var rank: int = 1
@export var player_name: String = "PixelHero"
@export var points: int = 0
@export var avatar_texture: Texture2D = null
@export var avatar_color: Color = Color(0.95, 0.52, 0.20, 1.0)
@export var reward_texture: Texture2D = null
@export var reward_label: String = ""
@export var highlighted: bool = false

@export_group("Optional Overrides")
@export var row_fill_override: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var row_border_override: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var name_color_override: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var points_color_override: Color = Color(0.0, 0.0, 0.0, 0.0)
@export var metadata: Dictionary = {}
