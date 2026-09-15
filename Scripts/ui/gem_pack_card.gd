extends Panel

## Reusable Gem Store pack card.
##
## Instanced by Scripts/shop_ui.gd's build_gem_store_cards() once per entry in
## GEM_PACK_CARDS -- one instance per real-money gem pack (pouch/sack/chest/
## vault/mountain today, but any future pack just means adding a dictionary to
## that array, not duplicating a node tree). This replaces the old
## hand-authored Card_pouch/Card_sack/Card_chest/Card_vault/Card_mountain
## Panel node trees that used to live directly in ShopScene.tscn.
##
## Configure it with configure(data); it reports buy clicks back to the owner
## via the buy_pressed signal instead of reaching into shop_ui.gd itself, the
## same pattern shop_item_card.gd already uses for the regular gem-priced item
## cards, so this scene has no dependency on shop_ui.gd.

signal buy_pressed(pack_id: String, pack_label: String)

var pack_id := ""
var pack_label := ""

@onready var featured_frame: Panel = $FeaturedFrame
@onready var ribbon: Panel = $Ribbon
@onready var ribbon_label: Label = $Ribbon/RibbonLabel
@onready var icon_slot: Panel = $IconSlot
@onready var icon: TextureRect = $IconSlot/Icon
@onready var icon_hint: Label = $IconSlot/IconHint
@onready var gem_amount_label: Label = $GemAmount
@onready var edition_label: Label = $EditionLabel
@onready var bonus_label: Label = $BonusLabel
@onready var buy_button: Button = $BuyButton


func _ready() -> void:
	if not buy_button.pressed.is_connected(_on_buy_button_pressed):
		buy_button.pressed.connect(_on_buy_button_pressed)


## data fields (all optional except "gems"):
##   id (String) - must match a key in the server's GEM_PACKS table
##                 (PixelManiaServer/src/server_iap_routes.ts), or "" for
##                 bundles that aren't purchasable through that table yet
##   gems (int) - gem amount, shown as "N,NNN GEMS"
##   price (String) - display price text, e.g. "$4.99". The server is always
##                     the source of truth for what actually gets charged --
##                     this is display text only, same rule the old hand-built
##                     cards followed.
##   edition (String) - subtitle under the gem amount, e.g. "Pocket Edition"
##                       (shown upper-cased). Omit or "" to hide it.
##   bonus (String) - optional green corner-of-icon callout, e.g. "+10% BONUS".
##                     Omit or "" to hide it.
##   ribbon (String) - optional rotated corner ribbon text, e.g. "POPULAR".
##                      Omit or "" to hide it.
##   featured (bool) - shows the extra glowing frame around the card.
##   icon (Texture2D) - optional pack icon; null shows the "ICON" placeholder,
##                       same as shop_item_card.gd's convention.
func configure(data: Dictionary) -> void:
	pack_id = str(data.get("id", ""))
	var gems = int(data.get("gems", 0))
	pack_label = str(data.get("label", _format_gems(gems) + " Gems"))

	name = "GemPackCard_" + (pack_id if pack_id != "" else pack_label)

	if gem_amount_label != null:
		gem_amount_label.text = _format_gems(gems) + " GEMS"

	if edition_label != null:
		var edition = str(data.get("edition", ""))
		edition_label.visible = edition != ""
		edition_label.text = edition.to_upper()

	if bonus_label != null:
		var bonus = str(data.get("bonus", ""))
		bonus_label.visible = bonus != ""
		bonus_label.text = bonus

	if ribbon != null:
		var ribbon_text = str(data.get("ribbon", ""))
		ribbon.visible = ribbon_text != ""
		if ribbon_label != null:
			ribbon_label.text = ribbon_text

	if featured_frame != null:
		featured_frame.visible = bool(data.get("featured", false))

	var icon_texture = data.get("icon", null)
	if icon != null:
		icon.texture = icon_texture
	if icon_hint != null:
		icon_hint.visible = icon_texture == null

	if buy_button != null:
		buy_button.text = str(data.get("price", "$0.00"))
		buy_button.tooltip_text = "Buy " + pack_label


func _on_buy_button_pressed() -> void:
	play_buy_feedback()
	buy_pressed.emit(pack_id, pack_label)


func play_buy_feedback() -> void:
	if buy_button == null:
		return
	var tween = create_tween()
	tween.tween_property(buy_button, "scale", Vector2(0.96, 0.96), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(buy_button, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _format_gems(value: int) -> String:
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
