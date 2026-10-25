# Agente testador: joga todos os conjuntos com os bots (playtest em lote, nas políticas sequential e stack),
# roda a bancada dos heróis (dev/hero_bench.gd) e escreve o relatório de balanço com as marcações de
# "forte demais" e "fraco demais" (tools/playtest/agent_report.js).
#   powershell -File tools/playtest/agent.ps1 -Out pasta
#   powershell -File tools/playtest/agent.ps1 -Sets costarubra,panteao -PerPolicy 20 -Out pasta
# Roda no máximo -Parallel processos do Godot ao mesmo tempo. O relatório fica em <Out>/relatorio.md.
param(
	[string]$Godot = 'E:\Download\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe',
	[string[]]$Sets = @('valcoroa', 'costarubra', 'forjaferro', 'cripta', 'panteao', 'todas'),
	[int]$PerPolicy = 12,
	[int]$Slices = 2,
	[int]$Seeds = 2,
	[int]$Parallel = 8,
	[switch]$NoBench,
	[switch]$NoPlaytest,
	[Parameter(Mandatory = $true)][string]$Out
)
# Com -File, "-Sets a,b" chega como um texto só.
$Sets = @($Sets | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = (Resolve-Path $Out).Path
$project = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$jobs = @()
foreach ($set in $Sets) {
	$dir = Join-Path $Out $set
	New-Item -ItemType Directory -Force $dir | Out-Null
	if (-not $NoBench) {
		$jobs += , @('-s', 'dev/hero_bench.gd', '--', "--set=$set", "--seeds=$Seeds", "`"--out=$(Join-Path $dir 'bench.json')`"", (Join-Path $dir 'bench.log'))
	}
	if (-not $NoPlaytest) {
		$slice = [math]::Ceiling($PerPolicy / $Slices)
		foreach ($policy in @('sequential', 'stack')) {
			for ($p = 0; $p -lt $Slices; $p++) {
				$from = $p * $slice
				$count = [math]::Min($slice, $PerPolicy - $from)
				if ($count -le 0) { continue }
				$file = Join-Path $dir "$policy-$p.json"
				$jobs += , @('-s', 'dev/playtest.gd', '--', "--set=$set", "--policy=$policy", "--from=$from", "--count=$count",
					"`"--out=$file`"", (Join-Path $dir "$policy-$p.log"))
			}
		}
	}
}
$running = @()
$started = Get-Date
foreach ($job in $jobs) {
	while (@($running | Where-Object { -not $_.HasExited }).Count -ge $Parallel) { Start-Sleep -Milliseconds 500 }
	$log = $job[-1]
	$argList = @('--headless', '--path', "`"$project`"") + $job[0..($job.Count - 2)]
	$running += Start-Process -FilePath $Godot -ArgumentList $argList -NoNewWindow -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
}
$running | Wait-Process
Write-Output ("Agente testador: {0} processos em {1:mm\:ss}." -f $jobs.Count, ((Get-Date) - $started))
node (Join-Path $PSScriptRoot 'agent_report.js') $Out (Join-Path $Out 'relatorio.md') | Out-Null
Write-Output "Relatório: $(Join-Path $Out 'relatorio.md')"
