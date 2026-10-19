# Playtest em lote: roda `dev/playtest.gd` em vários processos do Godot ao mesmo tempo e espera todos.
#   powershell -File tools/playtest/run_batch.ps1 -Set valcoroa -PerPolicy 100 -Procs 5 -Out pasta
# Cada processo joga uma fatia das sementes de cada política (sequential e stack) e grava um JSON.
param(
	[string]$Godot = 'E:\Download\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe',
	[string]$Set = 'valcoroa',
	[int]$PerPolicy = 100,
	[int]$Procs = 5,
	[int]$Interval = 600,
	[Parameter(Mandatory = $true)][string]$Out
)
New-Item -ItemType Directory -Force $Out | Out-Null
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$slice = [math]::Ceiling($PerPolicy / $Procs)
$running = @()
foreach ($policy in 'sequential', 'stack') {
	for ($p = 0; $p -lt $Procs; $p++) {
		$from = $p * $slice
		$count = [math]::Min($slice, $PerPolicy - $from)
		if ($count -le 0) { continue }
		$file = Join-Path $Out "$policy-$p.json"
		$log = Join-Path $Out "$policy-$p.log"
		$argList = @('--headless', '--path', $project, '-s', 'dev/playtest.gd', '--', "--set=$Set", "--policy=$policy",
			"--from=$from", "--count=$count", "--interval=$Interval", "--out=$file")
		$running += Start-Process -FilePath $Godot -ArgumentList $argList -NoNewWindow -PassThru -RedirectStandardOutput $log
	}
}
$running | Wait-Process
Write-Output "Playtest terminou: $($running.Count) processos."
