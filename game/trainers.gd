extends RefCounted

# 필드 시트는 기존 규격 192×144 (48×48, 방향 4열 × 동작 3행)을 사용합니다.
const IDS = ["ace_m","ace_f","youngster","lass","student_m","student_f","hiker","backpacker","taekwondo","martial_artist","researcher","swimmer"]
const NAMES = ["엘리트 남성","엘리트 여성","반바지 꼬마","미니스커트","남학생","여학생","등산가","배낭여행자","태권도 수련생","무술가","연구원","수영선수"]

static func battle_texture(id: String) -> Texture2D:
	var index := IDS.find(id)
	if index < 0: return null
	var path := "res://assets/trainers/battle_atlas.png"
	if not ResourceLoader.exists(path): return null
	var texture: Texture2D = load(path)
	var x := roundi((index%4)*texture.get_width()/4.0)
	var right := roundi((index%4+1)*texture.get_width()/4.0)
	var y := roundi((index/4)*texture.get_height()/3.0)
	var bottom := roundi((index/4+1)*texture.get_height()/3.0)
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(x,y,right-x,bottom-y)
	return atlas
