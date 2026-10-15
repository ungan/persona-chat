# 구성 출처

공개판은 새 AI 생성 캐릭터 3종을 포함합니다. 사용 조건은 ASSETS.md를 참고하세요.

- 대화 흐름과 페르소나 단계: 사용자의 LostMemory 프로젝트의 `FriendChatPanelView`, `LlmApiClient`, `LlmPersonaDemoWindow`, `LocalLlmDemoApplication`을 참고해 독립 구조로 재구성. 원본 프로젝트는 변경하지 않았습니다.
- Gradle Wrapper: 기존 서버의 Gradle 8.14.4 Wrapper 복사. Gradle은 Apache License 2.0을 사용합니다.
- 서버 의존성: Spring Boot/Spring Framework, Jackson, 내장 Tomcat 등은 Gradle로 내려받습니다. 각 라이브러리 JAR에 포함된 LICENSE/NOTICE를 유지합니다.
- Java: Eclipse Temurin OpenJDK 17을 사용하는 경우 GPLv2 + Classpath Exception. 휴대용 런타임의 `legal` 폴더를 함께 보존합니다. `Build-Runtime.ps1`은 설치된 JDK의 jlink로 구성합니다.
- Unity 엔진과 UGUI: Unity 설치 및 빌드 구성에 포함되는 구성 요소로 해당 라이선스·배포 조건을 따릅니다.
- 공개 캐릭터: 내장 이미지 생성 도구로 만든 밤색 단발·초록 망토의 캐릭터 3종입니다. 기존 유나 이미지와 별도 디자인이며 프로젝트 제공자가 자유로운 재사용을 허용했습니다. 상세 범위는 ASSETS.md에 있습니다.
- TopDown Engine, 타사 게임 에셋, 기존 프로젝트 폰트 파일은 복사하지 않았습니다. UI는 실행 PC에 설치된 글꼴을 사용합니다.

이 공개 예제의 자체 코드와 문서는 루트 LICENSE의 MIT 조건을 따릅니다. 기존 LostMemory 프로젝트 전체에 새 라이선스를 부여하는 것은 아닙니다. 위 외부 구성 요소에는 각각의 라이선스와 고지가 계속 적용되며, 공개 이미지에는 ASSETS.md의 사용 허락이 적용됩니다.
