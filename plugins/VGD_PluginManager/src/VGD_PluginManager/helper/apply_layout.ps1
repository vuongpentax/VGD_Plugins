# VGD Plugin Manager - helper: luu/ap dung layout va phim tat SketchUp khi SketchUp da dong.
# Duoc plugin chay nen (an cua so). Doc file job (JSON), cho SketchUp thoat, thuc hien cac buoc,
# ghi ket qua vao file result, roi mo lai SketchUp neu job yeu cau.
# Chi dung ASCII trong file nay (Windows PowerShell 5.1 doc file khong co BOM theo ma trang cu).
#
# Cac buoc (steps):
#   capture: doc layout/phim tat cua SketchUp <year> va luu vao thu muc <dir>
#   apply:   ap dung snapshot trong <dir> vao SketchUp <year> (sao luu truoc, hoan tac neu loi)
# Chi cac khoa layout/phim tat duoc doc/ghi; moi thiet lap khac trong file cai dat giu nguyen.

param([Parameter(Mandatory = $true)][string]$Job)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Web.Extensions
$ser = New-Object System.Web.Script.Serialization.JavaScriptSerializer
$ser.MaxJsonLength = [int]::MaxValue
$ser.RecursionLimit = 200
$utf8 = New-Object System.Text.UTF8Encoding($false)

$script:results = New-Object System.Collections.Generic.List[string]
$script:logPath = $null

function New-Dict { New-Object 'System.Collections.Generic.Dictionary[string,object]' }

function Read-Json([string]$path) {
    $ser.DeserializeObject([System.IO.File]::ReadAllText($path, $utf8))
}

function Write-Json([string]$path, $obj) {
    [System.IO.File]::WriteAllText($path, $ser.Serialize($obj), $utf8)
}

function Write-Log([string]$msg) {
    $line = '[' + (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '] helper: ' + $msg
    if ($script:logPath) {
        try { [System.IO.File]::AppendAllText($script:logPath, $line + "`r`n", $utf8) } catch { }
    }
}

function Add-Result([string]$msg) {
    $script:results.Add($msg)
    Write-Log $msg
}

function Get-PrivatePrefsPath([string]$year) {
    Join-Path $env:LOCALAPPDATA "SketchUp\SketchUp $year\SketchUp\PrivatePreferences.json"
}

function Get-SharedPrefsPath([string]$year) {
    Join-Path $env:APPDATA "SketchUp\SketchUp $year\SketchUp\SharedPreferences.json"
}

# Phai khop voi Layout.layout_section? / shortcut_key? / MAIN_WINDOW_KEYS trong layout.rb
function Test-LayoutSection([string]$name) {
    return ($name -match '^(Qt)?RubyWorkspace\\') -or ($name -match '^Workspace\\') -or ($name -eq 'ToolbarSettings')
}
function Test-ShortcutKey([string]$name) {
    return ($name -match '^(Num_Shortcuts|Shortcut_\d+)$')
}
$mainWindowKeys = @('DockWidgetState', 'ToolBarState')
$regNames = @('Workspace', 'RubyWorkspace')

function Invoke-Reg([string[]]$argv) {
    $old = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & reg.exe @argv 2>&1 | Out-Null
        return $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $old
    }
}

function Test-Running([string]$year) {
    foreach ($p in @(Get-Process -Name SketchUp -ErrorAction SilentlyContinue)) {
        try { if ($p.Path -like "*SketchUp $year*") { return $true } } catch { }
    }
    return $false
}

# Job con hieu luc khong: file con va co cung id (job moi hon thay the job cu)
function Test-JobCurrent([string]$path, [string]$id) {
    try {
        if (-not (Test-Path -LiteralPath $path)) { return $false }
        $j = Read-Json $path
        return ([string]$j['id'] -eq $id)
    } catch {
        return $true
    }
}

# Doc mot khoa con an toan: Dictionary nem loi neu khoa khong ton tai. Tra ve $null neu thieu.
function Get-Child($d, [string]$name) {
    if ($d -is [System.Collections.IDictionary] -and $d.Contains($name)) { return $d[$name] }
    return $null
}

# Lay khoa con la object, tao moi (rong) neu chua co hoac sai kieu
function Get-Section($doc, [string]$name) {
    $sec = Get-Child $doc $name
    if (-not ($sec -is [System.Collections.IDictionary])) { $sec = New-Dict; $doc[$name] = $sec }
    return $sec
}

