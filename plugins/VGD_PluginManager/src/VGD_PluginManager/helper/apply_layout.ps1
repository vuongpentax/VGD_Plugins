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
# $name la khoa THO (hai dau gach cheo): regex '\\\\' khop hai dau gach cheo lien nhau.
function Test-LayoutSection([string]$name) {
    return ($name -match '^(Qt)?RubyWorkspace\\\\') -or ($name -match '^Workspace\\\\') -or ($name -eq 'ToolbarSettings')
}
# Cung y nghia nhung cho khoa DA GIAI MA (mot dau gach cheo), dung khi doc lai qua JavaScriptSerializer
function Test-LayoutSectionDecoded([string]$name) {
    return ($name -match '^(Qt)?RubyWorkspace\\') -or ($name -match '^Workspace\\') -or ($name -eq 'ToolbarSettings')
}
function Test-ShortcutKey([string]$name) {
    return ($name -match '^(Num_Shortcuts|Shortcut_\d+)$')
}
$mainWindowKeys = @('DockWidgetState', 'ToolBarState')
# PrivatePreferences.json duoc chinh THEO DONG (khong doc-ghi lai ca file) de giu nguyen moi byte ngoai muc layout.
# Khoa muc la van ban tho giua hai dau nhay trong file (vi du RubyWorkspace\\RubyToolBar-59648, hai dau gach cheo).
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

# ---- PrivatePreferences.json: chup/ap layout theo dong (mirror cua PrivateSplice trong tests/support/splice_reference.rb) ----
$scalarRe = '(?:true|false|null|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|"(?:[^"\\]|\\.)*")'

# Khoi "This Computer Only": chi so dong mo, dong dong, thut le
function Find-ComputerBlock($lines) {
    $start = -1
    $indent = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^(\s*)"This Computer Only"\s*:\s*\{\s*$') { $start = $i; $indent = $Matches[1].Length; break }
    }
    if ($start -lt 0) { throw 'Khong thay muc "This Computer Only".' }
    $pat = '^' + (' ' * $indent) + '\},?\s*$'
    $end = -1
    for ($i = $start + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $pat) { $end = $i; break }
    }
    if ($end -lt 0) { throw 'Khong thay cuoi muc "This Computer Only".' }
    return @{ Start = $start; End = $end; Indent = $indent }
}

# Tach cac muc o thut le $entryIndent trong khoang dong from..to. Dong cuoi moi muc da bo dau phay.
function Split-Entries($lines, [int]$from, [int]$to, [int]$entryIndent) {
    $sp = ' ' * $entryIndent
    $keyPat = '^' + $sp + '("(?:[^"\\]|\\.)*")\s*:\s*(.*?)(,?)\s*$'
    $closePat = '^' + $sp + '[\}\]],?\s*$'
    $entries = New-Object 'System.Collections.Generic.List[object]'
    $i = $from
    while ($i -le $to) {
        $l = $lines[$i]
        if ($l.Trim().Length -eq 0) { $i++; continue }
        if (-not ($l -match $keyPat)) { throw ('Khong hieu dong (thut le ' + $entryIndent + ') tai dong ' + ($i + 1)) }
        $keyRaw = $Matches[1]
        $val = $Matches[2]
        $key = $keyRaw.Substring(1, $keyRaw.Length - 2)
        $isBlock = $false
        $end = $i
        if ($val -eq '{' -or $val -eq '[') {
            $isBlock = $true
            $end = -1
            for ($j = $i + 1; $j -le $to; $j++) {
                if ($lines[$j] -match $closePat) { $end = $j; break }
            }
            if ($end -lt 0) { throw ('Muc ' + $key + ' khong co dong dong.') }
        }
        $ent = New-Object 'System.Collections.Generic.List[string]'
        for ($k = $i; $k -le $end; $k++) { $ent.Add($lines[$k]) }
        $lastText = $ent[$ent.Count - 1].TrimEnd()
        if ($lastText.EndsWith(',', [StringComparison]::Ordinal)) { $lastText = $lastText.Substring(0, $lastText.Length - 1) }
        $ent[$ent.Count - 1] = $lastText
        $entries.Add((New-Object PSObject -Property @{ Key = $key; IsBlock = $isBlock; Lines = $ent }))
        $i = $end + 1
    }
    return ,$entries
}

