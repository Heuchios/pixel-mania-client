extends Panel

## Reusable Shop product card.
##
## Instanced by Scripts/shop_ui.gd's create_shop_item_cards() once per visible
## Item Shop product - one instance per item_id, built fresh each time the
## player switches category (existing instances are queue_free()'d first).
## Configure it with configure(data, accent, gem_texture); it reports buy
## clicks back to the owner via the buy_pressed signal instead of reaching
## into shop_ui.gd itself, so this scene has no dependency on shop_ui.gd and
## can be reused anywhere else a "buy this item for N gems" card is needed.
##
## Gem Store's five hand-authored packs and the Featured Spotlight banner are
## intentionally NOT built from this component - they're already-working,
## differently-priced/laid-out panels (Gem Store sells for real money via
## Stripe/Google Play, not gems) that don't need to be rebuilt just to share
## this class. See shop_gui_scene_v1.md for the full reasoning.

signal buy_pressed(item_id: String, amount: int, price: int)

const PixelUIStyle = preload("res://Scripts/ui/pixel_ui_style.gd")

var item_id := ""
var item_amount := 1
var item_price := 0
var item_affordable := true

@onready var art_back: Panel = $ArtBack
@onready var accent_wash: ColorRect = $ArtBack/AccentWash
@onready var icon: TextureRect = $ArtBack/IconSlot/Icon
@onready var icon_hint: Label = $ArtBack/IconSlot/IconHint
@onready var badge: Panel = $ArtBack/Badge
@onready var badge_label: Label = $ArtBack/Badge/BadgeLabel
@onready var name_label: Label = $NameLabel
@onready var buy_button: Button = $BuyButton
@onready var price_icon: TextureRect = $BuyButton/PriceIcon
@onready var price_label: Label = $BuyButton/PriceLabel


func _ready() -> void:
	pivot_offset = size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	if not buy_button.pressed.is_connected(_on_buy_button_pressed):
		buy_button.pressed.connect(_on_buy_button_pressed)


## data accepts the shop's existing field names plus a couple of friendly
## aliases, so callers don't need to reshape their item dictionaries:
##   item_id, price, amount (or quantity)
##   display_name (or name) - falls back to item_id if omitted
##   description
##   icon - a Texture2D, or null to show the "ICON" placeholder hint
##   category (or currency_type) - shown as the corner badge text
## accent tints the badge and the art backdrop wash. gem_texture is the
## currency icon shown next to the price (kept as a parameter rather than a
## hardcoded path so this scene never has to know how PixelMania resolves
## currency textures - shop_ui.gd already owns that via world.currency_textures).
func configure(data: Dictionary, accent: Color = Color(0.76, 0.93, 1.0, 1.0), gem_texture: Texture2D = null) -> void:
	item_id = str(data.get("item_id", ""))
	item_amount = int(data.get("amount", data.get("quantity", 1)))
	item_price = int(data.get("price", 0))

	var display_name = str(data.get("display_name", data.get("name", item_id)))
	var description = str(data.get("description", ""))
	var category = str(data.get("category", data.get("currency_type", ""))).strip_edges()
	var icon_texture = data.get("icon", null)

	name = "ShopCard_" + item_id
	tooltip_text = description
	pivot_offset = size * 0.5

	if accent_wash != null:
		accent_wash.color = Color(accent.r, accent.g, accent.b, 0.20)

	if icon != null:
		icon.texture = icon_texture
	if icon_hint != null:
		icon_hint.visible = icon_texture == null

	if badge != null:
		badge.add_theme_stylebox_override("panel", PixelUIStyle.style_box(
			Color(accent.r, accent.g, accent.b, 0.28), Color(accent.r, accent.g, accent.b, 0.9), 2, 8, 0
		))
	if badge_label != null:
		badge_label.visible = category != ""
		badge_label.text = category.to_upper()

	if name_label != null:
		name_label.text = display_name if item_amount <= 1 else (display_name + " x" + str(item_amount))

	if buy_button != null:
		buy_button.tooltip_text = "Buy " + display_name

	if price_label != null:
		price_label.text = _format_price(item_price)

	if price_icon != null and gem_texture != null:
		price_icon.texture = gem_texture

	set_affordable(true)


## The only supported "can't buy this" state today is insufficient gems -
## shop_ui.gd recomputes this whenever the cached gem balance changes and
## calls set_affordable() on every live card. There is no sold-out/owned
## concept in the current shop data, so this intentionally stays the only
## disabled state this component knows about.
func set_affordable(affordable: bool) -> void:
	item_affordable = affordable
	if buy_button != null:
		buy_button.disabled = not affordable


func _format_price(value: int) -> String:
	var digits = str(max(0, value))
	var result = ""
	var group_count = 0
	for i in range(digits.length() - 1, -1, -1):
		if group_count == 3:
			result = "," + result
			group_count = 0
		result = digits.substr(i, 1) + result
		group_count += 1
	return result


func _on_buy_button_pressed() -> void:
	play_buy_feedback()
	buy_pressed.emit(item_id, item_amount, item_price)


func play_buy_feedback() -> void:
	if buy_button == null:
		return
	var tween = create_tween()
	tween.tween_property(buy_button, "scale", Vector2(0.94, 0.94), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(buy_button, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _on_mouse_entered() -> void:
	# Subtle hover lift, per the "keep animations subtle" guidance - no bounce/rotation.
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_mouse_exited() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
