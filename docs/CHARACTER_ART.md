# 심야접속 — 캐릭터 아트·생성 프롬프트 설계 v0.1

작성일: 2026-11-04 · 프로젝트 ID: `packet-trail` · 범위: 제작용 설계 초안.
이 문서는 [프로젝트 계획](../PROJECT_PLAN.md), [화면 설계](../DESIGN.md), [스토리·페이싱](PACING_AND_STORY.md)을 따른다.
인물은 모두 성인 허구이며 실존 인물·기존 게임 인물의 얼굴이나 특정 작가의 그림체를 복제하지 않는다.

## 1. 확정 범위와 이번 제안

| 구분 | 상태 |
|---|---|
| 제품 방향 | 작은 3D 작업실+전체 화면 가상 OS, 침투의 손맛·이야기·자유 해법 우선 |
| 기존 서사 기준 | 서윤은 익명 첫 의뢰인, 도윤은 회수 자료 해석과 다음 단서의 동료 |
| 제안 중 | 두 사람의 나이·성별 표현·외형, 추가 인물 이름·외형, 아래 팔레트·규격·프롬프트 |
| 사용자 확정 아님 | 생성 후보 선택, 캐릭터 외형 정본, 초상화 공개 시점, 추가 인물의 최종 배역 |
| 현재 산출물 | 이 문서의 아트 바이블·외형 제안·복사 가능한 영문 프롬프트 |
| 아직 없음 | 참조 이미지, 생성 이미지, 캐릭터 시트, 정본 초상화, 표정·UI 검수 결과 |

서윤·도윤의 이름도 기존 스토리 초안의 이름이다. 외형을 구체화했다고 세계관·이름까지 사용자 확정으로 승격하지 않는다.
현재는 초안을 구체적으로 제안하는 단계이며 실제 이미지·음악 생성은 실행하지 않는다.

## 2. 매체와 단계

주 표현은 **OS 메신저·메일·인물 기록에 사용하는 세미리얼 2D 일러스트 초상화**다.
작업실은 절제된 3D 공간으로 제작하되 초상화와 재질·색온도 분위기를 맞춘다. 얼굴을 3D NPC로 먼저 만들지는 않는다.
플레이어는 1인칭이며 자기 프로필을 선택한다. 전신 고정 얼굴은 자기 투영을 좁히고 모델링·리깅·애니메이션 비용을 추가하므로 지금 만들지 않는다.
자기 프로필은 허구 별칭과 추상 아이콘으로 시작하고, 사진 업로드나 자동 얼굴 생성은 초기 범위에 넣지 않는다.
P0/P1은 임시 프로필·텍스트만으로 충분하다. 완성 초상화·4인 전체 세트·3D 캐릭터 생성은 선행 조건이 아니다.

| 단계 | 캐릭터 아트 범위 |
|---|---|
| P0 | 임시 추상 아바타와 이름 자리만. 초상화 품질이 입력 검증을 막지 않음 |
| P1 | M01 서윤의 익명 아바타·의뢰 텍스트. 완성 얼굴·4인 표정팩은 완료 조건 아님 |
| P2 | 3미션에서 실제 등장·공개되는 인물부터 첫 초상화와 UI 축소 검증; 3D 방은 회색상자 |
| P3 | 반복 등장 인물의 정본·표정 세트, ko/en 화면 검수와 제작 공수 실측 |
| P4/P5 | 최종 배역만 완성·다국어 화면·세 OS 표시 확인. 미등장 인물은 제작하지 않음 |

## 3. 공통 아트 바이블

