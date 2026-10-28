# 주요 인물 필드 스프라이트

## 찾은 설정집 자료

주요 여성 관장과 흑월단 간부의 승인 디자인은 `reference/02_승인_일러스트/여성체육관관장_4인.webp`, `reference/02_승인_일러스트/흑월단간부_4인.webp`에 있습니다. 실제 게임 필드의 SD 표현 참고는 `reference/04_게임화면_스타일/SD_캐릭터_컨셉참고.webp`와 `reference/04_게임화면_스타일/캐릭터_SD_필드_대화_참고.webp`입니다. 두 SD 시트는 방향·비율을 참고하는 자료이며 승인 원본 일러스트를 대체하지 않습니다.

사천왕은 `reference/03_콘셉트_참고/사천왕_챔피언_무영_콘셉트.webp`에서 찾았습니다. 최신 승인 가이드에 따라 이 자료는 최종 승인본이 아니라 콘셉트로 취급하며, 이를 근거로 만든 사천왕 스프라이트는 **검토용 초안**입니다.

## 제작한 필드 아틀라스

각 아틀라스는 192×144 PNG이며, 48×48 프레임 12개를 4열×3행으로 배열합니다. 열은 아래/정면, 왼쪽, 오른쪽, 위/뒷면이고 행은 대기, 걷기 A, 걷기 B입니다. 투명 배경을 사용하며 nearest-neighbor 방식으로 줄여 픽셀 경계를 보존합니다.

### 사용자가 제공한 시트

- 플레이어: 원본 `assets/sources/user_field_sheets/player_male_sheet.png` → `assets/generated/player_walk_48.png`
- 서하린: 원본 `assets/sources/user_field_sheets/harin_sheet.png` → `assets/generated/harin_walk_48.png`
- 백서화: 원본 `assets/sources/user_field_sheets/seohwa_sheet.png` → `assets/generated/seohwa_walk_48.png`

### 승인 개별 디자인에서 파생한 관장·간부 시트

이 자산들은 승인 디자인을 작은 필드용 SD로 옮긴 작업용 스프라이트이며, 원본 일러스트나 개별 최종 승인을 대신하지 않습니다.

- 설유나 — `assets/generated/field_characters/seol_yuna_walk_48.png`
- 윤서린 — `assets/generated/field_characters/yun_seorin_walk_48.png`
- 문시연 — `assets/generated/field_characters/moon_si_yeon_walk_48.png`
- 해나리 — `assets/generated/field_characters/hae_nari_walk_48.png`
- 에리카 — `assets/generated/field_characters/erika_walk_48.png`
- 레이나 — `assets/generated/field_characters/reina_walk_48.png`
- 카이엔 — `assets/generated/field_characters/kaien_walk_48.png`
- 시오리 — `assets/generated/field_characters/shiori_walk_48.png`

### 콘셉트 기반 검토용 사천왕 초안

- 세아린 — `assets/generated/field_characters/se_arin_walk_48.png`
- 렌 카이토 — `assets/generated/field_characters/ren_kaito_walk_48.png`
- 카렌 유즈화 — `assets/generated/field_characters/karen_yuzuhwa_walk_48.png`
- 신 츠카사 — `assets/generated/field_characters/shin_tsukasa_walk_48.png`

## 런타임 연결 범위

`game/field.gd`는 플레이어와 서하린·백서화, 그리고 위 12명의 캐릭터 시트를 로드합니다. 필드 NPC에 `character_id`를 주면 해당 ID의 시트를 우선 사용하고, 미등록 ID는 기존 기본 NPC 표현으로 폴백합니다. 따라서 앞으로 인물별 지역 맵을 추가할 때 자산을 재사용할 수 있습니다.

현 체험판은 인천부터 수원까지라서 실제 지도에 배치되어 움직이는 고유 인물은 플레이어·서하린·백서화뿐입니다. 설악산·대전·전주·경주·부산 및 서울의 나머지 캐릭터는 관련 지역 맵이 아직 구현되지 않았으므로, 이번 작업은 이들의 스프라이트를 만든 것이지 해당 지역을 플레이 가능하게 만든 것은 아닙니다.

설정집의 정식 진행표상 수원 이도윤, 대전 한태오, 광주 백시온, 대구 강태준의 개별 최종 승인 필드 시트는 이 전달 패키지에서 찾지 못했습니다. `reference/03_콘셉트_참고/게임기획_종합포스터.webp`에는 지역별 관장 초상 콘셉트가 있지만, 가이드는 포스터·합본을 최종 승인본으로 보지 않고 이미지 자동 생성 문구도 설정 근거로 삼지 말라고 지정합니다. 해당 네 인물의 외형은 임의 제작하거나 승인된 것으로 표기하지 않았습니다.

## 재생성 및 검증

```sh
python3 scripts/prepare_user_field_sheets.py
python3 scripts/prepare_field_character_assets.py
bash scripts/godot.sh --headless --editor --import --quit
bash scripts/godot.sh --headless --script tests/test_scene.gd
```

장면 회귀는 15개 필드 캐릭터의 아틀라스 로딩과 192×144 규격을 검사합니다. 2026-10-28 기준 엔진 테스트는 318검사, 헤드리스 장면은 457검사, X11/OpenGL 장면은 489검사와 16장 캡처를 통과했습니다. 생성된 12명 아틀라스의 검수 접촉 시트는 `qa/character-sprites/12-major-character-atlases.png`에 있습니다.
