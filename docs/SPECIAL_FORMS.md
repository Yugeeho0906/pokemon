# 한국 지방 리전폼 · 신규 메가진화

이 문서는 기획서에 확정된 특수 폼의 데이터·아트 준비 상태를 기록한다. 인천–수원 체험판에서는 아직 야생·트레이너·체육관 출현 테이블에 넣지 않는다. 모든 항목은 `storyOnly: true`이며 이후 지역·이벤트·메가진화 시스템에서만 해금한다.

## 한국 지방 리전폼 12종

| ID | 이름 | 타입 | 상태 |
|---|---|---|---|
| `ninetales_korean` | 나인테일(한국폼) | 고스트/페어리 | 스프라이트 준비 |
| `arcanine_korean` | 윈디(한국폼) | 불꽃/바위 | 스프라이트 준비 |
| `bronzong_korean` | 동탁군(한국폼) | 강철/고스트 | 스프라이트 준비 |
| `lilligant_korean` | 드레디어(한국폼) | 풀/페어리 | 스프라이트 준비 — 개별 승인본 우선 |
| `noctowl_korean` | 야부엉(한국폼) | 에스퍼/비행 | 스프라이트 준비 |
| `rapidash_korean` | 날쌩마(한국폼) | 물/페어리 | 스프라이트 준비 |
| `chimecho_korean` | 치렁(한국폼) | 에스퍼/페어리 | 스프라이트 준비 |
| `absol_korean` | 앱솔(한국폼) | 악/얼음 | 스프라이트 준비 |
| `lucario_korean` | 루카리오(한국폼) | 격투/강철 | 스프라이트 준비 |
| `falinks_korean` | 대여르(한국폼) | 격투/강철 | 스프라이트 준비 — 개별 승인본 우선 |
| `decidueye_korean` | 모크나이퍼(한국폼) | 풀/고스트 | 스프라이트 준비 |
| `milotic_korean` | 밀로틱(한국폼) | 물/드래곤 | 스프라이트 준비 |

## 신규 메가진화 5종

| ID | 이름 | 기준 종 | 상태 |
|---|---|---|---|
| `mega_ulchangryeong` | 메가울창령 | 울창령 | 스프라이트 준비 |
| `mega_jinhwarang` | 메가진화랑 | 진화랑 | 스프라이트 준비 |
| `mega_haeryushin` | 메가해류신 | 해류신 | 스프라이트 준비 |
| `mega_cheonhwagu` | 메가천화구 | 천화구 | 스프라이트 준비 |
| `mega_gardevoir_korean_shiny` | 특수 이로치 메가가디안 | 가디안 | 스프라이트 준비 — 최신 개별 승인본 우선 |

`game/data.json`의 `assetStatus`가 실제 준비 상태를 표시한다. `scripts/prepare_special_form_battle_art.py`는 17개 포즈쌍을 각각 `*_front.png`·`*_back.png`로 정규화하며, `scripts/sync_pokemon_sprite_catalog.py`는 준비된 폼을 `custom_entries`로 등록한다. 현재 `pending_custom_entries`는 비어 있다. 이후 새 폼을 추가할 때에도 미완성 항목은 임의의 다른 종·일반 폼·플레이스홀더로 대체하지 않는다.
