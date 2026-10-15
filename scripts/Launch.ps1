# UTF-8 BOM is required for Korean messages in Windows PowerShell 5.1.
. (Join-Path $PSScriptRoot 'Common.ps1')
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
Write-Host 'Persona Chat — 채팅 시작' -ForegroundColor Cyan
Write-Host ''
$envPath = Join-Path $ProjectRoot '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    Copy-Item -LiteralPath (Join-Path $ProjectRoot '.env.example') -Destination $envPath
}
try {
    $null = Read-ChatEnv -Path $envPath
} catch {
    Write-Host '설정을 확인해 주세요. 서버와 앱은 실행하지 않았습니다.' -ForegroundColor Yellow
    Write-Host ('1. 메모장으로 이 파일을 여세요: ' + $envPath)
    Write-Host '2. LLM_API_KEY= 뒤에 본인의 API 키를 입력하세요.'
    Write-Host '3. LLM_MODEL=gpt-4.1-mini 처럼 모델 이름을 입력하세요.'
    Write-Host '4. 저장한 뒤 채팅 시작.cmd를 다시 실행하세요.'
    Write-Host '키를 이미 입력했다면 .env의 항목 이름, 모델 이름, CHAT_PORT(1024~65535)를 확인하세요.'
    Write-Host 'API 키는 채팅에 보내지 마세요. 사용 방법은 README.md에 있습니다.'
    exit 2
}
try {
    Write-Host '서버를 준비하고 있습니다. 준비가 끝나면 채팅 창이 열립니다.'
    & (Join-Path $PSScriptRoot 'Start.ps1')
    Write-Host '채팅과 서버를 종료했습니다.'
    exit 0
} catch {
    $reason = $_.Exception.Message
    if ($reason -eq 'CHAT_ALREADY_RUNNING') {
        Write-Host '채팅이 이미 실행 중이거나 시작 중입니다. 기존 채팅 창을 사용해 주세요.' -ForegroundColor Yellow
        Write-Host '새 서버나 채팅 창은 추가로 열지 않았습니다.'
    } elseif ($reason -like '*project server is already running*') {
        Write-Host '이 폴더의 서버가 이미 실행 중입니다.' -ForegroundColor Yellow
        Write-Host 'Unity 에디터에서 사용 중이면 그대로 이용하세요.'
        Write-Host '독립 앱을 열려면 Stop.cmd로 서버를 종료한 뒤 채팅 시작.cmd를 다시 실행하세요.'
    } elseif ($reason -like '*CHAT_PORT is already in use*') {
        Write-Host '다른 앱이 같은 포트를 사용 중입니다. 다른 Persona Chat을 종료하거나 .env의 CHAT_PORT를 변경하세요.' -ForegroundColor Yellow
    } elseif ($reason -like '*Unity client is not built*') {
        Write-Host 'Windows 실행 파일이 없습니다. 배포 ZIP 전체를 풀었는지 확인하세요.' -ForegroundColor Yellow
        Write-Host '소스 프로젝트라면 README.md의 Windows 빌드 방법을 먼저 진행하세요.'
    } else {
        Write-Host '실행하지 못했습니다. ZIP 전체를 쓰기 가능한 폴더에 풀었는지 확인하세요.' -ForegroundColor Yellow
        Write-Host 'README.md의 오류 해결과 .run/server.log를 확인하세요. 이 안내에는 키를 표시하지 않습니다.'
    }
    exit 1
}
