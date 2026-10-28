# 외부 스프라이트 출처

## 1–9세대·공식 메가진화 전투 스프라이트

전국도감 #001–#1025와 PokéAPI에 앞·뒤 PNG가 제공되는 공식 메가진화 96폼은 PokéAPI Sprites 저장소의 Generation V Black/White 정적 스프라이트를 우선 사용합니다. 원본 투명 PNG는 `assets/catalog/pokemon/<slug>/<front|back>.png`에 보존하며, `scripts/sync_pokemon_sprite_catalog.py`로 재현할 수 있습니다. 이 범위의 종은 임의 생성 이미지로 대체하지 않습니다.

- 저장소: https://github.com/PokeAPI/sprites
- 기본 전면: `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/<resource-id>.png`
- 기본 후면: `https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/versions/generation-v/black-white/back/<resource-id>.png`
- 구구·피죤·피죤투의 원본 96×96 파일은 호환성 참조용으로 `assets/sources/pokeapi-gen5-birds/`에도 보존합니다.

PokéAPI 저장소는 Generation V Black/White 폴더에 공식 B&W 스프라이트를 수록한다고 설명합니다. 상업적 배포 또는 퍼블릭 출시 전에는 포켓몬 IP 사용 권한을 별도로 검토해야 합니다.

## 한국 지역 오리지널 종·특수 폼

푸르내 계열·화랑이 계열·파도링 계열, 전설 수호자 6종(천화구, 천화린, 월화록, 청해룡, 금련화, 월해령), 승인 기획의 한국 지방 리전폼 12종, 신규 메가진화 5종은 확정 문서와 콘셉트 시트 범위 안에서 제작한 오리지널 픽셀 스프라이트입니다. 리전폼 12종 초안 시트보다 별도 최신 승인본이 있는 대여르·드레디어를 우선하고, 특수 이로치 메가가디안은 `메가가디안_한국풍_최신승인.webp`를 우선합니다. 전·후면 정규화 결과는 `assets/generated/battle/`에 있습니다. 이 폼들은 `storyOnly` 데이터로 등록되어 이후 지역용이며, 현 체험판 출현·메가전투 시스템을 의미하지 않습니다. 상세 범위·검증은 [SPECIAL_FORMS.md](SPECIAL_FORMS.md)와 [SPRITE_CATALOG.md](SPRITE_CATALOG.md)를 따릅니다.
