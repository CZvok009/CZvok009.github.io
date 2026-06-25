# Spusti cloudflared a zachyti URL tunelu do tunnel_url.txt
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$urlFile = Join-Path $root "tunnel_url.txt"
$snippetFile = Join-Path $root "tunnel_url_snippet.txt"
$logFile = Join-Path $root "tunnel_log.txt"

Remove-Item $urlFile, $snippetFile, $logFile -ErrorAction SilentlyContinue

Write-Host "Spoustim cloudflared tunel na http://localhost:5678 ..." -ForegroundColor Cyan
Write-Host ""

$urlSaved = $false

& npx cloudflared tunnel --url http://localhost:5678 2>&1 | ForEach-Object {
    $line = $_.ToString()
    Add-Content -Path $logFile -Value $line

    if (-not $urlSaved -and $line -match '(https://[a-z0-9-]+\.trycloudflare\.com)') {
        $url = $Matches[1]
        Set-Content -Path $urlFile -Value $url -NoNewline
        $snippet = "const TARGET_TUNNEL = '$url';"
        Set-Content -Path $snippetFile -Value $snippet -NoNewline
        $urlSaved = $true

        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host " TUNEL URL: $url" -ForegroundColor Green
        Write-Host " Ulozeno do: tunnel_url.txt" -ForegroundColor Green
        Write-Host " Radek pro index.html: tunnel_url_snippet.txt" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
    }

    Write-Host $line
}
