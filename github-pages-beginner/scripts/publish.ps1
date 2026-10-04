param([string]$ProjectDir='.', [string]$RepoName='', [switch]$DryRun, [int]$WaitSeconds=90)
# Windows PowerShell 5.1. Never persist execution-policy or global Git changes.
$ErrorActionPreference='Stop'
Set-PSDebug -Off
$TempPath=$null
function Stop-Publish([string]$Code) { throw [System.Exception]::new($Code) }
function Git-Raw([string[]]$Arguments) {
 # Windows PowerShell 5.1 wraps native stderr in ErrorRecord even on exit 0.
 $savedPreference=$ErrorActionPreference
 try {
  $ErrorActionPreference='Continue'
  $lines=& $script:GitExe @Arguments 2>$null
  $script:GitExit=$LASTEXITCODE
  return ($lines -join "`n")
 } finally { $ErrorActionPreference=$savedPreference }
}
function Git-Run([string[]]$Arguments) {
 $result=Git-Raw $Arguments
 if ($script:GitExit -ne 0) { Stop-Publish 'GIT_OPERATION_FAILED' }
 return $result
}
function Api([string]$Method,[string]$Endpoint,$Payload=$null) {
 $opts=@{Uri="https://api.github.com$Endpoint";Method=$Method;Headers=$script:Headers;UseBasicParsing=$true;TimeoutSec=40;MaximumRedirection=0}
 if ($null -ne $Payload) { $opts.Body=($Payload|ConvertTo-Json -Depth 8 -Compress);$opts.ContentType='application/json' }
 try { $r=Invoke-WebRequest @opts; $script:Status=[int]$r.StatusCode; $script:Body=if($r.Content){$r.Content|ConvertFrom-Json}else{$null} }
 catch {
  $response=$_.Exception.Response
  if ($null -eq $response) { Stop-Publish 'NETWORK_ERROR' }
  $script:Status=[int]$response.StatusCode; $script:Body=$null
  if ($script:Status -eq 401) { Stop-Publish 'TOKEN_INVALID' }
  if ($script:Status -eq 403 -or $script:Status -eq 429) {
   if ($response.Headers['X-RateLimit-Remaining'] -eq '0' -or $response.Headers['Retry-After'] -or $_.ErrorDetails.Message -match 'rate.limit|abuse') {Stop-Publish 'RATE_LIMITED'}
   Stop-Publish 'TOKEN_PERMISSION'
  }
 }
}
function Secret-Path([string]$p) { return $p -match '(?i)(^|/)(github_pat[^/]*|\.env($|\.)|[^/]*\.(pem|key)$)' }
try {
 $cmd=Get-Command git.exe -ErrorAction SilentlyContinue
 if($cmd){$script:GitExe=$cmd.Source}else{
  $script:GitExe=@("$env:ProgramFiles\Git\cmd\git.exe","${env:ProgramFiles(x86)}\Git\cmd\git.exe","$env:LOCALAPPDATA\Programs\Git\cmd\git.exe")|Where-Object{Test-Path -LiteralPath $_}|Select-Object -First 1
 }
 if(!$script:GitExe){Stop-Publish 'GIT_MISSING'}
 $null=Git-Run @('--version')
 Set-Location -LiteralPath $ProjectDir
 $ProjectDir=(Get-Location).Path
 $workspace=Split-Path -Parent $ProjectDir
 if((Split-Path -Leaf $workspace) -ne 'web-create-deploy' -or (Split-Path -Leaf $ProjectDir) -eq 'web-create-deploy'){Stop-Publish 'WORKSPACE_LAYOUT'}
 if(Test-Path -LiteralPath (Join-Path $ProjectDir 'github_pat.txt')){Stop-Publish 'TOKEN_INSIDE_SITE'}
 if((Get-Item -LiteralPath $ProjectDir).Attributes -band [IO.FileAttributes]::ReparsePoint){Stop-Publish 'SYMLINK_UNSUPPORTED'}
 $tokenPath=Join-Path $workspace 'github_pat.txt' 
 if(!(Test-Path -LiteralPath $tokenPath -PathType Leaf)){Stop-Publish 'TOKEN_MISSING'}
 if((Get-Item -LiteralPath $tokenPath).Attributes -band [IO.FileAttributes]::ReparsePoint){Stop-Publish 'TOKEN_FILE_UNSAFE'}
 $Token=[IO.File]::ReadAllText($tokenPath).Trim([char]0xFEFF).Trim() -replace '[\r\n]',''
 if(!$Token){Stop-Publish 'TOKEN_EMPTY'}
 if($Token -notmatch '^[a-zA-Z0-9_]+$'){Stop-Publish 'TOKEN_INVALID'}
 if(!(Test-Path -LiteralPath 'index.html' -PathType Leaf)){Stop-Publish 'SITE_ENTRY_MISSING'}
 if(!$RepoName){$RepoName=([IO.Path]::GetFileName($ProjectDir).ToLowerInvariant() -replace '[ _]','-' -replace '[^a-z0-9-]','' -replace '-+','-').Trim('-')}
 if(!$RepoName){$RepoName='my-webpage'}
 if($RepoName -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]{0,79}$'){Stop-Publish 'REPO_NAME_INVALID'}
 $root=Git-Raw @('rev-parse','--show-toplevel')
 if($script:GitExit -eq 0){
  if([IO.Path]::GetFullPath($root) -ne $ProjectDir -or !(Test-Path .git -PathType Container)){Stop-Publish 'REPO_CONFLICT'}
  if((Git-Run @('symbolic-ref','--short','HEAD')) -ne 'main'){Stop-Publish 'REPO_CONFLICT'}
  if(Git-Run @('diff','--cached','--name-only')){Stop-Publish 'STAGED_CHANGES'}
  $history=Git-Raw @('log','--all','--format=','--name-only','-z')
  foreach($p in ($history -split "`0")){if(Secret-Path $p){Stop-Publish 'SECRET_IN_HISTORY'}}
  if((Git-Run @('config','--local','--list')).Contains($Token)){Stop-Publish 'TOKEN_IN_CONFIG'}
  foreach($rev in ((Git-Run @('rev-list','--all')) -split "`n")){
   if($rev){foreach($blob in ((Git-Run @('ls-tree','-r','--format=%(objectname)',$rev)) -split "`n")){ if($blob -and (Git-Run @('cat-file','blob',$blob)).Contains($Token)){Stop-Publish 'SECRET_IN_HISTORY'} }}
  }
 }
 # Iterative traversal avoids following directory junctions outside the project.
 $stack=New-Object 'System.Collections.Generic.Stack[string]';$stack.Push($ProjectDir)
 while($stack.Count){
  foreach($item in Get-ChildItem -LiteralPath $stack.Pop() -Force){
   if($item.Name -eq '.git'){continue}
   if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){Stop-Publish 'SYMLINK_UNSUPPORTED'}
   if($item.PSIsContainer){$stack.Push($item.FullName);continue}
   if(Secret-Path $item.Name){continue}
   if($item.Length -ge 104857600){Stop-Publish 'FILE_TOO_LARGE'}
   if([IO.File]::ReadAllText($item.FullName).Contains($Token)){Stop-Publish 'SECRET_IN_FILES'}
  }
 }
 if($DryRun){@{ok=$true;action='dry-run';repository=$RepoName;token_file_present=$true;gitignore_planned=$true}|ConvertTo-Json -Compress;exit 0}
 [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
 $script:Headers=@{Authorization="Bearer $Token";Accept='application/vnd.github+json';'X-GitHub-Api-Version'='2026-03-10'}
 Api GET '/user'
 if($script:Status -ne 200){Stop-Publish 'TOKEN_INVALID'}
 $Login=$script:Body.login;$UserId=$script:Body.id
 if($Login -notmatch '^[a-zA-Z0-9-]+$' -or "$UserId" -notmatch '^\d+$'){Stop-Publish 'API_RESPONSE_INVALID'}
 $Action='created';$statePath='.git/pages-beginner-state'
 if(Test-Path $statePath){
  $owner,$Repo=([IO.File]::ReadAllText((Join-Path $ProjectDir $statePath)).Trim() -split ' ')
  if($owner -ne $Login){Stop-Publish 'ACCOUNT_MISMATCH'}
  if($Repo -notmatch '^[a-zA-Z0-9][a-zA-Z0-9_-]*$'){Stop-Publish 'REPO_CONFLICT'}
  $Action='updated'
 }else{
  if(Test-Path .git){$remote=Git-Raw @('remote','get-url','origin');if($script:GitExit -eq 0){Stop-Publish 'UNMANAGED_REMOTE'}}
  $Repo=$RepoName;$n=1
  while($true){Api GET "/repos/$Login/$Repo";if($script:Status -eq 404){break};if($script:Status -ne 200){Stop-Publish 'REPO_CREATE_FAILED'};$n++;if($n -gt 30){Stop-Publish 'REPO_CONFLICT'};$Repo="$RepoName-$n"}
 }
 $Remote="https://github.com/$Login/$Repo.git"
 if($Action -eq 'updated'){
  if((Git-Run @('remote','get-url','origin')) -ne $Remote){Stop-Publish 'REPO_CONFLICT'}
  Api GET "/repos/$Login/$Repo"
  if($script:Status -ne 200 -or $script:Body.private){Stop-Publish 'REPO_CONFLICT'}
 }
 $TempPath=Join-Path ([IO.Path]::GetTempPath()) ('pages-publish-'+[guid]::NewGuid().ToString('N'))
 $null=New-Item -ItemType Directory -Path $TempPath
 # Restrict temporary credentials to the current user before writing them.
 $acl=New-Object Security.AccessControl.DirectorySecurity
 $acl.SetAccessRuleProtection($true,$false)
 $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User
 $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow')))
 Set-Acl -LiteralPath $TempPath -AclObject $acl
 $utf8=New-Object Text.UTF8Encoding($false)
 $credentialPath=Join-Path $TempPath 'credentials'
 [IO.File]::WriteAllText($credentialPath,"https://x-access-token:$Token@github.com`n",$utf8)
 $escaped=$credentialPath.Replace('\','/').Replace("'","'\''")
 function Auth-Git([string[]]$Arguments){
  $env:GIT_TERMINAL_PROMPT='0'
  return Git-Run (@('-c','credential.helper=','-c',"credential.helper=store --file='$escaped'",'-c','credential.interactive=false','-c','http.followRedirects=false')+$Arguments)
 }
 if($Action -eq 'updated'){
  $heads=Auth-Git @('ls-remote','--heads','origin')
  if($heads){
   if($heads -notmatch 'refs/heads/main(\r?\n|$)'){Stop-Publish 'REPO_CONFLICT'}
   $null=Auth-Git @('fetch','origin','main')
   $null=Git-Raw @('merge-base','--is-ancestor','FETCH_HEAD','HEAD')
   if($script:GitExit -ne 0){Stop-Publish 'REMOTE_DIVERGED'}
  }
 }
 if(!(Test-Path .git)){$null=Git-Run @('init','-q');$null=Git-Run @('symbolic-ref','HEAD','refs/heads/main')}
 $backup=Join-Path '.git/pages-backups' ((Get-Date -Format yyyyMMdd-HHmmss)+'-'+[guid]::NewGuid().ToString('N'))
 $null=New-Item -ItemType Directory -Path $backup -Force
 $ignorePath=Join-Path $ProjectDir '.gitignore'
 $ignore='';if(Test-Path $ignorePath){Copy-Item -LiteralPath $ignorePath -Destination (Join-Path $backup 'gitignore');$ignore=[IO.File]::ReadAllText($ignorePath)}
 foreach($rule in @('github_pat.txt','github_pat*','.env','.env.*','*.pem','*.key','.DS_Store','.agents/','.codex/','node_modules/')){
  if(($ignore -split '\r?\n') -notcontains $rule){if($ignore -and !$ignore.EndsWith("`n")){$ignore+="`n"};$ignore+="$rule`n"}
 }
 [IO.File]::WriteAllText($ignorePath,$ignore,$utf8)
 if(!(Test-Path .nojekyll)){[IO.File]::WriteAllText((Join-Path $ProjectDir '.nojekyll'),'',$utf8)}
 $null=Git-Run @('config','user.name',$Login)
 $null=Git-Run @('config','user.email',"$UserId+$Login@users.noreply.github.com")
 $null=Git-Run @('add','-A')
 foreach($p in ((Git-Run @('ls-files','-z')) -split "`0")){if(Secret-Path $p){Stop-Publish 'SECRET_STAGED'}}
 $null=Git-Raw @('diff','--cached','--quiet')
 if($script:GitExit -ne 0){$null=Git-Run @('commit','-qm','Publish or update website')}else{$Action='unchanged'}
 $Sha=Git-Run @('rev-parse','HEAD')
 if(!(Test-Path $statePath)){
  Api POST '/user/repos' @{name=$Repo;private=$false;auto_init=$false}
  if($script:Status -ne 201){Stop-Publish 'REPO_CREATE_FAILED'}
  $null=Git-Run @('remote','add','origin',$Remote)
  [IO.File]::WriteAllText((Join-Path $ProjectDir $statePath),"$Login $Repo`n",$utf8)
 }
 $null=Auth-Git @('push','-u','origin','main')
 Api GET "/repos/$Login/$Repo/pages"
 if($script:Status -eq 404){
  Api POST "/repos/$Login/$Repo/pages" @{build_type='legacy';source=@{branch='main';path='/'}}
  if($script:Status -ne 201){Stop-Publish 'PAGES_CREATE_FAILED'}
 }elseif($script:Status -eq 200){
  if($script:Body.cname -or $script:Body.build_type -eq 'workflow'){Stop-Publish 'CUSTOM_PAGES_CONFIG'}
  if($script:Body.source.branch -ne 'main' -or $script:Body.source.path -ne '/'){
   Api PUT "/repos/$Login/$Repo/pages" @{source=@{branch='main';path='/'}}
   if($script:Status -ne 204){Stop-Publish 'PAGES_CONFIG_FAILED'}
  }
 }else{Stop-Publish 'PAGES_CONFIG_FAILED'}
 $Url="https://$Login.github.io/$Repo/";$deadline=(Get-Date).AddSeconds($WaitSeconds);$success=$false
 while($true){
  Api GET "/repos/$Login/$Repo/pages/builds/latest"
  if($script:Status -eq 200 -and $script:Body.commit -eq $Sha){
   if($script:Body.status -eq 'errored'){Stop-Publish 'PAGES_BUILD_FAILED'}
   if($script:Body.status -eq 'built'){
    try{
     # Public URL deliberately has no PAT or API headers.
     $sitePath=Join-Path $TempPath 'site'
     $r=Invoke-WebRequest -UseBasicParsing -Uri "$Url`?verify=$Sha" -TimeoutSec 25 -OutFile $sitePath -PassThru
     if($r.StatusCode -eq 200 -and (Git-Run @('hash-object','--no-filters',$sitePath)) -eq (Git-Run @('rev-parse','HEAD:index.html'))){$success=$true;break}
    }catch{}
   }
  }elseif($script:Status -ne 200 -and $script:Status -ne 404){Stop-Publish 'PAGES_CONFIG_FAILED'}
  if((Get-Date) -ge $deadline){break};Start-Sleep -Seconds 5
 }
 @{ok=$success;action=$Action;username=$Login;repository=$Repo;repository_url="https://github.com/$Login/$Repo";pages_url=$Url;commit=$Sha;pages_status=$(if($success){'built'}else{'pending'});code=$(if($success){''}else{'PAGES_BUILD_PENDING'})}|ConvertTo-Json -Compress
 if(!$success){exit 2}
}catch{
 $code=$_.Exception.Message
 if($code -notmatch '^[A-Z][A-Z0-9_]+$'){$code='INTERNAL_ERROR'}
 @{ok=$false;code=$code}|ConvertTo-Json -Compress
 exit 1
}finally{
 if($TempPath -and (Test-Path -LiteralPath $TempPath)){Remove-Item -LiteralPath $TempPath -Recurse -Force}
 $Token=$null;$script:Headers=$null
}