# Khoi phang (chi thuoc tinh vo huong o thut le +4): tra ve cac dong da bo dau phay, hoac $null
function ConvertTo-FlatBlock($lines, [int]$indent) {
    $in1 = ' ' * ($indent + 4)
    $in2 = ' ' * ($indent + 8)
    if ($lines.Count -lt 2) { return $null }
    if (-not ($lines[0] -match ('^' + $in1 + '"(?:[^"\\]|\\.)*"\s*:\s*\{$'))) { return $null }
    if ($lines[$lines.Count - 1] -ne ($in1 + '}')) { return $null }
    $out = New-Object 'System.Collections.Generic.List[string]'
    $out.Add($lines[0])
    $innerPat = '^' + $in2 + '"(?:[^"\\]|\\.)*"\s*:\s*' + $scalarRe + '$'
    for ($i = 1; $i -lt $lines.Count - 1; $i++) {
        $l = $lines[$i]
        if ($l.EndsWith(',', [StringComparison]::Ordinal)) { $l = $l.Substring(0, $l.Length - 1) }
        if (-not ($l -match $innerPat)) { return $null }
        $out.Add($l)
    }
    $out.Add($lines[$lines.Count - 1])
    return ,$out
}

function Get-PrivateLayout([string]$text) {
    $lines = $text -split "`r?`n"
    $cb = Find-ComputerBlock $lines
    $blocks = New-Dict
    $mw = New-Dict
    $skipped = 0
    foreach ($e in (Split-Entries $lines ($cb.Start + 1) ($cb.End - 1) ($cb.Indent + 4))) {
        if (-not $e.IsBlock) { continue }
        if (Test-LayoutSection $e.Key) {
            $flat = ConvertTo-FlatBlock $e.Lines $cb.Indent
            if ($null -eq $flat) { $skipped++ } else { $blocks[$e.Key] = [string[]]$flat.ToArray() }
        } elseif ($e.Key -eq 'MainWindow') {
            foreach ($ie in (Split-Entries $e.Lines 1 ($e.Lines.Count - 2) ($cb.Indent + 8))) {
                if ((-not $ie.IsBlock) -and ($mainWindowKeys -contains $ie.Key)) { $mw[$ie.Key] = $ie.Lines[0].Trim() }
            }
        }
    }
    return @{ Blocks = $blocks; MainWindow = $mw; Skipped = $skipped }
}

# Danh sach cac muc (moi muc la List[string]) -> cac dong, them dau phay vao dong cuoi cua moi muc tru muc cuoi
function Join-EntryLines($entryLines) {
    $out = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $entryLines.Count; $i++) {
        $ls = $entryLines[$i]
        for ($k = 0; $k -lt $ls.Count; $k++) {
            if ($k -eq $ls.Count - 1 -and $i -lt $entryLines.Count - 1) { $out.Add($ls[$k] + ',') } else { $out.Add($ls[$k]) }
        }
    }
    return ,$out
}

# Khoi layout moi: dong dau, thuoc tinh (them dau phay tru dong cuoi), dong dong
function Format-BlockLines($blockLines) {
    $out = New-Object 'System.Collections.Generic.List[string]'
    $out.Add($blockLines[0])
    $n = $blockLines.Count - 2
    for ($i = 1; $i -le $n; $i++) {
        if ($i -lt $n) { $out.Add($blockLines[$i] + ',') } else { $out.Add($blockLines[$i]) }
    }
    $out.Add($blockLines[$blockLines.Count - 1])
    return ,$out
}

function New-EntryObject([string]$key, $lines) {
    return (New-Object PSObject -Property @{ Key = $key; IsBlock = $true; Lines = $lines })
}

