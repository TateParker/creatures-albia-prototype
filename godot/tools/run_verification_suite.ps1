param(
	[Parameter(Mandatory = $true)]
	[string]$GodotExecutable
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$resolvedExecutable = (Resolve-Path $GodotExecutable).Path
$checks = @(
	"verify_action_utility.gd",
	"verify_avi_writer.gd",
	"verify_biochemistry.gd",
	"verify_drawing_reach.gd",
	"verify_drawing_system.gd",
	"verify_family_system.gd",
	"verify_face_geometry.gd",
	"verify_recording_retention.gd",
	"verify_record_scripts_parse.gd",
	"verify_norn_animation.gd",
	"verify_social_slice.gd",
	"verify_stabilization.gd",
	"run_habitat_scenario.gd"
)
$runtimeErrorPattern = "(?m)(^|[\r\n])(?:SCRIPT ERROR|ERROR):"

foreach ($check in $checks) {
	$arguments = @("--headless", "--path", $projectRoot)
	if ($check -eq "run_habitat_scenario.gd") {
		$arguments += @("--fixed-fps", "60")
	}
	$arguments += @("--script", "res://tools/$check")
	Write-Output "RUN $check"
	$output = & $resolvedExecutable @arguments 2>&1
	$exitCode = $LASTEXITCODE
	$output | ForEach-Object { Write-Output $_.ToString() }
	$outputText = $output -join "`n"
	if ($exitCode -ne 0 -or $outputText -match $runtimeErrorPattern) {
		Write-Error "Verification failed: $check (exit $exitCode; Godot runtime errors are treated as failures)."
		exit 1
	}
	Write-Output "PASS $check"
}

Write-Output "GODOT_VERIFICATION_SUITE_OK count=$($checks.Count)"
