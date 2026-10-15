. (Join-Path $PSScriptRoot 'Common.ps1')
function Check([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$source = Get-Content -LiteralPath (Join-Path $ProjectRoot 'client\Assets\PersonaChat\Runtime\Conversation.cs') -Raw -Encoding UTF8
if (-not ('PersonaChat.Conversation' -as [type])) { Add-Type -TypeDefinition $source }
$chat = New-Object PersonaChat.Conversation
for ($i=0; $i -lt 12; $i++) { [void]$chat.Complete($chat.Version, "question-$i", "answer-$i") }
Check ($chat.Count -eq 20) 'History should retain 10 complete turns.'
$request = $chat.ForRequest('current-question')
Check ($request.Count -eq 21 -and $request[0].content -eq 'question-2') 'History trim lost turn ordering.'
$oldVersion = $chat.Version
$chat.Reset(1)
Check (-not $chat.Complete($oldVersion, 'stale', 'late-response')) 'An old response survived reset.'
Check ($chat.Count -eq 0 -and $chat.Stage -eq 1) 'Reset did not clear history or switch persona.'
Check ($chat.ForRequest('new').Length -eq 1) 'New conversation contains old messages.'
$temp = Join-Path ([IO.Path]::GetTempPath()) ('persona-chat-env-test-'+[Guid]::NewGuid().ToString('N')+'.txt')
try {
    @('LLM_API_KEY=''test-key-$(not-executed)#literal''', 'LLM_MODEL="test-model"', 'CHAT_PORT=18082') | Set-Content -LiteralPath $temp -Encoding UTF8
    $data = Read-ChatEnv -Path $temp
    Check ($data.LLM_API_KEY -eq 'test-key-$(not-executed)#literal') '.env parser interpreted literal content.'
    Check ($data.LLM_MODEL -eq 'test-model') '.env quoting failed.'
    @('LLM_API_KEY=test-key', 'CHAT_PORT=0') | Set-Content -LiteralPath $temp -Encoding UTF8
    $rejected = $false
    try { Read-ChatEnv -Path $temp | Out-Null } catch { $rejected = $true }
    Check $rejected 'Invalid port should be rejected.'
} finally { Remove-Item -LiteralPath $temp }
Write-Host 'PASS: history trimming, reset, stale response guard, .env literals, quoting, and port validation.'