# Thay Dock/ToolBarState trong muc MainWindow, giu nguyen cac khoa khac (vi du Geometry cua may nay)
function Set-MainWindowEntry($entry, $mw, [int]$entryIndent) {
    $pad = ' ' * ($entryIndent + 4)
    $items = New-Object 'System.Collections.Generic.List[object]'
    $done = @{}
    foreach ($ie in (Split-Entries $entry.Lines 1 ($entry.Lines.Count - 2) ($entryIndent + 4))) {
        if ((-not $ie.IsBlock) -and $mw.ContainsKey($ie.Key)) {
            $one = New-Object 'System.Collections.Generic.List[string]'
            $one.Add($pad + $mw[$ie.Key])
            $items.Add($one)
            $done[$ie.Key] = $true
        } else {
            $items.Add($ie.Lines)
        }
    }
    $mk = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in @($mw.Keys)) { $mk.Add($k) }
    $mkArr = $mk.ToArray()
    [Array]::Sort($mkArr, [StringComparer]::Ordinal)
    foreach ($k in $mkArr) {
        if (-not $done.ContainsKey($k)) {
            $one = New-Object 'System.Collections.Generic.List[string]'
            $one.Add($pad + $mw[$k])
            $items.Add($one)
        }
    }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.Add($entry.Lines[0])
    $lines.AddRange((Join-EntryLines $items))
    $lines.Add($entry.Lines[$entry.Lines.Count - 1])
    return (New-EntryObject 'MainWindow' $lines)
}

function Set-PrivateLayout([string]$text, $blocks, $mw) {
    if ($null -eq $blocks) { $blocks = New-Dict }
    if ($null -eq $mw) { $mw = New-Dict }
    $eol = "`n"
    if ($text.Contains("`r`n")) { $eol = "`r`n" }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.AddRange([string[]]($text -split "`r?`n"))
    $cb = Find-ComputerBlock $lines
    $entryIndent = $cb.Indent + 4

    $keyList = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in @($blocks.Keys)) {
        if (-not (Test-LayoutSection $k)) { continue }
        $flat = ConvertTo-FlatBlock @($blocks[$k]) $cb.Indent
        if ($null -eq $flat) { throw ('Snapshot co muc layout khong hop le: ' + $k) }
        if (-not ($flat[0].TrimStart().StartsWith('"' + $k + '"', [StringComparison]::Ordinal))) { throw ('Dong dau cua muc layout khong khop khoa: ' + $k) }
        $keyList.Add($k)
    }
    $keys = $keyList.ToArray()
    [Array]::Sort($keys, [StringComparer]::Ordinal)

    $newEntries = New-Object 'System.Collections.Generic.List[object]'
    $insertAt = -1
    $mwDone = $false
    foreach ($e in (Split-Entries $lines ($cb.Start + 1) ($cb.End - 1) $entryIndent)) {
        if ($e.IsBlock -and (Test-LayoutSection $e.Key)) {
            if ($insertAt -lt 0) { $insertAt = $newEntries.Count }
            continue
        }
        if ($e.IsBlock -and $e.Key -eq 'MainWindow' -and $mw.Count -gt 0) {
            $newEntries.Add((Set-MainWindowEntry $e $mw $entryIndent))
            $mwDone = $true
            continue
        }
        $newEntries.Add($e)
    }
    if ($insertAt -lt 0) { $insertAt = $newEntries.Count }
    $ins = New-Object 'System.Collections.Generic.List[object]'
    foreach ($k in $keys) { $ins.Add((New-EntryObject $k (Format-BlockLines @($blocks[$k])))) }
    $newEntries.InsertRange($insertAt, $ins)
    if ((-not $mwDone) -and $mw.Count -gt 0) {
        $pad = ' ' * ($entryIndent + 4)
        $mk = New-Object 'System.Collections.Generic.List[string]'
        foreach ($k in @($mw.Keys)) { $mk.Add($k) }
        $mkArr = $mk.ToArray()
        [Array]::Sort($mkArr, [StringComparer]::Ordinal)
        $items = New-Object 'System.Collections.Generic.List[object]'
        foreach ($k in $mkArr) {
            $one = New-Object 'System.Collections.Generic.List[string]'
            $one.Add($pad + $mw[$k])
            $items.Add($one)
        }
        $ml = New-Object 'System.Collections.Generic.List[string]'
        $ml.Add((' ' * $entryIndent) + '"MainWindow": {')
        $ml.AddRange((Join-EntryLines $items))
        $ml.Add((' ' * $entryIndent) + '}')
        $newEntries.Add((New-EntryObject 'MainWindow' $ml))
    }
    $all = New-Object 'System.Collections.Generic.List[object]'
    foreach ($e in $newEntries) { $all.Add($e.Lines) }
    $joined = Join-EntryLines $all
    $lines.RemoveRange($cb.Start + 1, $cb.End - $cb.Start - 1)
    $lines.InsertRange($cb.Start + 1, $joined)
    return ($lines -join $eol)
}