| 요소 | 제작 제안 |
|---|---|
| 현실성 | 성인의 자연스러운 비율·피부·연령 표현. 사진 같은 미세 디테일보다 읽기 쉬운 회화적 면 |
| 선·형태 | 얇고 끊긴 외곽선, 얼굴·머리·어깨의 큰 면 3~5개 우선. 머리카락 한 올씩 묘사하지 않음 |
| 빛 | 화면 기준 왼쪽 위의 부드러운 중성 키라이트, 약한 회청색 반사광. 눈과 얼굴 중심은 충분히 밝게 |
| 질감 | 무광 피부·직물, 제한된 붓결. 뷰티 리터칭·기름진 광택·과도한 노이즈 제외 |
| 기본색 | 차콜 `#30363D`, 슬레이트 `#657482`, 아이보리 `#D8D2C8`, 절제된 청록 `#668B88` |
| 보조색 | 먼지 낀 황갈색 `#B3916C`, 올리브 `#687564`. 피부색은 팔레트에 억지로 끼워 맞추지 않음 |
| 인물 구별 | 얼굴형·헤어 덩어리·목선·안경 유무로 우선 구별. 의상색 하나에 의존하지 않음 |
| 회피할 것 | 전원 후드, 익명 가면, 네온 청록/자홍 역광, 공중 코드·해골·무기, 악역만 어둡게 칠하기 |
| UI 여백 | 정사각 가슴 위 초상, 머리 위 여백 약 8~12%, 눈높이 약 40~45%, 안전 영역 안에 머리·턱 |
| 텍스트 | 이미지에 이름·회사·로고·문구를 생성하지 않음. 번역 가능한 UI 텍스트로 별도 표시 |

장식 조명은 얼굴의 정체성을 가리지 않는다. 인물별 색은 분위기 보조이며 신뢰·배신·위험 판정 색이 아니다.
초상화의 감정은 대사를 보조하고, 정답 여부·숨은 범인·서버 경보 상태를 대신 알려주지 않는다.

## 4. 인물 외형 제안

아래 연령·성별 표현·외형은 제작 제안이다. 좌우 지시는 항상 **캐릭터 본인의 해부학적 좌우**를 기준으로 기록한다.

| ID·인물 | 제안 외형·실루엣 | 성격·담당 역할·고정 특징 |
|---|---|---|
| C01 서윤 | 30세 여성, 약간 넓은 타원형 얼굴, 자연스러운 중간 톤 피부. 턱선 길이의 짙은 흑갈색 단발, 오른쪽 귀 뒤로 넘김. 탁한 남색 오버셔츠+아이보리 티 | 짧고 구체적으로 말하며 불필요한 정보를 감춤. M01 인계 기록 회수 의뢰. 곧은 짙은 눈썹·둥글지 않은 단발 끝·단정한 목선 고정 |
| C02 도윤 | 34세 남성, 긴 타원형 얼굴, 짧고 약간 굽은 흑갈색 머리와 느슨한 가르마. 얇은 호박색 사각 안경, 올리브 니트+밝은 회색 셔츠 깃 | 차분하고 분석적이되 과잉 설명을 자제. 회수 자료 해석·다음 서버 맥락 제공. 안경 형태·긴 얼굴형·완만한 헤어 볼륨 고정 |
| C03 민서·제안명 | 41세 여성, 길고 각진 얼굴과 높은 광대, 짙은 머리를 낮게 묶음. 왼쪽 관자놀이의 소량 회색 머리, 갈색 직물 재킷+어두운 남색 상의 | 외부 제보자 후보. 말보다 원자료의 출처를 따지고 두 동료의 설명과 충돌하는 기록 제시. 낮은 묶음·관자놀이 회색 띠·긴 실루엣 고정 |
| C04 태경·제안명 | 46세 남성, 넓은 직사각 얼굴, 짧은 소금후추색 옆가르마, 옅은 눈가 주름. 안경 없음. 밝은 회갈색 재킷+짙은 청록 셔츠 | 상대 기관의 운영 책임자 후보. 절차·책임·현실 제약을 중시하며 단순 악역으로 단정하지 않음. 넓은 턱·짧은 가르마·차분한 정면성 고정 |

민서·태경은 새로운 확정 등장인물이 아니라 외형 대비와 역할 검토용 후보다. 역할을 기존 인물에 합치면 자산도 만들지 않는다.
네 사람의 표정 세트는 `neutral` 평상, `focused` 집중, `guarded` 경계, `relieved` 짧은 안도로 통일한다.
집중은 눈썹·시선의 작은 변화, 경계는 닫힌 입과 약간의 긴장, 안도는 눈가와 작은 미소로 표현한다. 전원 과장된 웃음·분노를 쓰지 않는다.
태경도 안도하고 서윤도 경계한다. 특정 표정을 도덕성이나 배신의 시각 코드로 고정하지 않는다.

