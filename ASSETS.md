# 공개용 이미지 안내

## 자유로운 재사용 허용

이 공개판에는 AI 이미지 생성 도구로 제작한 별도 디자인의 캐릭터 이미지 3종을 포함합니다.

- `character/portraits/example-neutral.png`: 평상시
- `character/portraits/example-happy.png`: 기쁨
- `character/portraits/example-sad.png`: 걱정·슬픔

프로젝트 제공자는 위 이미지 3종에 대해 허락할 수 있는 범위에서 누구나 무료로 사용·복사·수정·재배포할 수 있도록 허용합니다. 개인·교육·상업 목적, 다른 프로젝트에서의 이용, 이미지 단독 재배포도 허용하며 출처 표기는 필수가 아닙니다. AI 생성 이미지라는 제작 경위를 공개합니다.

이 허락은 위 3개 PNG에만 적용됩니다. 코드, Unity 엔진, Java 런타임과 외부 라이브러리의 조건은 별개입니다. 기존 유나 이미지·서재 배경·이전 시연 영상은 이 공개판에 포함하지 않으며 이 허락의 대상이 아닙니다.

## 이미지 교체

이미지는 외부 파일이므로 재빌드 없이 교체할 수 있습니다. 사용 권한이 있는 PNG/JPG를 `character/portraits/`에 놓고 `character/character.json`을 수정합니다. 경로는 `character` 폴더 기준입니다.

```json
{
  "displayName": "유나",
  "playerName": "나",
  "neutral": { "path": "portraits/example-neutral.png", "columns": 1, "index": 0 },
  "happy": { "path": "portraits/example-happy.png", "columns": 1, "index": 0 },
  "sad": { "path": "portraits/example-sad.png", "columns": 1, "index": 0 }
}
```

이미지당 16MB 이하로 사용합니다. 개별 이미지는 `columns: 1, index: 0`이며 가로 아틀라스는 칸 수와 0부터 시작하는 칸 번호를 지정합니다. 정면 얼굴의 위치·크기와 캔버스 비율을 맞추면 전환이 자연스럽습니다. 앱을 다시 실행하거나 Unity의 Persona Chat → Refresh Character Preview를 선택합니다.

공개판의 배경은 단색입니다. 원한다면 사용 권한이 있는 배경을 직접 연결할 수 있습니다. 패키징은 기본 공개 캐릭터 3종만 허용 목록으로 복사하며, 사용자 추가 이미지를 배포하려면 스크립트의 공개 파일 목록과 이 문서를 함께 갱신해야 합니다.