# Kiem tra truoc khi thay file: JSON doc lai duoc, so khoa cap cao nhat khong doi, moi muc ngoai layout va ngoai
# MainWindow giong het truoc, cac muc layout moi co mat dung, MainWindow co gia tri moi. Chi sau do moi ghi.
function Save-PrivateChecked([string]$path, [string]$oldText, [string]$newText, $blocks, $mw) {
    $o = $ser.DeserializeObject($oldText)
    $n = $ser.DeserializeObject($newText)
    if ($n.Count -ne $o.Count) { throw 'Kiem tra loi: so khoa cap cao nhat thay doi.' }
    $os = Get-Child $o 'This Computer Only'
    $ns = Get-Child $n 'This Computer Only'
    foreach ($k in @($os.Keys)) {
        if ((Test-LayoutSectionDecoded $k) -or $k -eq 'MainWindow') { continue }
        if (-not $ns.ContainsKey($k)) { throw ('Kiem tra loi: mat muc ' + $k) }
        if ($ser.Serialize($os[$k]) -ne $ser.Serialize($ns[$k])) { throw ('Kiem tra loi: muc ' + $k + ' bi thay doi.') }
    }
    $want = 0
    foreach ($k in @($blocks.Keys)) {
        if (-not (Test-LayoutSection $k)) { continue }
        $dec = $ser.DeserializeObject('"' + $k + '"')
        if (-not $ns.ContainsKey($dec)) { throw ('Kiem tra loi: thieu muc layout ' + $dec) }
        $want++
    }
    $have = 0
    foreach ($k in @($ns.Keys)) { if (Test-LayoutSectionDecoded $k) { $have++ } }
    if ($have -ne $want) { throw ('Kiem tra loi: so muc layout ' + $have + ' khac ' + $want) }
    if ($mw.Count -gt 0) {
        $nmw = Get-Child $ns 'MainWindow'
        foreach ($k in @($mw.Keys)) {
            $expect = (Get-Child ($ser.DeserializeObject('{' + $mw[$k] + '}')) $k)
            if ([string](Get-Child $nmw $k) -ne [string]$expect) { throw ('Kiem tra loi: MainWindow ' + $k + ' khong khop.') }
        }
    }
    $tmp = "$path.vgdtmp"
    [System.IO.File]::WriteAllText($tmp, $newText, $utf8)
    Move-Item -LiteralPath $tmp -Destination $path -Force
}