### 익명성과 비밀 노출

서윤의 최초 메신저·메일에는 비인물 추상 아바타를 사용한다. 초상화 시트를 제작해도 M01에서 얼굴을 보여주는 근거가 되지 않는다.
얼굴 공개는 대본이 정한 공개 사건 이후에만 가능하며, 이전 세이브·연락처 검색·알림·인물 기록에서도 우회 노출되지 않아야 한다.
도윤·민서·태경도 해당 인물을 만났거나 사진을 발견한 맥락에서만 표시한다. 회색 실루엣만으로 미발견 인원수를 미리 알려주지 않는다.
제작용 시트·파일명·메타데이터에는 배신자·실제 소속·결말 등 미확정 반전을 넣지 않는다. 인물 ID와 버전만 사용한다.
초상화·의상에 기관 배지·이름표·특정 서비스 주소를 넣어 숨은 소속을 유출하지 않는다.

## 5. 예정 산출물과 파일 규격

다음은 목표 규격이며 이미지 도구의 지원 해상도나 출력 형식을 보증하지 않는다. 원본은 보존하고 지원되는 작업 방식에 맞춰 파생본을 만든다.

| 산출물 | 제안 규격·수량 | 종료 조건 |
|---|---|---|
| 인물별 master 시트 | 실제 채택 인물마다 정면·3/4·측면 흉상, 색 견본·고정 특징. 가능하면 2048px 이상 긴 변 | 인물 정체성·좌우·의상 일치. 텍스트 라벨·색표는 후편집 |
| source 초상화 | 인물별 중립 정사각 원본, 1024×1024 이상 목표 | 머리·턱 여백 확보, 생성 원본·편집본 구분 |
| 표정 | 인물별 총 4종 = 중립 1+편집 3; 전원 채택 시 16장 | 동일 인물·카메라·의상·빛 유지. 포즈가 달라진 새 초상으로 대체하지 않음 |
| UI 초상화 | 각 표정 128/256/512px RGBA PNG, 투명 배경 | 검정·밝은색·실제 OS 배경에서 테두리 번짐·불투명 배경 없음 |
| 익명 아바타 | C01용 원본 벡터/고해상도 도형, 128/256/512px PNG | 얼굴·성별·소속을 유추시키는 도상 없이 단순 비대칭 선형 표식 |
| 출처 기록 | 생성/편집 도구·날짜·실행 프롬프트·참조 자산·라이선스/제작자·해시 | 실존 인물·원작 자산 없음. 공개·상용 사용 조건 별도 확인 기록 |
| 색·폰트 기록 | 위 팔레트는 본 문서 제안. 시트/UI 폰트는 선정 후 이름·제작자·원본 URL·라이선스 기록 | 현재 폰트 파일 선정·다운로드 없음. 이미지 속 생성 글자를 제품 텍스트로 사용하지 않음 |
| 향후 3D 인물 | 실제 대면 장면이 반복되고 흉상으로 목표 감정을 전달할 수 없을 때 검토 | 정면·측면 시트, 모델링·리깅·표정·세 OS 성능 공수 검증 후 별도 범위 결정 |

레이어 원본은 실제 도구가 제공하면 보존한다. 제공하지 않는 PSD·분리 레이어·진짜 3D 모델을 있다고 기록하지 않는다.
UI 파생본의 권장 경로는 `godot/assets/art/portraits/`이며 현재 생성된 디렉터리나 자산이 아니다. 기본 원본은 배포 파일과 분리한다.
최종 투명 출력은 도구의 투명 배경 옵션도 함께 사용한다. 프롬프트에 적는 것만으로 실제 alpha가 생겼다고 간주하지 않는다.

## 6. 공통 그림체와 복사할 프롬프트

공통 그림체 블록은 새 인물을 제안할 때 사용한다. 아래 C01~C04는 이 기준을 포함한 독립 실행용 완성 프롬프트다.
생성 도구의 별도 negative prompt 칸을 가정하지 않는다. 제외 조건도 본문에 쓴다. 영어는 그림 생성용이며 제품 대사는 별도 한국어/번역 데이터다.

