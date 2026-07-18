$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$background = Join-Path $root 'www\assets\art\backgrounds\wildcard-endless-victory-cosmos.webp'
$expressions = Join-Path $root 'www\assets\art\sly\sly-expression-grid.webp'
$tempDir = Join-Path $root 'output\cinematic'
$tear = Join-Path $tempDir 'tear.png'
$output = Join-Path $root 'www\assets\video\sly-single-tear.mp4'

if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
  throw 'ffmpeg is required to rebuild the Sly tear cinematic.'
}
if (-not (Test-Path -LiteralPath $background) -or -not (Test-Path -LiteralPath $expressions)) {
  throw 'Canonical Sly or Endless artwork is missing.'
}

New-Item -ItemType Directory -Force -Path $tempDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $output) | Out-Null

& ffmpeg -y -hide_banner -loglevel error `
  -f lavfi -i 'nullsrc=s=40x64,format=rgba' `
  -vf "geq=r='150':g='235':b='255':a='if(lt(pow(X-20,2)+pow(Y-40,2),380),220,if(gte(Y,2)*lte(Y,40)*lt(abs(X-20),Y*0.34),220,0))'" `
  -frames:v 1 $tear
if ($LASTEXITCODE -ne 0) { throw 'Tear matte generation failed.' }

$filter = "[0:v]crop=720:1600:90:0,eq=brightness=-0.13:saturation=0.82,gblur=sigma=1.1[bg];" +
  "[1:v]crop=200:200:400:400,scale=600:600:flags=lanczos[face];" +
  "[bg][face]overlay=x=60:y=330:format=auto[portrait];" +
  "[2:v]scale=18:30,format=rgba,fade=t=in:st=0.55:d=0.12:alpha=1,fade=t=out:st=1.82:d=0.22:alpha=1[tear];" +
  "[portrait][tear]overlay=x=420:y='570+if(lt(t,0.55),0,min((t-0.55)/1.1,1)*260)':enable='between(t,0.55,2.05)'," +
  "vignette=PI/5,fade=t=in:st=0:d=0.22,fade=t=out:st=2.08:d=0.32,format=yuv420p[out]"

& ffmpeg -y -hide_banner -loglevel error `
  -loop 1 -framerate 30 -t 2.4 -i $background `
  -loop 1 -framerate 30 -t 2.4 -i $expressions `
  -loop 1 -framerate 30 -t 2.4 -i $tear `
  -filter_complex $filter -map '[out]' -an `
  -c:v libx264 -profile:v main -level:v 4.0 -preset slow -crf 24 `
  -movflags '+faststart' -r 30 $output
if ($LASTEXITCODE -ne 0) { throw 'Sly tear cinematic encoding failed.' }

$asset = Get-Item -LiteralPath $output
if ($asset.Length -ge 300000) {
  throw "Sly tear cinematic exceeds the 300 KB mobile budget: $($asset.Length) bytes."
}

Write-Output "Built $output ($($asset.Length) bytes)"