# ---- capture ----
function Invoke-Capture($step) {
    $year = [string]$step['year']
    $dir = [string]$step['dir']
    $parts = @($step['parts'])
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Filter '*.reg' -ErrorAction SilentlyContinue)) { Remove-Item -LiteralPath $f.FullName -Force }

    $blocks = New-Dict
    $mwOut = New-Dict
    $shortcuts = New-Dict
    $gotLayout = $false

    if ($parts -contains 'layout') {
        $priv = Get-PrivatePrefsPath $year
        if (Test-Path -LiteralPath $priv) {
            $pl = Get-PrivateLayout ([System.IO.File]::ReadAllText($priv, $utf8))
            $blocks = $pl.Blocks
            $mwOut = $pl.MainWindow
            if ($pl.Skipped -gt 0) { Add-Result ('Bo qua ' + $pl.Skipped + ' muc layout khong dung dinh dang phang.') }
        }
        foreach ($n in $regNames) {
            $key = "HKCU\Software\SketchUp\SketchUp $year\$n"
            if ((Invoke-Reg @('query', $key)) -eq 0) {
                if ((Invoke-Reg @('export', $key, (Join-Path $dir "$n.reg"), '/y')) -eq 0) { $gotLayout = $true }
            }
        }
        if ($blocks.Count -gt 0 -or $mwOut.Count -gt 0) { $gotLayout = $true }
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
    $snap['format'] = 2
    $snap['blocks'] = $blocks
    $snap['main_window'] = $mwOut
    $snap['shortcuts'] = $shortcuts
    Write-Json (Join-Path $dir 'layout.json') $snap
    $what = @()
    if ($gotLayout) { $what += 'layout' }
    if ($shortcuts.Count -gt 0) { $what += ('phim tat (' + $shortcuts.Count + ' muc)') }
    Add-Result ("Da luu tu SketchUp $year : " + ($(if ($what.Count -gt 0) { $what -join ', ' } else { 'khong co gi' })))
}

# Chuoi JSON: thoat dau nhay kep, gach cheo nguoc va ky tu dieu khien; giu nguyen ky tu Unicode (tieng Viet)
function ConvertTo-JsonString([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append('"')
    foreach ($ch in $s.ToCharArray()) {
        $code = [int]$ch
        if ($code -eq 34) { [void]$sb.Append('\"') }
        elseif ($code -eq 92) { [void]$sb.Append('\\') }
        elseif ($code -lt 32) { [void]$sb.Append(('\u{0:x4}' -f $code)) }
        else { [void]$sb.Append($ch) }
    }
    [void]$sb.Append('"')
    return $sb.ToString()
}

# Thay cac dong Num_Shortcuts / Shortcut_N trong khoi "Windows Only" > "Settings" bang cac dong moi,
# giu nguyen moi byte khac cua file (khong doc-ghi lai JSON nen so 24.0 khong bi doi thanh 24).
# Khoi Settings phai gom cac dong phang dang  "khoa": gia_tri  ; neu khong thi bao loi va khong sua.
# Phai khop voi Splice.apply trong tests/support/splice_reference.rb.
function Set-ShortcutLines([string]$text, $shortcuts) {
    $eol = "`n"
    if ($text.Contains("`r`n")) { $eol = "`r`n" }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    $lines.AddRange([string[]]($text -split "`r?`n"))

    $winIdx = -1
    $winIndent = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^(\s*)"Windows Only"\s*:\s*\{\s*$') { $winIdx = $i; $winIndent = $Matches[1].Length; break }
    }
    if ($winIdx -lt 0) { throw 'Khong thay muc "Windows Only" trong SharedPreferences.json.' }

    $setIdx = -1
    $setIndent = 0
    for ($i = $winIdx + 1; $i -lt $lines.Count; $i++) {
        $l = $lines[$i]
        if ($l -match '^(\s*)"Settings"\s*:\s*\{\s*$') { $setIdx = $i; $setIndent = $Matches[1].Length; break }
        if ($l -match '^(\s*)\S') { if ($Matches[1].Length -le $winIndent) { break } }
    }
    if ($setIdx -lt 0) { throw 'Khong thay muc "Settings" trong "Windows Only".' }

    $endIdx = -1
    for ($i = $setIdx + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^(\s*)\}\s*,?\s*$') { if ($Matches[1].Length -eq $setIndent) { $endIdx = $i; break } }
    }
    if ($endIdx -lt 0) { throw 'Khong thay cuoi khoi "Settings".' }

    $keep = New-Object 'System.Collections.Generic.List[string]'
    $insertAt = -1
    $indent = $null
    for ($i = $setIdx + 1; $i -lt $endIdx; $i++) {
        $l = $lines[$i]
        if ($l.Trim().Length -eq 0) { continue }
        if (-not ($l -match '^(\s+)("(?:[^"\\]|\\.)*")\s*:\s*(.*?)(,?)\s*$')) { throw ('Khong hieu dong trong Settings: ' + $l) }
        $ind = $Matches[1]
        $keyRaw = $Matches[2]
        $val = $Matches[3]
        if ($val -match '^[\{\[]') { throw 'Settings co muc long nhau, khong chinh theo dong duoc.' }
        if ($null -eq $indent) { $indent = $ind }
        $name = $keyRaw.Substring(1, $keyRaw.Length - 2)
        if (Test-ShortcutKey $name) {
            if ($insertAt -lt 0) { $insertAt = $keep.Count }
            continue
        }
        $orig = $l.TrimEnd()
        if ($orig.EndsWith(',', [StringComparison]::Ordinal)) { $orig = $orig.Substring(0, $orig.Length - 1) }
        $keep.Add($orig)
    }
    if ($null -eq $indent) { $indent = ' ' * ($setIndent + 4) }
    if ($insertAt -lt 0) { $insertAt = $keep.Count }

    $names = New-Object 'System.Collections.Generic.List[string]'
    $count = 0
    foreach ($k in @($shortcuts.Keys)) {
        if (-not (Test-ShortcutKey $k)) { continue }
        $names.Add($k)
        if ($k -ne 'Num_Shortcuts') { $count++ }
    }
    $arr = $names.ToArray()
    [Array]::Sort($arr, [StringComparer]::Ordinal)
    $newLines = New-Object 'System.Collections.Generic.List[string]'
    foreach ($k in $arr) {
        $v = $shortcuts[$k]
        if ($k -eq 'Num_Shortcuts') { $valText = $count.ToString([System.Globalization.CultureInfo]::InvariantCulture) }
        elseif ($v -is [string]) { $valText = ConvertTo-JsonString $v }
        else { $valText = ([long]$v).ToString([System.Globalization.CultureInfo]::InvariantCulture) }
        $newLines.Add($indent + (ConvertTo-JsonString $k) + ': ' + $valText)
    }
    $keep.InsertRange($insertAt, $newLines)

    $outLines = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $keep.Count; $i++) {
        if ($i -lt $keep.Count - 1) { $outLines.Add($keep[$i] + ',') } else { $outLines.Add($keep[$i]) }
    }
    $lines.RemoveRange($setIdx + 1, $endIdx - $setIdx - 1)
    $lines.InsertRange($setIdx + 1, $outLines)
    return ($lines -join $eol)
}