# ---- capture ----
function Invoke-Capture($step) {
    $year = [string]$step['year']
    $dir = [string]$step['dir']
    $parts = @($step['parts'])
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.reg' -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $f.FullName -Force }

    $prefs = New-Dict
    $shortcuts = New-Dict
    $gotLayout = $false

    if ($parts -contains 'layout') {
        $priv = Get-PrivatePrefsPath $year
        if (Test-Path -LiteralPath $priv) {
            $doc = Read-Json $priv
            $sec = Get-Child $doc 'This Computer Only'
            if ($null -ne $sec) {
                foreach ($k in @($sec.Keys)) {
                    if (Test-LayoutSection $k) { $prefs[$k] = $sec[$k] }
                }
                $mw = Get-Child $sec 'MainWindow'
                if ($null -ne $mw) {
                    $keep = New-Dict
                    foreach ($mk in $mainWindowKeys) { if ($mw.ContainsKey($mk)) { $keep[$mk] = $mw[$mk] } }
                    if ($keep.Count -gt 0) { $prefs['MainWindow'] = $keep }
                }
            }
        }
        foreach ($n in $regNames) {
            $key = "HKCU\Software\SketchUp\SketchUp $year\$n"
            if ((Invoke-Reg @('query', $key)) -eq 0) {
                if ((Invoke-Reg @('export', $key, (Join-Path $dir "$n.reg"), '/y')) -eq 0) { $gotLayout = $true }
            }
        }
        if ($prefs.Count -gt 0) { $gotLayout = $true }
        if (-not $gotLayout) { Add-Result "Khong tim thay du lieu layout cua SketchUp $year." }
    }

    if ($parts -contains 'shortcuts') {
        $shared = Get-SharedPrefsPath $year
        if (Test-Path -LiteralPath $shared) {
            $doc = Read-Json $shared
            $set = Get-Child (Get-Child $doc 'Windows Only') 'Settings'
            if ($null -ne $set) {
                foreach ($k in @($set.Keys)) {
                    if (Test-ShortcutKey $k) { $shortcuts[$k] = $set[$k] }
                }
            }
        }
        if ($shortcuts.Count -eq 0) { Add-Result "Khong tim thay phim tat cua SketchUp $year." }
    }

    $snap = New-Dict
    $snap['year'] = $year
    $snap['saved_at'] = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    $snap['prefs'] = $prefs
    $snap['shortcuts'] = $shortcuts
    Write-Json (Join-Path $dir 'layout.json') $snap
    $what = @()
    if ($gotLayout) { $what += 'layout' }
    if ($shortcuts.Count -gt 0) { $what += ('phim tat (' + $shortcuts.Count + ' muc)') }
    Add-Result ("Da luu tu SketchUp $year : " + ($(if ($what.Count -gt 0) { $what -join ', ' } else { 'khong co gi' })))
}

# Ghi file JSON qua file tam, kiem tra doc lai duoc roi moi thay the
function Save-JsonChecked([string]$path, $doc, [int]$expectTop) {
    $tmp = "$path.vgdtmp"
    Write-Json $tmp $doc
    $check = Read-Json $tmp
    if ($check.Count -ne $expectTop) { throw "Kiem tra loi: so khoa cap cao nhat thay doi ($($check.Count) khac $expectTop)" }
    Move-Item -LiteralPath $tmp -Destination $path -Force
}

