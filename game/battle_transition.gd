extends Control

# 모든 배틀이 공유하는 짧은 셔터 전환. 필드 좌표와 저장 상태는 수정하지 않습니다.
enum Kind { WILD, TRAINER, GYM, STORY }
var active := false
var generation := 0
var coverage := 0.0
var tint := Color("183d35")
var _tween: Tween

func _ready() -> void:
	position = Vector2(20,100)
	size = Vector2(960,640)
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

func cancel() -> void:
	generation += 1
	if _tween != null and _tween.is_valid(): _tween.kill()
	active = false
	coverage = 0.0
	hide()

func cover(kind: int) -> bool:
	if active: return false
	active = true
	generation += 1
	var token := generation
	tint = Color("5b4225") if kind == Kind.GYM else Color("183d35")
	show()
	await _animate(1.0,0.28)
	return token == generation

func reveal() -> bool:
	var token := generation
	await _animate(0.0,0.28)
	if token != generation: return false
	active = false
	hide()
	return true

func _animate(target: float, duration: float) -> void:
	_tween = create_tween()
	_tween.tween_method(func(value: float): coverage = value; queue_redraw(),coverage,target,duration)
	# 취소한 트윈의 finished 신호를 기다리며 멈추지 않도록 타이머를 사용합니다.
	await get_tree().create_timer(duration+0.02).timeout

func _draw() -> void:
	for row in range(10):
		var width := size.x*coverage
		draw_rect(Rect2(0 if row%2 == 0 else size.x-width,row*64,width,64),tint)
