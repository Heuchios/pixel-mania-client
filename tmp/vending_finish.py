from pathlib import Path
p=Path('Scripts/vending_ui.gd');s=p.read_text(encoding='utf-8')
s=s.replace('panel.get_node("PriceCard/PriceReadout").text = "PRICE\\n%d items for %d WL" % [bundle, int(listing.get("price_wls", 1))] if not listing.is_empty() else "No active listing"','panel.get_node("PriceCard/PriceReadout").text = "PRICE\\n%d %s for %d WL" % [bundle, "item" if bundle == 1 else "items", int(listing.get("price_wls", 1))] if not listing.is_empty() else "No active listing"')
s=s.replace('summary.text = "YOU RECEIVE: %d items\\nTOTAL: %d WL" % [count * bundle, total]','summary.text = "YOU RECEIVE: %d %s\\nTOTAL: %d WL" % [count * bundle, "item" if count * bundle == 1 else "items", total]')
s=s.replace('\tpanel.get_node("ItemCard/Hint").text = hint','\tpanel.get_node("ItemCard/Hint").text = hint\n\tpanel.get_node("ItemCard/Hint").tooltip_text = hint')
s=s.replace('\t\titem_icon.visible = false','\t\tpanel.get_node("ItemCard/Hint").tooltip_text = ""\n\t\titem_icon.visible = false',1)
p.write_text(s,encoding='utf-8')
p=Path('Scenes/ui/vending/VendingMachineGUI.tscn');s=p.read_text(encoding='utf-8');s=s.replace('text = "SALE SUMMARY"\n','text = "SALE SUMMARY"\nmetadata/pixelmania_font_size = 14\n');s=s.replace('text_overrun_behavior = 3','text_overrun_behavior = 3\nmax_lines_visible = 4');p.write_text(s,encoding='utf-8')