```text
Original semi-realistic editorial character illustration for a fictional late-night investigation game. Portray an adult with believable anatomy, restrained facial acting, matte fabric, simplified painted planes, and sparse soft linework. Use a soft neutral key light from the upper left of the image and subtle cool fill. Keep the eyes and face readable at small UI sizes. Favor charcoal, slate, muted teal, warm gray, and natural skin colors. Avoid cyberpunk neon, hacker costumes, famous faces, existing game characters, and imitation of any named artist. No text, branding, watermark, or narrative clues.
```

### C01 서윤 — 중립 정본 후보

```text
Create one original semi-realistic illustrated portrait of Seoyun, a fictional thirty-year-old Korean woman, for a late-night investigative PC game. She has a slightly broad oval face, natural medium-toned skin, straight dark eyebrows, and dark brown eyes. Her dark brown-black bob ends at the jaw, with clean blunt ends and the hair tucked behind her anatomical right ear. She wears a faded navy overshirt over a plain ivory crew-neck T-shirt. Her expression is composed and attentive, with closed lips and no smile; reserve should not read as villainy. Show a chest-up, almost frontal three-quarter view, both eyes visible, relaxed shoulders, no hands, and no props. Use matte painted planes, sparse soft outlines, a gentle neutral key light from the upper left of the image, and restrained cool fill. Keep her face bright and readable. Square composition, generous headroom, unclipped hair and chin, transparent background, crisp but natural silhouette. No hood, mask, glowing code, neon rim light, jewelry, company badges, lettering, logo, watermark, recognizable celebrity resemblance, or imitation of existing character art. This is a production portrait, not an identity reveal scene.
```

### C02 도윤 — 중립 정본 후보

```text
Create one original semi-realistic illustrated portrait of Doyun, a fictional thirty-four-year-old Korean man, for a late-night investigative PC game. Give him a long oval face, natural light-medium skin, dark brown eyes, and short softly wavy dark brown hair with a loose part and modest volume. His signature glasses are thin amber-brown rectangular frames, with clear lenses that never conceal his eyes. He wears a muted olive knit sweater over a light gray shirt with a small visible collar. He looks patient, thoughtful, and approachable without smiling broadly. His mouth is closed and his posture is relaxed. Show a chest-up, almost frontal three-quarter view, both eyes visible, no hands, and no objects. Render believable adult proportions with matte painted planes, sparse soft outlines, gentle neutral light from the upper left of the image, and subtle cool fill. Keep the face and glasses clear at avatar scale. Use a square composition with headroom, complete hair and chin, and a transparent background. No hacker hoodie, headset, neon lighting, lab coat, office branding, text, watermark, exaggerated genius stereotypes, celebrity resemblance, or imitation of existing game artwork.
```

### C03 민서 — 추가 인물 후보

```text
Create one original semi-realistic illustrated portrait of Minseo, a proposed fictional forty-one-year-old Korean woman, for a late-night investigative PC game. She has an elongated angular face, defined cheekbones, dark brown eyes, and natural medium skin with subtle adult texture. Her dark hair is swept back into a compact low bun, with a small visible streak of gray at her anatomical left temple. She wears a practical warm brown fabric jacket over a plain dark navy top. Her neutral expression is observant and measured, with closed lips, level eyes, and no theatrical suspicion. She should feel like someone who checks facts carefully, not a stock spy. Show a chest-up, almost frontal three-quarter view, both eyes visible, relaxed shoulders, no hands, and no props. Use matte painted planes, restrained brush texture, sparse soft edges, neutral soft light from the upper left of the image, and mild cool fill. Keep her silhouette and face distinct at small UI sizes. Square framing, generous headroom, full chin, transparent background. No trench coat, sunglasses, scars, dramatic shadows, organization badges, lettering, watermark, neon, celebrity resemblance, or imitation of existing character art. Do not suggest a secret allegiance.
```

### C04 태경 — 추가 인물 후보