# ---- apply ----
function Invoke-Apply($step, [string]$backupRoot) {
    $year = [string]$step['year']
    $dir = [string]$step['dir']
    $parts = @($step['parts'])
    $snapFile = Join-Path $dir 'layout.json'
    if (-not (Test-Path -LiteralPath $snapFile)) { Add-Result "Khong co snapshot de ap dung ($dir)."; return }
    $snap = Read-Json $snapFile
    $snapYear = [string](Get-Child $snap 'year')
    $stamp = (Get-Date).ToString('yyyyMMdd_HHmmss')
    $bk = Join-Path $backupRoot "$year-$stamp"
    New-Item -ItemType Directory -Force -Path $bk | Out-Null

    $priv = Get-PrivatePrefsPath $year
    $shared = Get-SharedPrefsPath $year
    if (Test-Path -LiteralPath $priv) { Copy-Item -LiteralPath $priv -Destination (Join-Path $bk 'PrivatePreferences.json') -Force }
    if (Test-Path -LiteralPath $shared) { Copy-Item -LiteralPath $shared -Destination (Join-Path $bk 'SharedPreferences.json') -Force }
    foreach ($n in $regNames) { [void](Invoke-Reg @('export', "HKCU\Software\SketchUp\SketchUp $year\$n", (Join-Path $bk "$n.reg"), '/y')) }
    Add-Result "Da sao luu SketchUp $year vao $bk"

    $applied = @()

    # Layout chi ap khi cung phien ban SketchUp (hai ban luu theo kieu khac nhau)
    if ($parts -contains 'layout') {
        if ($snapYear -ne $year) {
            Add-Result ("Bo qua layout: snapshot tu SketchUp " + $snapYear + ", khong ap duoc cho " + $year + '.')
        } else {
            $prefs = Get-Child $snap 'prefs'
            if ($null -ne $prefs -and $prefs.Count -gt 0 -and (Test-Path -LiteralPath $priv)) {
                $doc = Read-Json $priv
                $top = $doc.Count
                $sec = Get-Section $doc 'This Computer Only'
                foreach ($k in @($sec.Keys)) { if (Test-LayoutSection $k) { [void]$sec.Remove($k) } }
                foreach ($k in @($prefs.Keys)) {
                    if ($k -eq 'MainWindow') {
                        $mw = Get-Section $sec 'MainWindow'
                        $srcMw = Get-Child $prefs 'MainWindow'
                        foreach ($mk in @($srcMw.Keys)) {
                            if ($mainWindowKeys -contains $mk) { $mw[$mk] = $srcMw[$mk] }
                        }
                    } elseif (Test-LayoutSection $k) {
                        $sec[$k] = $prefs[$k]
                    }
                }
                Save-JsonChecked $priv $doc $top
                $applied += 'layout (file cai dat)'
            }
            foreach ($n in $regNames) {
                $regFile = Join-Path $dir "$n.reg"
                if (-not (Test-Path -LiteralPath $regFile)) { continue }
                $key = "HKCU\Software\SketchUp\SketchUp $year\$n"
                [void](Invoke-Reg @('delete', $key, '/f'))
                if ((Invoke-Reg @('import', $regFile)) -ne 0) {
                    $old = Join-Path $bk "$n.reg"
                    if (Test-Path -LiteralPath $old) { [void](Invoke-Reg @('import', $old)) }
                    throw "Khong nhap duoc $n vao registry (da khoi phuc tu ban sao luu)."
                }
                $applied += "layout (registry $n)"
            }
        }
    }

    if ($parts -contains 'shortcuts') {
        $sc = Get-Child $snap 'shortcuts'
        if ($null -ne $sc -and $sc.Count -gt 0 -and (Test-Path -LiteralPath $shared)) {
            $doc = Read-Json $shared
            $top = $doc.Count
            $win = Get-Section $doc 'Windows Only'
            $set = Get-Section $win 'Settings'
            foreach ($k in @($set.Keys)) { if (Test-ShortcutKey $k) { [void]$set.Remove($k) } }
            foreach ($k in @($sc.Keys)) { if (Test-ShortcutKey $k) { $set[$k] = $sc[$k] } }
            Save-JsonChecked $shared $doc $top
            $applied += ('phim tat (' + $sc.Count + ' muc)')
        } else {
            Add-Result 'Bo qua phim tat: snapshot khong co phim tat hoac khong tim thay file cai dat dich.'
        }
    }

    if ($applied.Count -gt 0) { Add-Result ("Da ap dung vao SketchUp $year : " + ($applied -join ', ')) }
}

# ---- chinh ----
$job = Read-Json $Job
$script:logPath = [string]$job['log']
$id = [string]$job['id']
$hostPid = [int]$job['sketchup_pid']
$resultPath = [string]$job['result']
$backupRoot = [string]$job['backup_dir']
$restart = [bool]$job['restart']

$exe = $null
try { $exe = (Get-Process -Id $hostPid -ErrorAction Stop).Path } catch { }

$years = @()
foreach ($s in @($job['steps'])) { $years += [string]$s['year'] }
$years = @($years | Select-Object -Unique)

# Cho SketchUp (tien trinh goc va cac ban lien quan) thoat hoan toan
while ($true) {
    if (-not (Test-JobCurrent ([string]$job['job_file']) $id)) { exit 0 }
    $busy = [bool](Get-Process -Id $hostPid -ErrorAction SilentlyContinue)
    foreach ($y in $years) { if (Test-Running $y) { $busy = $true } }
    if (-not $busy) { break }
    Start-Sleep -Seconds 1
}
Start-Sleep -Seconds 2

foreach ($step in @($job['steps'])) {
    try {
        switch ([string]$step['op']) {
            'capture' { Invoke-Capture $step }
            'apply'   { Invoke-Apply $step $backupRoot }
            default   { Add-Result ('Bo qua buoc khong biet: ' + $step['op']) }
        }
    } catch {
        Add-Result ('LOI buoc ' + $step['op'] + ': ' + $_.Exception.Message)
    }
}

try { Remove-Item -LiteralPath ([string]$job['job_file']) -Force -ErrorAction SilentlyContinue } catch { }
try {
    $dirOfResult = Split-Path -Parent $resultPath
    New-Item -ItemType Directory -Force -Path $dirOfResult | Out-Null
    [System.IO.File]::WriteAllText($resultPath, ($script:results -join "`r`n"), $utf8)
} catch { }

if ($restart -and $exe) {
    try { Start-Process -FilePath $exe } catch { Write-Log ('Khong mo lai duoc SketchUp: ' + $_.Exception.Message) }
}
