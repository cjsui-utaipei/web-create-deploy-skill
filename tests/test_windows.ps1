param([string]$OutputPath = '', [string]$DivergenceOwner = '', [string]$DivergenceRepo = '')
$ErrorActionPreference='Stop'
if($PSVersionTable.PSVersion.Major -ne 5){throw 'Run with Windows PowerShell 5.1'}
$publisher=(Resolve-Path "$PSScriptRoot/../github-pages-beginner/scripts/publish.ps1").Path
$base=Join-Path $env:TEMP ('pages-windows-tests-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $base
$utf8=New-Object Text.UTF8Encoding($false)
$fake='workshop_test_credential_0123456789'
$results=New-Object Collections.Generic.List[object]
function Put($path,$value){[IO.File]::WriteAllText($path,$value,$utf8)}
function Case($name,$expected,$setup,[string]$mock='',[switch]$Live,[switch]$AllowFetch){
 $caseRoot=Join-Path $base $name
 $workspace=Join-Path $caseRoot 'web-create-deploy'
 $site=Join-Path $workspace '中文 My Website'
 $null=New-Item -ItemType Directory -Path $site -Force
 Put (Join-Path $site 'index.html') '<h1>Windows test</h1>'
 Put (Join-Path $workspace 'github_pat.txt') $fake
 & $setup $site $workspace
 $target=$site;if($name -eq 'workspace-root'){$target=$workspace}
 $wrapper=Join-Path $caseRoot 'invoke.ps1'
 $prefix=@'
param($Publisher,$Project)
function Invoke-WebRequest { throw 'Unexpected network access' }
'@
 if($mock){$prefix=$mock}
 Put $wrapper ($prefix+"`r`n& `$Publisher -ProjectDir `$Project "+$(if(!$Live){'-DryRun'}else{'-WaitSeconds 0'})+"`r`nexit `$LASTEXITCODE")
 $before=@(Get-ChildItem -LiteralPath $workspace -Recurse -Force -File | Where-Object { !$AllowFetch -or $_.FullName -notmatch '[\\/]\.git[\\/]' } | ForEach-Object { $_.FullName+':'+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
 if($AllowFetch){$beforeHead=(& git -C $site rev-parse HEAD)}
 $raw=(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wrapper $publisher $target 2>&1 | Out-String)
 $exit=$LASTEXITCODE
 $after=@(Get-ChildItem -LiteralPath $workspace -Recurse -Force -File | Where-Object { !$AllowFetch -or $_.FullName -notmatch '[\\/]\.git[\\/]' } | ForEach-Object { $_.FullName+':'+(Get-FileHash -LiteralPath $_.FullName).Hash }) -join "`n"
 try{$r=$raw|ConvertFrom-Json;$actual=if($r.ok){'OK'}else{$r.code}}catch{$actual='NON_JSON'}
 $pass=($actual -eq $expected -and !$raw.Contains($fake) -and $before -eq $after -and $exit -eq $(if($expected -eq 'OK'){0}else{1}))
 if($AllowFetch){$pass=$pass -and ($beforeHead -eq (& git -C $site rev-parse HEAD))}
 $results.Add([pscustomobject]@{test=$name;status=$(if($pass){'PASS'}else{'FAIL'});expected=$expected;actual=$actual;exit=$exit;unchanged=($before -eq $after)})
}
function Init($site){
 & git -C $site init -q -b main
 & git -C $site -c user.name=Test -c user.email=test@example.invalid add index.html
 & git -C $site -c user.name=Test -c user.email=test@example.invalid commit -qm Initial
}
Case 'dry-unicode-space' 'OK' {}
Case 'bom-crlf' 'OK' {param($s,$w) [IO.File]::WriteAllText((Join-Path $w 'github_pat.txt'),"$fake`r`n",(New-Object Text.UTF8Encoding($true)))}
Case 'workspace-root' 'WORKSPACE_LAYOUT' {}
Case 'token-inside-site' 'TOKEN_INSIDE_SITE' {param($s,$w) Put (Join-Path $s 'github_pat.txt') $fake}
Case 'missing-token' 'TOKEN_MISSING' {param($s,$w) Remove-Item -LiteralPath (Join-Path $w 'github_pat.txt')}
Case 'empty-token' 'TOKEN_EMPTY' {param($s,$w) Put (Join-Path $w 'github_pat.txt') ''}
Case 'invalid-token-syntax' 'TOKEN_INVALID' {param($s,$w) Put (Join-Path $w 'github_pat.txt') 'invalid!'}
Case 'missing-index' 'SITE_ENTRY_MISSING' {param($s,$w) Remove-Item -LiteralPath (Join-Path $s 'index.html')}
Case 'staged-changes' 'STAGED_CHANGES' {param($s,$w) Init $s;Put (Join-Path $s 'index.html') '<h1>Changed</h1>'; & git -C $s add index.html}
foreach($ext in @('.env','secret.pem','secret.key')){
 $secretName=$ext
 Case ('history-'+$ext.Replace('.','')) 'SECRET_IN_HISTORY' {param($s,$w)
  Init $s;$folder=Join-Path $s '中文目錄';$null=New-Item -ItemType Directory $folder
  Put (Join-Path $folder $secretName) 'unrelated secret fixture'
  & git -C $s add .
  & git -C $s -c user.name=Test -c user.email=test@example.invalid commit -qm SecretFixture
 }
}
$network=@'
param($Publisher,$Project)
function Invoke-WebRequest { throw [Net.WebException]::new('Simulated transport failure') }
'@
Case 'network-error-mock' 'NETWORK_ERROR' {} $network -Live
$unauthorized=@'
param($Publisher,$Project)
function Invoke-WebRequest {
 $e=New-Object Exception 'Simulated HTTP failure'
 $e|Add-Member NoteProperty Response ([pscustomobject]@{StatusCode=401;Headers=@{}})
 throw $e
}
'@
Case 'invalid-token-http-mock' 'TOKEN_INVALID' {} $unauthorized -Live
$missingGit=@'
param($Publisher,$Project)
function Get-Command { param($Name,$ErrorAction) if($Name -eq 'git.exe'){return $null};Microsoft.PowerShell.Core\Get-Command $Name }
function Test-Path { param($LiteralPath) if($LiteralPath -like '*git.exe'){return $false};Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath }
'@
Case 'missing-git-mock' 'GIT_MISSING' {} $missingGit
$userMock=@'
param($Publisher,$Project)
function Invoke-WebRequest { [pscustomobject]@{StatusCode=200;Content='{"login":"student","id":123}'} }
'@
Case 'unmanaged-remote' 'UNMANAGED_REMOTE' {param($s,$w) Init $s;& git -C $s remote add origin https://github.com/example/unmanaged.git} $userMock -Live
foreach($ext in @('.env','secret.pem','secret.key')){
 $secretName=$ext
 Case ('newline-history-'+$ext.Replace('.','')) 'SECRET_IN_HISTORY' {param($s,$w)
  Init $s
  $blob=('unrelated secret fixture' | git -C $s hash-object -w --stdin).Trim()
  # Build a subtree because slash is not valid in a single tree entry.
  $sub=("100644 blob $blob`t$secretName" | git -C $s mktree).Trim()
  $tree=("040000 tree $sub`t"+'"line\nbreak"' | git -C $s mktree).Trim()
  $commit=('Fixture' | git -C $s -c user.name=Test -c user.email=test@example.invalid commit-tree $tree).Trim()
  & git -C $s update-ref refs/heads/newline-fixture $commit
 }
}
if($DivergenceOwner -and $DivergenceRepo){
 if($DivergenceOwner -notmatch '^[a-zA-Z0-9-]+$' -or $DivergenceRepo -notmatch '^[a-zA-Z0-9_-]+$'){throw 'Expected explicit public demo repository'}
 $divergeMock=@'
param($Publisher,$Project)
function Invoke-WebRequest { param($Uri)
 if($Uri -eq 'https://api.github.com/user'){return [pscustomobject]@{StatusCode=200;Content='{"login":"OWNER","id":123}'}}
 return [pscustomobject]@{StatusCode=200;Content='{"private":false}'}
}
'@
 $divergeMock=$divergeMock.Replace('OWNER',$DivergenceOwner)
 Case 'remote-diverged-public-read-only' 'REMOTE_DIVERGED' {param($s,$w)
  Init $s
  & git -C $s remote add origin "https://github.com/$DivergenceOwner/$DivergenceRepo.git"
  Put (Join-Path $s '.git/pages-beginner-state') "$DivergenceOwner $DivergenceRepo"
 } $divergeMock -Live -AllowFetch
}
$results | Format-Table -AutoSize
if($OutputPath){$results|ConvertTo-Json -Depth 4|Set-Content -LiteralPath $OutputPath -Encoding UTF8}
Write-Output ('Temporary isolated fixtures retained: '+$base)
if(@($results|Where-Object status -eq FAIL).Count){exit 1}
