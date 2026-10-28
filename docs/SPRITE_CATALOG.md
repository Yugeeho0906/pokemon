# 배틀 스프라이트 카탈로그

## 범위

`assets/catalog/pokemon_sprite_registry.json`은 배틀 아트의 **자산 레지스트리**입니다. 이 파일이 모든 종을 현재 체험판에서 포획·출현·도감 완성할 수 있다는 뜻은 아닙니다.

- 전국도감 1–9세대 기본 종: 1,025종, 전면·후면 각 1장
- 공식 메가진화 폼: 96종, 전면·후면 각 1장
- 한국 지역 스타팅 3계열: 푸르내·푸르솔이·울창령 / 화랑이·불호령·진화랑 / 파도링·물결달이·해류신
- 한국 지역 전설 수호자 6종: 천화구, 천화린, 월화록, 청해룡, 금련화, 월해령
- 한국 지방 리전폼 12종 및 신규 메가진화 5종: 전부 전·후면 게임 스프라이트 완료

현재 인천–수원 체험판의 실제 야생·트레이너·체육관 출현 테이블은 별도로 제한됩니다. 수호자·리전폼·신규 메가진화는 `storyOnly: true`로 등록되어 이후 지역·스토리에서만 배치해야 합니다. 폼 데이터와 아트 등록은 실제 메가진화 전투 기믹이 구현됐다는 뜻이 아닙니다.

## 원본·사용 규칙

공식 종과 공식 메가진화는 PokéAPI Sprites의 Generation V Black/White 정적 PNG를 우선 사용합니다. 따라서 공식 종의 자산은 AI로 유사하게 생성하지 않습니다. 원본이 제공되지 않는 비정규 항목은 억지로 대체하지 않고 레지스트리에서 제외합니다.

한국 지역 스타팅 계열·전설 수호자·확정된 리전폼·신규 메가진화만 프로젝트 승인/확정 콘셉트에 근거한 오리지널 픽셀 스프라이트를 사용합니다. 리전폼 초안과 별도 최신 승인본이 다르면 대여르·드레디어 개별 승인본과 메가가디안 최신 승인본이 우선입니다. 이 범위 밖의 임시 창작 종을 추가하지 않습니다.

## 재생성·검증

```sh
# 1–9세대·공식 메가진화 리소스 동기화 및 레지스트리 생성
python3 scripts/sync_pokemon_sprite_catalog.py --workers 12

# 전설 수호자 포즈쌍을 개별 전면·후면 192px PNG로 분리
python3 scripts/prepare_guardian_battle_art.py

# 한국 리전폼 12종·신규 메가진화 5종 포즈쌍 정규화
python3 scripts/prepare_special_form_battle_art.py
python3 scripts/sync_pokemon_sprite_catalog.py --workers 12

# 카탈로그 파일·오리지널 스타팅·수호자·특수 폼 리소스 검증
python3 scripts/verify_pokemon_sprite_catalog.py
```

게임은 `game/main.gd::_battle_texture`에서 `assets/catalog/pokemon/<id>/<front|back>.png`를 먼저 찾고, 프로젝트 오리지널 종은 `assets/generated/battle/<id>_<front|back>.png`를 사용합니다.