```text
Create one original semi-realistic illustrated portrait of Taegyeong, a proposed fictional forty-six-year-old Korean man, for a late-night investigative PC game. He has a broad rectangular face, a substantial but natural jaw, dark brown eyes, light-medium skin, and understated lines around the eyes. His short salt-and-pepper hair has a neat side part. He has no glasses and no facial hair. Dress him in an unbranded light warm-gray jacket over a plain deep muted teal shirt, with no tie or visible insignia. His neutral expression is calm, responsible, and slightly tired, with closed lips and attentive eyes. Avoid making an institutional contact look automatically threatening or corrupt. Show a chest-up, almost frontal three-quarter view, both eyes visible, relaxed shoulders, no hands, and no props. Use believable adult proportions, simplified matte painted planes, sparse soft outlines, neutral soft key light from the upper left of the image, and gentle cool fill. Square composition, sufficient headroom, intact hair and chin, transparent background, readable silhouette. No military styling, villain grin, dramatic underlighting, neon, badges, text, watermark, celebrity resemblance, or imitation of existing artwork.
```

### 표정 수정 — 선택된 정본 이미지가 있을 때만

```text
Edit only the supplied canonical portrait of [CHARACTER_ID]. Preserve the exact identity, apparent age, face proportions, skin tone, hair silhouette and anatomical side details, glasses if present, clothing, camera angle, crop, lighting, palette, and transparent background. Change only the facial expression to [EXPRESSION_DIRECTION]. Keep both eyes readable and the acting subtle enough for a small messenger avatar. Do not add props, hands, tears, text, badges, a new background, or a new hairstyle. Do not mirror the image. Keep all original transparency and edge quality. Return one edited portrait, not a contact sheet or a redesigned character.
```

표정 치환문: `focused` = “quiet concentration, slightly engaged eyebrows and steady eyes, lips relaxed and closed”.
`guarded` = “mild caution, a small tightening around the eyes and closed lips, no anger or sinister smile”.
`relieved` = “subtle relief, softened eyes and a small closed-mouth smile, no laughter or exaggerated joy”.
`neutral`은 선택한 정본을 그대로 사용한다. 표정별로 새 텍스트 생성부터 반복하지 않는다.

### master 시트 — 정본 선택 이후의 별도 작업

```text
Using the supplied canonical portrait as the sole identity reference, create a clean production character sheet for [CHARACTER_ID]. Show matched front, three-quarter, and profile chest-up views of the same adult, with identical facial proportions, anatomical side details, hair, age, clothing, and color palette. Use neutral expression and even soft studio lighting so construction is clear. Keep all views separated with generous space on a plain neutral background. No full-body design, new accessories, narrative props, extra characters, handwritten labels, branding, or text. Preserve identity rather than inventing attractive variations.
```

현재 참조 이미지는 **없다**. 첫 생성에서 존재하지 않는 정본 파일을 참조했다고 쓰지 않는다. 캐릭터 시트의 여러 뷰도 자동으로 일치한다고 가정하지 않는다.
실제 후보를 고른 뒤 해당 인물의 정본만 도구의 참조 이미지 입력에 연결하고, 파일 ID와 해시를 기록한다. 다른 인물 초상이나 원작 이미지는 섞지 않는다.
그림체 참조가 필요하면 채택된 자체 작업물로 만든 비인물 색·붓결 견본을 사용한다. 여러 얼굴을 한 번에 참조해 정체성이 섞이지 않게 한다.

## 7. 생성·선택·고정·검수 순서

1. 실제 등장 우선순위와 얼굴 공개 조건을 대본에서 확인한다. P1은 익명 아바타로 진행 가능하다.
2. 최초로 필요한 한 인물의 중립 후보를 소수 생성한다. 초기 예산 제안은 후보 3개이며 무한 재생성하지 않는다.
3. 외형표·공통 그림체·128px 가독성과 대사 분위기를 비교해 제작용 한 후보를 고른다. 사용자 검토 결과와 제작자 선택을 구분한다.
4. 고른 중립 초상을 `canon candidate`로 지정하고 master 시트의 정면·측면 정합성을 확인한다. 불일치 시 정본을 기준으로 수정한다.
5. 채택 근거·기준 버전·고정 특징·참조 해시를 기록해 `canon`을 고정한다. 사용자 승인 여부는 별도 필드이며 자동 승인으로 쓰지 않는다.
6. 정본을 참조해 집중·경계·안도만 편집하고 중립 포함 4종을 검수한다. 배역이 빠지면 세트도 제작하지 않는다.
7. alpha PNG 파생본을 만들고 512/256/128px 및 실제 UI의 더 작은 표시에서 확인한다. 자동 축소 성공만으로 가독성 PASS를 주지 않는다.
8. 실제 OS 배경·원형/사각 크롭·고대비·회색조·ko/en 이름 배치에서 검수한다. 얼굴은 번역 텍스트를 이미지에 포함하지 않는다.
9. 사건별 초상화/익명 아바타 공개와 감정 선택을 플레이 흐름·저장/재개에서 확인한다. 이미지 검수와 게임 연결 검증을 별도로 기록한다.

