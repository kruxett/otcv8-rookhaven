# Owned release QA only. Never deploys or edits client/server sources.
# Profile moves use same-volume, exact-name opaque renames and a recovery journal.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$Config)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
function Assert([bool]$ok,[string]$why){if(-not $ok){throw $why}}
function Hash([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLowerInvariant()}
$cfg=Get-Content -LiteralPath $Config -Raw | ConvertFrom-Json
$evidenceRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../out/release-smoke-20261027'))
Assert ([IO.Path]::IsPathRooted([string]$cfg.stage)) 'Stage must be an explicit absolute path.'
$stage=[IO.Path]::GetFullPath([string]$cfg.stage)
Assert ($stage.StartsWith($evidenceRoot+'\',[StringComparison]::OrdinalIgnoreCase)) 'Stage must be a fresh child of the owned release-smoke evidence root.'
Assert (-not (Test-Path -LiteralPath $stage)) 'This run already exists; reconcile before retry.'
Assert ([int]$cfg.newVersion -gt [int]$cfg.oldVersion) 'Updater target must be newer.'
foreach($name in @('oldClientZipSha256','oldExeSha256','oldDataSha256','newExeSha256','newDataSha256')){Assert ([string]$cfg.$name -cmatch '^[0-9a-f]{64}$') ('Invalid SHA256 pin: '+$name)}
Assert ((Hash ([string]$cfg.oldClientZip)) -ceq [string]$cfg.oldClientZipSha256) 'Previous published archive differs from the authoritative baseline.'
Assert ([string]$cfg.oldExeSha256 -cne [string]$cfg.newExeSha256 -and [string]$cfg.oldDataSha256 -cne [string]$cfg.newDataSha256) 'This proof requires a real binary AND data transition.'
Assert (@(Get-CimInstance Win32_Process -Filter "Name LIKE 'Rookhaven%.exe' OR Name LIKE 'otclient%.exe'").Count -eq 0) 'A client is already running.'
[void][IO.Directory]::CreateDirectory($stage)
$acl=Get-Acl -LiteralPath $stage;$acl.SetAccessRuleProtection($true,$false)
foreach($rule in @($acl.GetAccessRules($true,$false,[Security.Principal.SecurityIdentifier]))){[void]$acl.RemoveAccessRuleAll($rule)}
foreach($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,[Security.Principal.SecurityIdentifier]::new('S-1-5-18'))){$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid,'FullControl','ContainerInherit,ObjectInherit','None','Allow'))}
Set-Acl -LiteralPath $stage -AclObject $acl
$copy=Join-Path $stage 'client-copy';$backupRoot=Join-Path $stage 'profile-backups';$generatedRoot=Join-Path $stage 'generated-profiles';$blankRoot=Join-Path $stage 'blank-profiles'
$profileBase=Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Rookhaven Client'
$profileNames=@('Rookhaven','Rookhaven-LocalItemTest','Rookhaven-LocalPassives-Probe','Rookhaven-LocalPassives-Probe-Peer')
$oldExe=[string]$cfg.oldExeSha256;$oldData=[string]$cfg.oldDataSha256
$newExe=[string]$cfg.newExeSha256;$newData=[string]$cfg.newDataSha256
$uiWaitSeconds=if($cfg.PSObject.Properties.Name -contains 'uiWaitSeconds'){[int]$cfg.uiWaitSeconds}else{900}
Assert ($uiWaitSeconds -ge 30 -and $uiWaitSeconds -le 1800) 'GUI wait must be 30..1800 seconds.'
$profiles=[Collections.Generic.List[object]]::new();$owned=@{};$started=[DateTime]::UtcNow;$nativeRuns=0;$failure=$null;$result=$null;$restored=$false;$uiSignaled=$false
function StageChild([string]$p){Assert ([IO.Path]::GetFullPath($p).StartsWith($stage+'\',[StringComparison]::OrdinalIgnoreCase)) 'Artifact outside owned stage.'}
function Fingerprint([string]$p){
 if(-not (Test-Path -LiteralPath $p)){return 'ABSENT'}
 Assert (-not ((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Profile root reparse point forbids opaque traversal.'
 $all=@(Get-ChildItem -LiteralPath $p -Recurse -Force)
 Assert (@($all|Where-Object{$_.Attributes -band [IO.FileAttributes]::ReparsePoint}).Count -eq 0) 'Profile reparse point forbids opaque traversal.'
 $all=@((Get-Item -LiteralPath $p -Force))+$all
 $rows=@($all|Sort-Object FullName|ForEach-Object{$relative=$_.FullName.Substring($p.Length);$security=(Get-Acl -LiteralPath $_.FullName).Sddl;if($_.PSIsContainer){'D|'+$relative+'|'+$security}else{'F|'+$relative+'|'+(Hash $_.FullName)+'|'+$security}})
 $sha=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($rows -join "`n")))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function No-Clients{Assert (@(Get-CimInstance Win32_Process -Filter "Name LIKE 'Rookhaven%.exe' OR Name LIKE 'otclient%.exe'").Count -eq 0) 'A client owns a profile; profile moves/native startup prohibited.'}
function Profile-Paths($record){
 Assert ($record.name -cin $profileNames) 'Unexpected profile name.'
 Assert ($record.path -ceq [IO.Path]::GetFullPath((Join-Path $profileBase $record.name))) 'Profile path outside the exact known targets.'
 Assert ($record.backup -ceq [IO.Path]::GetFullPath((Join-Path $backupRoot $record.name)) -and $record.blank -ceq [IO.Path]::GetFullPath((Join-Path $blankRoot $record.name))) 'Profile staging path differs.'
 StageChild $record.backup;StageChild $record.blank
 Assert ([IO.Path]::GetPathRoot($record.path) -eq [IO.Path]::GetPathRoot($record.backup)) 'Opaque profile rename must stay on one volume.'
}
function Replace-Receipt([string]$pending,[string]$path){[IO.File]::Replace($pending,$path,[Management.Automation.Language.NullString]::Value,$true)}
function Atomic-Json([string]$path,$value){
 StageChild $path;$pending=$path+'.pending-'+[Guid]::NewGuid().ToString('N');StageChild $pending
 [IO.File]::WriteAllText($pending,($value|ConvertTo-Json -Depth 12),[Text.UTF8Encoding]::new($false))
 $desired=Hash $pending;$before=if([IO.File]::Exists($path)){Hash $path}else{'ABSENT'}
 for($attempt=0;$attempt -lt 4;$attempt++){
  try{
   if([IO.File]::Exists($path)){Replace-Receipt $pending $path}else{[IO.File]::Move($pending,$path)}
   Assert ((Hash $path) -ceq $desired) 'Atomic receipt content differs after write.';return
  }catch{
   $failed=$_;$io=$_.Exception.GetBaseException()
   # ERROR_UNABLE_TO_REMOVE_REPLACED (1175) was observed on the synthetic
   # fixture. Other errors remain fail-closed; no broad filesystem retry.
   if(-not ($io -is [IO.IOException]) -or ($io.HResult -band 65535) -ne 1175){throw $failed}
   $now=if([IO.File]::Exists($path)){Hash $path}else{'ABSENT'}
   $pendingNow=if([IO.File]::Exists($pending)){Hash $pending}else{'ABSENT'}
   Assert ($pendingNow -ceq 'ABSENT' -or $pendingNow -ceq $desired) 'Prepared receipt changed after ambiguous replacement.'
   if($now -ceq $desired){
    # Replace may have committed before reporting an error. Reconcile the
    # identical desired bytes rather than replacing them again.
    if($pendingNow -ceq $desired){StageChild $pending;Remove-Item -LiteralPath $pending -Force};return
   }
   Assert ($now -ceq $before -and $pendingNow -ceq $desired) 'Ambiguous receipt outcome; refusing overwrite/retry.'
   if($attempt -ge 3){throw $failed}
   Start-Sleep -Milliseconds (120+($attempt*30)+[Random]::new().Next(0,61))
  }
 }
}
function Profile-State([string]$phase){
 Atomic-Json (Join-Path $stage 'profile-state.json') ([ordered]@{phase=$phase;utc=[DateTime]::UtcNow.ToString('o');nativeRuns=$nativeRuns;profiles=@($profiles.ToArray())})
}
function Snapshot-Profiles{
 No-Clients
 Assert ([IO.Directory]::Exists($profileBase) -and -not ((Get-Item -LiteralPath $profileBase -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) 'Known profile parent must exist without redirection.'
 foreach($name in $profileNames){
  $path=[IO.Path]::GetFullPath((Join-Path $profileBase $name))
  Assert (-not [IO.File]::Exists($path)) 'A profile target is a file.'
  $record=[pscustomobject]@{name=$name;path=$path;backup=[IO.Path]::GetFullPath((Join-Path $backupRoot $name));blank=[IO.Path]::GetFullPath((Join-Path $blankRoot $name));fingerprint=Fingerprint $path;existed=[IO.Directory]::Exists($path);moved=$false;generated=$false;ownedFingerprint='';restoredFingerprint='';pending='';restored=$false;quarantines=@()}
  Profile-Paths $record;[void]$profiles.Add($record)
  Assert (-not [IO.Directory]::Exists($record.backup) -and -not [IO.Directory]::Exists($record.blank)) 'Profile stage was already used.'
  [void][IO.Directory]::CreateDirectory($record.blank)
  [IO.File]::WriteAllText((Join-Path $record.blank 'config.otml'),"window-size: 1280 800`nwindow-maximized: false`nwindow-pos: 80 80`nautoReconnect: false`naccount:`npassword:`nserver: Default`nhost: testserver2.rookhaven-ot.com:7173:860`nclient-version: 860`n",[Text.UTF8Encoding]::new($false))
  $record.ownedFingerprint=Fingerprint $record.blank
 }
 # All baseline fingerprints and blank trees exist before the first profile move.
 Profile-State 'ALL_ORIGINALS_SNAPSHOTTED_BLANKS_STAGED'
}
function Install-Profiles{
 Assert ($profiles.Count -eq $profileNames.Count) 'All known profiles must be snapshotted before mutation.'
 foreach($record in $profiles){Profile-Paths $record;Assert ((Fingerprint $record.path) -ceq $record.fingerprint) 'An original changed before the first move.'}
 foreach($record in $profiles){
  Profile-Paths $record;No-Clients
  Assert ((Fingerprint $record.path) -ceq $record.fingerprint) 'Profile changed after the snapshot; refusing preparation.'
  if($record.existed){
   $record.pending='BACKUP_ORIGINAL';Profile-State 'BEFORE_ORIGINAL_MOVE';No-Clients
   Assert (-not [IO.Directory]::Exists($record.backup) -and (Fingerprint $record.path) -ceq $record.fingerprint) 'Original changed before backup.'
   [IO.Directory]::Move($record.path,$record.backup);$record.moved=$true;$record.pending='';Profile-State 'ORIGINAL_BACKED_UP'
   Assert ((Fingerprint $record.backup) -ceq $record.fingerprint) 'Original backup integrity failed.'
  }
  $record.pending='INSTALL_BLANK';Profile-State 'BEFORE_BLANK_MOVE';No-Clients
  Assert (-not [IO.Directory]::Exists($record.path) -and -not [IO.File]::Exists($record.path)) 'Profile target reappeared; refusing native startup.'
  # Exclusive rename of an already prepared blank; never adopt an existing tree.
  [IO.Directory]::Move($record.blank,$record.path);$record.generated=$true;$record.pending='';Profile-State 'BLANK_INSTALLED'
  Assert ((Fingerprint $record.path) -ceq $record.ownedFingerprint) 'Installed blank profile changed unexpectedly.'
 }
}
function Prepared-Profiles{
 No-Clients;Assert ($profiles.Count -eq $profileNames.Count) 'Missing prepared profile state.'
 foreach($record in $profiles){Profile-Paths $record;Assert ($record.generated -and (Fingerprint $record.path) -ceq $record.ownedFingerprint) 'Prepared target changed/reappeared; native startup prohibited.'}
}
function Quarantine-Profile($record){
 Profile-Paths $record;No-Clients
 $fingerprint=Fingerprint $record.path
 Assert ($fingerprint -cne 'ABSENT' -and [IO.Directory]::Exists($record.path)) 'Expected profile tree to preserve.'
 $destination=Join-Path $generatedRoot ($record.name+'-'+[Guid]::NewGuid().ToString('N'));StageChild $destination
 $record.pending='PRESERVE_PRESENT_TREE';Profile-State 'BEFORE_QUARANTINE';No-Clients
 [IO.Directory]::Move($record.path,$destination)
 Assert ((Fingerprint $destination) -ceq $fingerprint -and -not [IO.Directory]::Exists($record.path)) 'Opaque quarantine integrity failed.'
 $record.quarantines+=@([pscustomobject]@{path=$destination;fingerprint=$fingerprint});$record.generated=$false;$record.pending='';Profile-State 'PRESENT_TREE_PRESERVED'
}
function Restore-Profiles{
 No-Clients
 foreach($record in $profiles){
  Profile-Paths $record;No-Clients
  $hasBackup=[IO.Directory]::Exists($record.backup)
  if($hasBackup){
   Assert ($record.existed -and (Fingerprint $record.backup) -ceq $record.fingerprint) 'Original backup differs; refusing restoration.'
   if([IO.Directory]::Exists($record.path)){Quarantine-Profile $record}
   $record.pending='RESTORE_ORIGINAL';Profile-State 'BEFORE_RESTORE';No-Clients
   Assert (-not [IO.Directory]::Exists($record.path) -and -not [IO.File]::Exists($record.path)) 'Restoration target reappeared again.'
   [IO.Directory]::Move($record.backup,$record.path);$record.moved=$false;$record.generated=$false
  }elseif(-not $record.existed){
   if([IO.Directory]::Exists($record.path)){Quarantine-Profile $record}
  }
  $record.restoredFingerprint=Fingerprint $record.path
  Assert ($record.restoredFingerprint -ceq $record.fingerprint) 'Original profile restoration integrity failed.'
  $record.restored=$true;$record.pending='';Profile-State 'PROFILE_RESTORED'
 }
 Profile-State 'ALL_PROFILES_RESTORED'
}
function Track{
 $found=@(Get-CimInstance Win32_Process -Filter "Name LIKE 'RookhavenClient%.exe'"|Where-Object{$_.ExecutablePath -and $_.ExecutablePath.StartsWith($copy+'\',[StringComparison]::OrdinalIgnoreCase)})
 foreach($p in $found){Assert ($p.CreationDate.ToUniversalTime() -ge $started) 'Stage process predates probe.';Assert ((Hash $p.ExecutablePath) -in @($oldExe,$newExe)) 'Unreviewed stage executable.';$key=[string]$p.ProcessId;if(-not $owned.ContainsKey($key)){$owned[$key]=[pscustomobject]@{pid=$p.ProcessId;parentPid=$p.ParentProcessId;path=$p.ExecutablePath;createdUtc=$p.CreationDate.ToUniversalTime().ToString('o');sha256=Hash $p.ExecutablePath}}}
 return $found
}
function Stop-Owned{
 for($attempt=0;$attempt -lt 4;$attempt++){
  $current=@(Track);if(-not $current.Count){Start-Sleep -Milliseconds 500;$current=@(Track);if(-not $current.Count){return}}
  foreach($p in $current){$known=$owned[[string]$p.ProcessId];$fresh=Get-CimInstance Win32_Process -Filter ('ProcessId='+$p.ProcessId);if($fresh){Assert ($fresh.ExecutablePath -eq $known.path -and $fresh.CreationDate.ToUniversalTime().ToString('o') -eq $known.createdUtc) 'Cleanup ownership changed.';Stop-Process -Id $fresh.ProcessId -ErrorAction Stop}}
  Start-Sleep -Milliseconds 700
 }
 Assert (@(Track).Count -eq 0) 'Owned clients still running; profile restoration prohibited.'
}
try{
 # Public API preflight is deliberately BEFORE any profile move or native launch.
 $request=@{version=[int]$cfg.oldVersion;os='windows';args=@{dev=$true}}|ConvertTo-Json -Compress
 $api=Invoke-RestMethod -Uri ([string]$cfg.updaterApiUrl) -Method Post -ContentType 'application/json' -Body $request -TimeoutSec 20
 Assert ($api.version -eq [int]$cfg.newVersion -and $api.files.'data.zip' -ceq $newData -and $api.binary.checksum -ceq $newExe) 'Public updater target differs from the release pins.'
 Atomic-Json (Join-Path $stage 'public-manifest.json') $api
 Expand-Archive -LiteralPath ([string]$cfg.oldClientZip) -DestinationPath $copy
 $exe=Join-Path $copy 'RookhavenClient.exe';$data=Join-Path $copy 'data.zip'
 Assert ((Hash $exe) -ceq $oldExe -and (Hash $data) -ceq $oldData) 'Previous published package differs.'
 Assert (-not (Test-Path -LiteralPath (Join-Path $copy 'init.lua')) -and -not (Test-Path -LiteralPath (Join-Path $copy 'init.luac'))) 'Retail updater proof forbids plaintext script startup.'
 foreach($dir in @($backupRoot,$generatedRoot,$blankRoot)){[void][IO.Directory]::CreateDirectory($dir)}
 Snapshot-Profiles;Install-Profiles;Prepared-Profiles
 # No --test, --local-passives, environment profile override or injected Lua.
 $process=Start-Process -FilePath $exe -WorkingDirectory $copy -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $stage 'stdout.log') -RedirectStandardError (Join-Path $stage 'stderr.log')
 $null=$process.Handle;$nativeRuns++;[void](Track);Profile-State 'REAL_UPDATER_STARTED'
 $deadline=[DateTime]::UtcNow.AddSeconds(300);$stable=$null;$stableId=''
 while([DateTime]::UtcNow -lt $deadline){
  $current=@(Track)
  $base=@($current|Where-Object{$_.ExecutablePath -ceq $exe -and $_.ProcessId -ne $process.Id -and (Hash $_.ExecutablePath) -ceq $newExe})
  if($base.Count -eq 1 -and (Hash $exe) -ceq $newExe -and (Hash $data) -ceq $newData){
   $id=([string]$base[0].ProcessId)+'|'+$base[0].CreationDate.ToUniversalTime().ToString('o')
   if(-not $stable -or $stableId -cne $id){$stable=[DateTime]::UtcNow;$stableId=$id}
   if(([DateTime]::UtcNow-$stable).TotalSeconds -ge 8){break}
  }else{$stable=$null;$stableId=''}
  Start-Sleep -Milliseconds 500
 }
 Assert ($null -ne $stable -and ([DateTime]::UtcNow-$stable).TotalSeconds -ge 8) 'Updated child did not stabilize.'
 $process.Refresh();Assert ($process.HasExited -and $process.ExitCode -eq 0) 'Previous client did not exit normally.'
 $log=''
 foreach($logPath in @((Join-Path $stage 'stdout.log'),(Join-Path $copy 'Rookhaven.log'))){if(Test-Path -LiteralPath $logPath){$log+=Get-Content -LiteralPath $logPath -Raw}}
 Assert ($log -match 'Updating binary file: RookhavenClient-[0-9]+\.exe') 'Native HTTP binary download evidence missing.'
 Assert ($log -notmatch '(?m)^(ERROR|FATAL):') 'Client error during update.'
 Assert (@(Get-ChildItem -LiteralPath $copy -File -Filter 'RookhavenClient-*.exe').Count -eq 0) 'Versioned binary was not cleaned up.'
 $result=[ordered]@{state=('PASS_REAL_UPDATER'+$cfg.oldVersion+'_TO'+$cfg.newVersion);oldVersion=[int]$cfg.oldVersion;newVersion=[int]$cfg.newVersion;oldZipSha256=[string]$cfg.oldClientZipSha256;oldExitCode=$process.ExitCode;exeSha256=Hash $exe;dataSha256=Hash $data;childIdentity=$stableId;childStableSeconds=8;publicHttp=$true;nativeRestart=$true;noInjectedScripts=$true;normalProfile=(Join-Path $profileBase 'Rookhaven');visibleVersionRequiresGuiEvidence=$true;profileFingerprintIncludes='relative paths, every file SHA256, root and descendant owner/DACL SDDL';profileNames=$profileNames}
 Atomic-Json (Join-Path $stage 'ready-for-ui.json') $result
 [Console]::Out.WriteLine('REAL_UPDATER_PASSED_READY_FOR_UI')
 $uiDeadline=[DateTime]::UtcNow.AddSeconds($uiWaitSeconds)
 while(-not (Test-Path -LiteralPath (Join-Path $stage 'finish-ui')) -and [DateTime]::UtcNow -lt $uiDeadline){[void](Track);Start-Sleep -Seconds 1}
 $uiSignaled=Test-Path -LiteralPath (Join-Path $stage 'finish-ui')
 Assert $uiSignaled 'Native update passed, but GUI phase was not completed before cleanup timeout.'
}catch{$failure=$_}finally{
 $cleanupFailure=$null
 try{Stop-Owned;Restore-Profiles;$restored=$true}catch{$cleanupFailure=$_}
 $receipt=[ordered]@{state=if($result -and -not $failure -and -not $cleanupFailure){$result.state}else{'FAILED_NATIVE_UPDATER_CHECK'};profileRestored=$restored;uiCompletionSignaled=$uiSignaled;failure=if($failure){$failure.Exception.Message}else{''};cleanupFailure=if($cleanupFailure){$cleanupFailure.Exception.Message}else{''};evidence=$result;ownedProcesses=@($owned.Values);stage=$stage}
 Atomic-Json (Join-Path $stage 'result.json') $receipt
 $receipt|ConvertTo-Json -Depth 8
 if($cleanupFailure){throw $cleanupFailure}
}
if($failure){throw $failure}