# Ghi file van ban qua file tam sau khi kiem tra: phim tat doc lai dung nhu mong muon, so khoa cap cao nhat khong doi
function Save-ShortcutsChecked([string]$path, [string]$oldText, [string]$newText, $shortcuts) {
    $oldDoc = $ser.DeserializeObject($oldText)
    $newDoc = $ser.DeserializeObject($newText)
    if ($newDoc.Count -ne $oldDoc.Count) { throw 'Kiem tra loi: so khoa cap cao nhat thay doi.' }
    $set = Get-Child (Get-Child $newDoc 'Windows Only') 'Settings'
    $got = 0
    foreach ($k in @($shortcuts.Keys)) {
        if (-not (Test-ShortcutKey $k)) { continue }
        if ($k -eq 'Num_Shortcuts') { continue }
        $got++
        if ([string](Get-Child $set $k) -ne [string]$shortcuts[$k]) { throw ('Kiem tra loi: phim tat ' + $k + ' khong khop.') }
    }
    $num = Get-Child $set 'Num_Shortcuts'
    if ([int]$num -ne $got) { throw 'Kiem tra loi: Num_Shortcuts khong khop so phim tat.' }
    $tmp = "$path.vgdtmp"
    [System.IO.File]::WriteAllText($tmp, $newText, $utf8)
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
            $blocks = Get-Child $snap 'blocks'
            $mwSnap = Get-Child $snap 'main_window'
            $hasBlocks = ($null -ne $blocks -and $blocks.Count -gt 0)
            $hasMw = ($null -ne $mwSnap -and $mwSnap.Count -gt 0)
            if (($hasBlocks -or $hasMw) -and (Test-Path -LiteralPath $priv)) {
                if ($null -eq $blocks) { $blocks = New-Dict }
                if ($null -eq $mwSnap) { $mwSnap = New-Dict }
                $oldText = [System.IO.File]::ReadAllText($priv, $utf8)
                $newText = Set-PrivateLayout $oldText $blocks $mwSnap
                Save-PrivateChecked $priv $oldText $newText $blocks $mwSnap
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
            $oldText = [System.IO.File]::ReadAllText($shared, $utf8)
            $newText = Set-ShortcutLines $oldText $sc
            Save-ShortcutsChecked $shared $oldText $newText $sc
            $applied += ('phim tat (' + (@($sc.Keys | Where-Object { $_ -ne 'Num_Shortcuts' }).Count) + ' muc)')
        } else {
            Add-Result 'Bo qua phim tat: snapshot khong co phim tat hoac khong tim thay file cai dat dich.'
        }
    }

    if ($applied.Count -gt 0) { Add-Result ("Da ap dung vao SketchUp $year : " + ($applied -join ', ')) }
}

