Write-Host "[PRE-PUSH] Checking changes..."

$PublicRepo = "https://github.com/Loupimo/Test-pub.git"
$Temp = "$env:TEMP\public-export"

# Récupérer fichiers modifiés entre HEAD et index
$files = git diff --name-only HEAD~1..HEAD

# Charger ignore list
$ignore = @()
if (Test-Path ".publicignore") {
    $ignore = Get-Content ".publicignore" | Where-Object { $_ -and -not $_.StartsWith("#") }
}

# Vérifier si au moins un fichier public est touché
$hasPublicChange = $false

foreach ($file in $files) {
    foreach ($pattern in $ignore) {
        if ($file -like $pattern) {
            continue
        }
    }

    # si le fichier n'est PAS ignoré → public change détecté
    $isIgnored = $false
    foreach ($pattern in $ignore) {
        if ($file -like $pattern) {
            $isIgnored = $true
        }
    }

    if (-not $isIgnored) {
        $hasPublicChange = $true
    }
}

if (-not $hasPublicChange) {
    Write-Host "[PRE-PUSH] No public changes -> skipping public sync"
    exit 0
}

Write-Host "[PRE-PUSH] Public changes detected -> syncing..."

# clean temp
if (Test-Path $Temp) {
    Remove-Item $Temp -Recurse -Force
}
New-Item -ItemType Directory -Path $Temp | Out-Null

# branch + msg
$branch = git rev-parse --abbrev-ref HEAD
$msg = git log -1 --pretty=%B

# copy repo
Get-ChildItem -Recurse | ForEach-Object {

    $relative = $_.FullName.Replace((Get-Location).Path + "\", "")

    $skip = $false
    foreach ($pattern in $ignore) {
        if ($relative -like $pattern) {
            $skip = $true
        }
    }

    if ($skip) { return }

    $target = Join-Path $Temp $relative

    if ($_.PSIsContainer) {
        New-Item -ItemType Directory -Force -Path $target | Out-Null
    } else {
        New-Item -ItemType Directory -Force -Path (Split-Path $target) | Out-Null
        Copy-Item $_.FullName $target -Force
    }
}

Set-Location $Temp

git init | Out-Null
git checkout -b $branch | Out-Null
git remote add origin $PublicRepo

git add .
git commit -m $msg
git push origin $branch --force

Write-Host "[PRE-PUSH] DONE"