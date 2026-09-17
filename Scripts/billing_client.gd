extends Node
## PixelMania adapter. Receipt validation and gem balances belong to the server.
const NativeBilling = preload("res://addons/GodotGooglePlayBilling/BillingClient.gd")
const PACK_IDS = ["pouch", "sack", "chest", "vault", "mountain"]
signal billing_message(message: String)
signal request_preview(request: Dictionary)
var native: Node
var account_id := ""
var products: Array[String] = []
var pending_receipts: Dictionary = {}

static func build_request(product_id: String, username: String) -> Dictionary:
	if not product_id.begins_with("gems_") or not product_id.trim_prefix("gems_") in PACK_IDS:
		return {}
	if username.strip_edges().is_empty() or username.length() > 64:
		return {}
	return {"product_id": product_id, "product_type": "inapp", "obfuscated_account_id": username}

func _ready() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	native = NativeBilling.new()
	add_child(native)
	native.connected.connect(_connected)
	native.disconnected.connect(func(): products.clear())
	native.connect_error.connect(func(_code, _message): billing_message.emit("Google Play connection failed. Try again."))
	native.query_product_details_response.connect(_products_received)
	native.on_purchase_updated.connect(_receipts_received)
	native.query_purchases_response.connect(_receipts_received)
	get_node("/root/NetworkManager").iap_purchase_result.connect(_verified)
	var recovery := Timer.new()
	recovery.wait_time = 60.0
	recovery.timeout.connect(func():
		# Retry retained purchases after login or a lost server reply. Server deduplicates tokens.
		pending_receipts.clear()
		if native.is_ready():
			native.query_purchases(NativeBilling.ProductType.INAPP)
		else:
			native.start_connection()
	)
	add_child(recovery)
	recovery.start()
	native.start_connection()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and native != null:
		if native.is_ready():
			native.query_purchases(NativeBilling.ProductType.INAPP)
		else:
			native.start_connection()

func _connected() -> void:
	var ids := PackedStringArray()
	for pack in PACK_IDS:
		ids.append("gems_" + pack)
	native.query_product_details(ids, NativeBilling.ProductType.INAPP)
	native.query_purchases(NativeBilling.ProductType.INAPP)

func _products_received(result: Dictionary) -> void:
	products.clear()
	if int(result.get("response_code", -1)) != 0:
		billing_message.emit("Google Play products could not be loaded. Try again.")
		return
	for product in result.get("product_details", []):
		products.append(str(product.get("product_id", "")))

func set_obfuscated_account_id(username: String) -> void:
	account_id = username

func purchase(product_id: String, preview_only: bool = false) -> Dictionary:
	var request := build_request(product_id, account_id)
	account_id = "" # Require fresh account binding for every press.
	if request.is_empty():
		billing_message.emit("Sign in and select a valid gem pack.")
		return {}
	if preview_only:
		# Explicit per-call preview: no native call, token, network request or reward.
		request_preview.emit(request)
		return request
	if native == null:
		billing_message.emit("Google Play purchases are unavailable on this device.")
		return {}
	if not native.is_ready() or not product_id in products:
		billing_message.emit("Google Play is loading. Please try again shortly.")
		if native.is_ready():
			_connected()
		else:
			native.start_connection()
		return {}
	native.set_obfuscated_account_id(request.obfuscated_account_id)
	var result: Dictionary = native.purchase(product_id)
	if int(result.get("response_code", -1)) != 0:
		billing_message.emit("Google Play checkout could not open. Please try again.")
	return result

func _receipts_received(result: Dictionary) -> void:
	if int(result.get("response_code", -1)) != 0:
		billing_message.emit("Google Play purchase canceled or unavailable.")
		return
	var network := get_node_or_null("/root/NetworkManager")
	if network == null or not network.is_server_session_authenticated():
		return # Play retains unconsumed purchases for the next query.
	for receipt in result.get("purchases", []):
		if not receipt is Dictionary or int(receipt.get("purchase_state", 0)) != 1:
			continue
		var ids = receipt.get("product_ids", [])
		var token := str(receipt.get("purchase_token", ""))
		if ids.size() != 1 or token.is_empty() or token in pending_receipts.values():
			continue
		var product_id := str(ids[0])
		if build_request(product_id, str(network.session_username)).is_empty():
			continue
		var request_id: String = network.send_iap_submit_google_play_purchase_request(product_id.trim_prefix("gems_"), token, product_id)
		if not request_id.is_empty():
			pending_receipts[request_id] = token

func _verified(result: Dictionary) -> void:
	var request_id := str(result.get("request_id", ""))
	if not pending_receipts.has(request_id):
		return
	var token: String = pending_receipts[request_id]
	pending_receipts.erase(request_id)
	if bool(result.get("ok", false)) and native != null:
		# Only a correlated authoritative success (including replay) permits consumption.
		native.consume_purchase(token)
