#Requires -Version 5.1
# Copies the three first-logon scripts from ..\scripts into autounattend.example.xml so the
# example matches the standalone files: the <File> blocks Setup runs at first logon, and the
# generator link in the comment at the top of the XML.
#
# pe.cmd is only compared. The generator stores it as a chain of RunSynchronous commands,
# so if it differs you have to paste it into the generator and download the XML again.
#
#   .\sync-example.ps1          update the example, then verify
#   .\sync-example.ps1 -Check   verify only, exit code 1 if anything differs
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$xmlPath   = Join-Path $PSScriptRoot 'autounattend.example.xml'
$scriptDir = Join-Path $PSScriptRoot '..\scripts'
$names     = '01-perf.ps1', '02-privacy.ps1', '03-interface.ps1'
$utf8      = New-Object System.Text.UTF8Encoding($false)

# escape like the generator does: & < > and non-ASCII as &#xHEX;
function ConvertTo-XmlText([string]$s) {
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $s.ToCharArray()) {
        if     ($ch -eq '&') { [void]$sb.Append('&amp;') }
        elseif ($ch -eq '<') { [void]$sb.Append('&lt;') }
        elseif ($ch -eq '>') { [void]$sb.Append('&gt;') }
        elseif ([int]$ch -gt 127) { [void]$sb.Append('&#x' + ([int]$ch).ToString('X') + ';') }
        else   { [void]$sb.Append($ch) }
    }
    $sb.ToString()
}

# form-encode like the generator link. '--' can't appear inside an XML comment.
function ConvertTo-FormValue([string]$s) {
    $safe = '-_.*~'
    $sb = New-Object System.Text.StringBuilder
    foreach ($b in [System.Text.Encoding]::UTF8.GetBytes($s)) {
        $c = [char]$b
        if (($b -ge 48 -and $b -le 57) -or ($b -ge 65 -and $b -le 90) -or ($b -ge 97 -and $b -le 122) -or ($b -lt 128 -and $safe.Contains($c))) { [void]$sb.Append($c) }
        elseif ($b -eq 32) { [void]$sb.Append('+') }
        else { [void]$sb.Append('%' + $b.ToString('X2')) }
    }
    $sb.ToString().Replace('--', '%2D%2D')
}

function Read-Crlf([string]$path) {
    ([System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)) -replace "`r?`n", "`r`n"
}

$xml = [System.IO.File]::ReadAllText($xmlPath, [System.Text.Encoding]::UTF8)
$eol = if ($xml.Contains("`r`n")) { "`r`n" } else { "`n" }
$differences = 0

# --- the three first-logon scripts ------------------------------------------
$linkValues = @{}
for ($n = 0; $n -lt $names.Count; $n++) {
    $text = Read-Crlf (Join-Path $scriptDir $names[$n])
    $linkValues["FirstLogonScript$n"] = ConvertTo-FormValue $text

    $open = '<File path="C:\Windows\Setup\Scripts\unattend-{0:00}.ps1">' -f ($n + 1)
    $start = $xml.IndexOf($open)
    if ($start -lt 0) { throw "No embedded copy of $($names[$n]) in the example." }
    $bodyStart = $start + $open.Length + $eol.Length
    $bodyEnd = $xml.IndexOf($eol + "`t`t</File>", $bodyStart)
    if ($bodyEnd -lt 0) { throw "Embedded copy of $($names[$n]) has no end tag." }

    $body = (ConvertTo-XmlText $text.TrimEnd("`r", "`n")).Replace("`r`n", $eol)
    if ($xml.Substring($bodyStart, $bodyEnd - $bodyStart) -ceq $body) {
        "{0,-18} embedded copy   identical" -f $names[$n]
    } else {
        $differences++
        "{0,-18} embedded copy   DIFFERS{1}" -f $names[$n], $(if ($Check) { '' } else { ' -> rewritten' })
        $xml = $xml.Substring(0, $bodyStart) + $body + $xml.Substring($bodyEnd)
    }
}

# --- generator link ---------------------------------------------------------
$comment = [regex]::Match($xml, '<!--(https://schneegans\.de/windows/unattend-generator/\?)(.*?)-->')
if (-not $comment.Success) { throw 'Generator link comment not found in the example.' }
$current = @{}
$parts = New-Object System.Collections.Generic.List[string]
foreach ($kv in $comment.Groups[2].Value -split '&') {
    $i = $kv.IndexOf('=')
    $key = $kv.Substring(0, $i)
    $current[$key] = $kv.Substring($i + 1)
    if ($linkValues.ContainsKey($key)) { $kv = "$key=" + $linkValues[$key] }
    $parts.Add($kv)
}
for ($n = 0; $n -lt $names.Count; $n++) {
    $key = "FirstLogonScript$n"
    if (-not $current.ContainsKey($key)) { throw "The generator link has no $key." }
    if ($current[$key] -ceq $linkValues[$key]) {
        "{0,-18} generator link  identical" -f $names[$n]
    } else {
        $differences++
        "{0,-18} generator link  DIFFERS{1}" -f $names[$n], $(if ($Check) { '' } else { ' -> rewritten' })
    }
}
$query = $parts -join '&'
$xml = $xml.Substring(0, $comment.Groups[2].Index) + $query + $xml.Substring($comment.Groups[2].Index + $comment.Groups[2].Length)

# --- pe.cmd: verify only ----------------------------------------------------
$pe = Read-Crlf (Join-Path $PSScriptRoot 'pe.cmd')
$copy = [regex]::Match($xml, '(?s)<PEScriptCopy>\r?\n(.*?)\r?\n\t\t</PEScriptCopy>')
$peCopyOk = $copy.Success -and (($copy.Groups[1].Value -replace "`r?`n", "`r`n") -ceq (ConvertTo-XmlText $pe.TrimEnd("`r", "`n")))
$peLinkOk = $current.ContainsKey('PEScript') -and ($current['PEScript'] -ceq (ConvertTo-FormValue $pe))
"{0,-18} readable copy   {1}" -f 'pe.cmd', $(if ($peCopyOk) { 'identical' } else { 'DIFFERS' })
"{0,-18} generator link  {1}" -f 'pe.cmd', $(if ($peLinkOk) { 'identical' } else { 'DIFFERS' })
$peProblem = -not ($peCopyOk -and $peLinkOk)
if ($peProblem) {
    'pe.cmd cannot be re-embedded by this script. Paste it into the generator (section 3) and download the XML again.'
}

# --- write and verify -------------------------------------------------------
if ($differences -gt 0 -and -not $Check) {
    [System.IO.File]::WriteAllText($xmlPath, $xml, $utf8)
    'autounattend.example.xml written.'
}
$doc = New-Object System.Xml.XmlDocument
$doc.LoadXml([System.IO.File]::ReadAllText($xmlPath, [System.Text.Encoding]::UTF8))
'XML is well-formed.'

if ($peProblem -or ($Check -and $differences -gt 0)) { exit 1 }