## 8. 버전·변경 허용 범위

예정 파일 ID는 `pt_c01_neutral_front_v001_source.png`, `pt_c01_focused_front_v001_ui256.png` 형식이다.
시트는 `pt_c01_sheet_v001.png`, 익명 아바타는 `pt_c01_anon_v001_ui128.png`로 구분한다. 파일명에 최종 반전이나 실명을 넣지 않는다.
작업 기록 필드: `character_id`, `asset_id`, `status`, `canon_version`, `parent_asset`, `reference_sha256`, `prompt_revision`, `actual_tool_model`, `approval_source`, `checks`.
`status`는 `draft/candidate/canon/retired`로 관리하고, 승인 전 후보도 실제 UI 시험에 쓸 수 있으나 출시 정본으로 오인하지 않게 한다.
기존 원본·프롬프트·선택 근거는 보존한다. 잘못된 얼굴을 파일명만 유지한 채 덮어쓰지 않는다.
파생본은 크기·크롭 여백·색 관리·alpha 가장자리 수정이 가능하다. 얼굴형·연령·헤어·고정 특징·안경 형태 변경은 정본 새 버전이다.
표정 편집은 눈썹·눈가·입 주변만 허용한다. 조명·의상·카메라가 크게 바뀌면 별도 연출 초상으로 분류하며 기본 4종 수에 끼워 넣지 않는다.

## 9. 수용 기준과 실행 모델

- 네 인물 후보는 이름·의상색을 숨겨도 헤어·얼굴형·안경으로 구별된다. 특히 128px에서 C01/C03, C02/C04가 혼동되지 않는다.
- 같은 인물의 4표정에서 나이·턱·코·눈 간격·좌우 특징·의상이 유지되고, 입·눈·안경·귀의 생성 오류가 없다.
- 머리·턱이 잘리지 않고 얼굴이 너무 작지 않다. alpha 가장자리에 검정/흰색 테두리·구멍·불투명 체크무늬가 없다.
- 집중·경계·안도의 의미가 저채도 화면에서도 보인다. 구분이 애매하면 UI 텍스트·대사를 보완하며 과장된 표정을 강요하지 않는다.
- 얼굴 공개 전 C01은 이름·대사·허용된 익명 표식만 보인다. 초상화가 기술 정답·배신·미발견 소속을 노출하지 않는다.
- 원본·참조·프롬프트·권리 출처·실제 도구 기록이 있고, 선택한 인물의 모든 파생본이 같은 정본 버전을 가리킨다.
- 위 항목은 현재 **검증 예정**이다. 새 이미지가 없으므로 일관성·alpha·가독성·실제 UI 검수를 PASS로 기록하지 않는다.

텍스트·외형·프롬프트 설계 권고 및 이번 작성 모델은 `gpt-6.1-sol / high`다. 독립 시각 판단은 `gpt-6.1-sol / xhigh`를 권고하되 아직 실행하지 않았다.
실제 이미지 생성 도구의 모델 ID·추론 effort 선택이 노출되지 않으면 `actual_tool_model=not_exposed`, `effort=not_exposed`로 기록한다.
`xhigh`는 텍스트/시각 검토 모델의 추론 수준이지 이미지 해상도·생성 품질 옵션이 아니다. 실제 이미지 도구 옵션은 그때 노출된 값만 기록한다.
상업 API 가격·계약·지원 해상도는 이 문서에서 보증하지 않는다. 이 문서 작성(A12)에는 이미지·음악 생성 호출이 없었다.

설계초안완료, 실제 생성/일관성/가독성 검수는 후속.