# ---- chinh ----
# Nhat ky du phong: neu khong doc duoc job thi van ghi duoc vi sao helper chet
$script:logPath = Join-Path $env:APPDATA 'SketchUp\VGD_PluginManager\migrator.log'
Write-Log ('bat dau: PowerShell ' + $PSVersionTable.PSVersion + ', job=' + $Job)
try {
    $jobData = Read-Json $Job
} catch {
    Write-Log ('LOI doc file job: ' + $_.Exception.Message)
    exit 1
}
if ($jobData['log']) { $script:logPath = [string]$jobData['log'] }
Write-Log ('da doc job: id=' + $jobData['id'] + ', cho SketchUp pid=' + $jobData['sketchup_pid'] + ', so buoc=' + @($jobData['steps']).Count + ', mo lai=' + $jobData['restart'])
$id = [string]$jobData['id']
$hostPid = [int]$jobData['sketchup_pid']
$resultPath = [string]$jobData['result']
$backupRoot = [string]$jobData['backup_dir']
$restart = [bool]$jobData['restart']
if ($hostPid -le 0 -or -not $id) {
    Write-Log 'LOI: file job thieu id hoac pid cua SketchUp, dung lai.'
    exit 1
}

$exe = $null
try { $exe = (Get-Process -Id $hostPid -ErrorAction Stop).Path } catch { }

$years = @()
foreach ($s in @($jobData['steps'])) { $years += [string]$s['year'] }
$years = @($years | Select-Object -Unique)

# Cho SketchUp (tien trinh goc va cac ban lien quan) thoat hoan toan
$waited = 0
while ($true) {
    if (-not (Test-JobCurrent ([string]$jobData['job_file']) $id)) { exit 0 }
    $busy = [bool](Get-Process -Id $hostPid -ErrorAction SilentlyContinue)
    foreach ($y in $years) { if (Test-Running $y) { $busy = $true } }
    if (-not $busy) { break }
    $waited++
    if ($waited -eq 1 -or $waited % 60 -eq 0) { Write-Log ('dang cho SketchUp dong (' + $waited + ' giay)') }
    Start-Sleep -Seconds 1
}
Write-Log 'SketchUp da dong, bat dau thuc hien'
Start-Sleep -Seconds 2

foreach ($step in @($jobData['steps'])) {
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

try { Remove-Item -LiteralPath ([string]$jobData['job_file']) -Force -ErrorAction SilentlyContinue } catch { }
try {
    $dirOfResult = Split-Path -Parent $resultPath
    New-Item -ItemType Directory -Force -Path $dirOfResult | Out-Null
    [System.IO.File]::WriteAllText($resultPath, ($script:results -join "`r`n"), $utf8)
} catch { }

if ($restart -and $exe) {
    try { Start-Process -FilePath $exe; Write-Log ('da mo lai SketchUp: ' + $exe) } catch { Write-Log ('Khong mo lai duoc SketchUp: ' + $_.Exception.Message) }
} else {
    Write-Log ('khong mo lai SketchUp (restart=' + $restart + ', exe=' + $exe + ')')
}
Write-Log 'helper ket thuc'
