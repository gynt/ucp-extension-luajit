param (
  [Parameter(Mandatory=$true)][string]$BuildType,
  [Parameter(Mandatory=$true)][string]$UCP3Path
)

Push-Location vendor\luajit\src
.\msvcbuild.bat
Pop-Location

Push-Location exceptions\luajitexceptions
msbuild /t:restore /p:RestoreAdditionalProjectSources="$UCP3Path"
msbuild /p:Configuration=$BuildType
Pop-Location