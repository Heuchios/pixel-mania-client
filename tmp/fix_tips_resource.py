from pathlib import Path
p=Path('Scenes/ui/lobby/LobbyScene.tscn');s=p.read_text(encoding='utf-8');line='[ext_resource type="Script" path="res://Scripts/ui/lobby_gameplay_tips.gd" id="gameplay_tips"]\n\n';s=s.replace(line,'');idx=s.index('[ext_resource');s=s[:idx]+line+s[idx:];p.write_text(s,encoding='utf-8')
