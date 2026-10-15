# 다운로드 횟수 확인

## README 배지

저장소 맨 위의 `Release downloads` 배지는 모든 Release 첨부 파일의 누적 다운로드 횟수입니다. Shields.io가 GitHub 데이터를 가져오며 캐시 때문에 즉시 갱신되지 않을 수 있습니다.

## Windows ZIP별 조회

PowerShell에서 프로젝트 루트로 이동한 뒤 실행합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Get-DownloadStats.ps1
```

버전·파일별 횟수, Windows ZIP 합계, 모든 Release 첨부 파일 합계가 표시됩니다. 공개 저장소라 로그인이나 API 키는 필요하지 않습니다. 비인증 GitHub API 요청 한도를 초과하면 잠시 후 다시 실행하세요.

JSON으로 저장하려면 다음 명령을 사용할 수 있습니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Get-DownloadStats.ps1 -AsJson | Set-Content downloads.json -Encoding utf8
```

## 무엇을 세나요?

- GitHub Release에 첨부한 파일의 `download_count`를 조회합니다.
- 재다운로드, 자동화 도구, 게시 후 다운로드 검증도 포함될 수 있습니다.
- 고유 사용자 수, 설치 수, 앱 실행 수, API 이용 수가 아닙니다.
- Git clone, Code → Download ZIP, GitHub가 자동 제공하는 Source code 압축파일은 이 Release 자산 집계에 포함되지 않습니다.
- 코드에는 사용자 추적이나 원격 사용량 수집 기능을 추가하지 않았습니다.
- 기존 Release 파일을 지우고 다시 올리면 기존 자산의 집계가 이어지지 않으므로 새 버전을 별도 Release로 게시하는 방식을 권장합니다.

## 직접 확인할 API

https://api.github.com/repos/ungan/persona-chat/releases

각 Release의 `assets` 안에 있는 `name`, `download_count`를 확인합니다.

[GitHub 공식 Release 자산 문서](https://docs.github.com/en/rest/releases/assets) · [Shields 다운로드 배지](https://shields.io/badges/git-hub-downloads-all-assets-all-releases)
