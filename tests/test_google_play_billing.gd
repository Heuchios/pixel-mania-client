extends SceneTree
const Adapter = preload("res://Scripts/billing_client.gd")
var failures := 0
class FakeNative extends Node:
	var consumed: Array = []
	func consume_purchase(token: String) -> void:
		consumed.append(token)

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	# Never enter the tree: no Android singleton initialization or network connection.
	var billing = Adapter.new()
	var previews: Array = []
	billing.request_preview.connect(func(request): previews.append(request))
	var shop_source := FileAccess.get_file_as_string("res://Scripts/shop_ui.gd")
	for pack in ["pouch", "sack", "chest", "vault", "mountain"]:
		check(shop_source.contains('"id": "' + pack + '"'), "Missing shop pack: " + pack)
		billing.set_obfuscated_account_id("billing_test_account")
		var request: Dictionary = billing.purchase("gems_" + pack, true)
		check(request == {"product_id": "gems_" + pack, "product_type": "inapp", "obfuscated_account_id": "billing_test_account"}, "Incorrect request: " + pack)
		print("PASS preview gems_", pack)
	check(previews.size() == 5, "Expected exactly five previews")
	check(billing.purchase("gems_pouch", true).is_empty(), "Stale account reused")
	for invalid in ["", "pouch", "gems_unknown", "gems_pouch_extra"]:
		billing.set_obfuscated_account_id("billing_test_account")
		check(billing.purchase(invalid, true).is_empty(), "Invalid product accepted")
	check(billing.native == null and billing.pending_receipts.is_empty(), "Preview touched live billing")
	var fake := FakeNative.new()
	billing.native = fake
	billing.pending_receipts["verified-request"] = "test-token"
	billing._verified({"request_id": "unknown", "ok": true})
	check(fake.consumed.is_empty(), "Uncorrelated success consumed a purchase")
	billing._verified({"request_id": "verified-request", "ok": false})
	check(fake.consumed.is_empty(), "Rejected receipt consumed a purchase")
	billing.pending_receipts["verified-request"] = "test-token"
	billing._verified({"request_id": "verified-request", "ok": true})
	check(fake.consumed == ["test-token"], "Verified receipt was not consumed")
	billing._verified({"request_id": "verified-request", "ok": true})
	check(fake.consumed.size() == 1, "Duplicate reply consumed twice")
	fake.free()
	billing.free()
	quit(1 if failures else 0)
