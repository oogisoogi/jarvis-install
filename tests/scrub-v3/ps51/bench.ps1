# bench.ps1 — 가림 v3 를 PowerShell 5.1 에서 어떤 모양으로 짜야 하는지 재는 일회용 측정 스크립트(제품 코드 아님 · TICKET=scrub-redesign-1116).
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File ps51-bench\bench.ps1            # windows-latest 러너 · 5.1
#   pwsh -NoProfile -File ps51-bench/bench.ps1 -Sizes 65536                                  # 다른 기계에서 미리 돌려 보기
#
# 재는 모양 셋(답은 셋 다 참조 모델 model/scrub-v3.js 와 같아야 한다 — expected.json 의 sha256 과 견준다):
#   csharp   = Add-Type 인라인 C#(자동기계 + 정규식 + 합치기 전부 C#). 컴파일 시간·성공 여부도 따로 적는다.
#   ps-ac    = 순수 PowerShell. 이름 찾기 = 글자마다 도는 Aho-Corasick 반복(선형이 증명되지만 5.1 의 반복이 느리다).
#   ps-regex = 순수 PowerShell + .NET 메서드 조합. 이름 찾기 = 앞보기 정규식 한 번 + 맞은 자리마다 반복(보통 글은 빠르지만 최악은 길이 x 이름 글자 합).
#
# 출력(탭으로 가른 줄 · 그대로 붙여 주면 된다):
#   ENV      <항목>  <값>
#   ADDTYPE  ok|FAIL  <컴파일 ms>  <오류 한 줄>
#   VECTORS  <모양>  <통과>/<전체>
#   RESULT   <모양>  <꼴>  <글자 수>  <ms>  <sha256 앞 16자>  match|MISMATCH|TIMEOUT|SKIP|ERROR
#   SUMMARY  <모양>  mismatch=<n>  timeout=<n>  skip=<n>  max_ms=<n>
param(
    [int]$BudgetSeconds = 60,
    [string]$Shapes = 'csharp,ps-ac,ps-regex',
    [string]$Sizes = '',
    [string]$Cases = '',
    [string]$RenderMode = 'substring'
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$utf8 = New-Object System.Text.UTF8Encoding $false
$spec = [System.IO.File]::ReadAllText((Join-Path $here 'spec.json'), $utf8) | ConvertFrom-Json
$expected = [System.IO.File]::ReadAllText((Join-Path $here 'expected.json'), $utf8) | ConvertFrom-Json
$vectors = [System.IO.File]::ReadAllText((Join-Path $here 'vectors.json'), $utf8) | ConvertFrom-Json

$script:V3Sources = [string[]]@($spec.sources)
$script:V3Ranks = [int[]]@($spec.ranks)
$script:V3Marks = [string[]]@($spec.marks)
$script:V3NamesMax = [int]$spec.limits.NAMES_MAX
$script:V3NameUnitsMax = [int]$spec.limits.NAME_UNITS_MAX
$script:V3RescansMax = [int]$spec.limits.RESCANS_MAX
$script:V3NameRank = 5
$script:V3FullRank = 6
$script:V3Rules = @($script:V3Sources | ForEach-Object { New-Object System.Text.RegularExpressions.Regex ([string]$_) })
$script:V3RegexTimeout = [TimeSpan]::FromSeconds($BudgetSeconds)
$script:V3RenderMode = $RenderMode

function Write-Row([string[]]$Cells) { [Console]::Out.WriteLine(($Cells -join "`t")) }

# ---------------------------------------------------------------- 순수 PowerShell 공용 부분
# 0단계 정리 — 순서가 명세다(3회차 · codex 2R 발견 1): NUL 제거가 먼저, 그 결과에 짝 잃은 서러게이트를 U+FFFD 로(.NET 정규식은 코드 단위로 본다)
$script:V3Lone = New-Object System.Text.RegularExpressions.Regex '[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]'
function Get-V3Tidy([string]$Value) {
    $clean = $Value.Replace(([string][char]0), '')
    return $script:V3Lone.Replace($clean, ([string][char]0xFFFD))
}

function Add-V3StructSpans([string]$Text, $SpanS, $SpanE, $SpanR) {
    for ($r = 0; $r -lt $script:V3Rules.Count; $r++) {
        $rank = $script:V3Ranks[$r]
        foreach ($m in $script:V3Rules[$r].Matches($Text)) { $SpanS.Add($m.Index); $SpanE.Add($m.Index + $m.Length); $SpanR.Add($rank) }
    }
}

# 겹치거나 맞닿은 구간 = 한 덩이 · 순위 = 가장 작은 것. 결과는 $script:RunS/RunE/RunR.
function Merge-V3Spans($SpanS, $SpanE, $SpanR) {
    $script:RunS = New-Object 'System.Collections.Generic.List[int]'
    $script:RunE = New-Object 'System.Collections.Generic.List[int]'
    $script:RunR = New-Object 'System.Collections.Generic.List[int]'
    $n = $SpanS.Count
    if ($n -eq 0) { return }
    $keys = $SpanS.ToArray()
    $idx = New-Object int[] $n
    for ($i = 0; $i -lt $n; $i++) { $idx[$i] = $i }
    [Array]::Sort($keys, $idx)
    $cs = $keys[0]; $ce = $SpanE[$idx[0]]; $cr = $SpanR[$idx[0]]
    for ($i = 1; $i -lt $n; $i++) {
        $j = $idx[$i]
        $s = $keys[$i]
        if ($s -le $ce) {
            if ($SpanE[$j] -gt $ce) { $ce = $SpanE[$j] }
            if ($SpanR[$j] -lt $cr) { $cr = $SpanR[$j] }
        } else {
            $script:RunS.Add($cs); $script:RunE.Add($ce); $script:RunR.Add($cr)
            $cs = $s; $ce = $SpanE[$j]; $cr = $SpanR[$j]
        }
    }
    $script:RunS.Add($cs); $script:RunE.Add($ce); $script:RunR.Add($cr)
}

function Get-V3Rendered([string]$Text) {
    $count = $script:RunS.Count
    $script:MarkS = New-Object int[] $count
    $script:MarkE = New-Object int[] $count
    $sb = New-Object System.Text.StringBuilder
    $cursor = 0
    for ($k = 0; $k -lt $count; $k++) {
        # pwsh 7.3+ 은 윈도에서 .NET 메서드 호출을 인자와 함께 백신 창구(AMSI)에 알린다(추정 원인) — 90만 자 글을 덩이마다 인자로 넘기면 덩이 수 x 글 길이가 된다.
        # 그래서 글은 「받는 쪽」으로만 쓴다: Substring 으로 조각을 꺼내 넘긴다.
        if ($script:V3RenderMode -eq 'range') { [void]$sb.Append($Text, $cursor, $script:RunS[$k] - $cursor) }
        else { [void]$sb.Append($Text.Substring($cursor, $script:RunS[$k] - $cursor)) }
        $script:MarkS[$k] = $sb.Length
        [void]$sb.Append($script:V3Marks[$script:RunR[$k]])
        $script:MarkE[$k] = $sb.Length
        $cursor = $script:RunE[$k]
    }
    [void]$sb.Append($Text.Substring($cursor))
    return $sb.ToString()
}

# 가린 글의 자리 -> 원문 자리(표식 안이면 그 덩이의 시작 또는 끝)
function Get-V3Original([int]$Pos, [bool]$IsEnd) {
    $k = [Array]::BinarySearch($script:MarkS, $Pos)
    if ($k -lt 0) { $k = (-bnot $k) - 1 }
    if ($k -lt 0) { if ($IsEnd) { return $Pos + 1 } else { return $Pos } }
    if ($Pos -lt $script:MarkE[$k]) { if ($IsEnd) { return $script:RunE[$k] } else { return $script:RunS[$k] } }
    $at = $script:RunE[$k] + ($Pos - $script:MarkE[$k])
    if ($IsEnd) { return $at + 1 } else { return $at }
}

# 이름 찾기 1 — 글자마다 도는 Aho-Corasick(순수 PowerShell)
function Add-V3NameSpansAc([string]$Text, $Names, $SpanS, $SpanE, $SpanR) {
    if ($Names.Count -eq 0) { return }
    $goto = New-Object 'System.Collections.Generic.Dictionary[long,int]'
    $fail = New-Object 'System.Collections.Generic.List[int]'
    $longest = New-Object 'System.Collections.Generic.List[int]'
    $kids = New-Object 'System.Collections.Generic.List[System.Collections.Generic.List[int]]'
    $fail.Add(0); $longest.Add(0); $kids.Add((New-Object 'System.Collections.Generic.List[int]'))
    foreach ($name in $Names) {
        $state = 0
        foreach ($ch in $name.ToCharArray()) {
            $unit = [int]$ch
            $key = ([long]$state * 65536) + $unit
            $to = 0
            if (-not $goto.TryGetValue($key, [ref]$to)) {
                $to = $fail.Count
                $fail.Add(0); $longest.Add(0); $kids.Add((New-Object 'System.Collections.Generic.List[int]'))
                $goto[$key] = $to
                $kids[$state].Add($unit)
            }
            $state = $to
        }
        if ($name.Length -gt $longest[$state]) { $longest[$state] = $name.Length }
    }
    $queue = New-Object 'System.Collections.Generic.List[int]'
    foreach ($unit in $kids[0]) { $queue.Add($goto[[long]$unit]) }
    for ($head = 0; $head -lt $queue.Count; $head++) {
        $state = $queue[$head]
        foreach ($unit in $kids[$state]) {
            $to = $goto[([long]$state * 65536) + $unit]
            $f = $fail[$state]
            $via = 0
            while ($f -ne 0 -and -not $goto.ContainsKey(([long]$f * 65536) + $unit)) { $f = $fail[$f] }
            if ($goto.TryGetValue(([long]$f * 65536) + $unit, [ref]$via) -and $via -ne $to) { $fail[$to] = $via } else { $fail[$to] = 0 }
            if ($longest[$fail[$to]] -gt $longest[$to]) { $longest[$to] = $longest[$fail[$to]] }
            $queue.Add($to)
        }
    }
    $failA = $fail.ToArray()
    $longA = $longest.ToArray()
    $chars = $Text.ToCharArray()
    $n = $chars.Length
    $state = 0
    $curS = -1; $curE = -1
    $to = 0
    # 뿌리 상태에서는 「어느 이름의 첫 글자」가 나올 때까지 .NET 이 건너뛴다 — 뜻은 같고(뿌리에서 갈 곳 없는 글자는 상태를 바꾸지 않는다) 보통 글에서 반복 횟수가 준다
    $rootChars = New-Object char[] ($kids[0].Count)
    for ($k = 0; $k -lt $kids[0].Count; $k++) { $rootChars[$k] = [char]$kids[0][$k] }
    for ($i = 0; $i -lt $n; $i++) {
        if ($state -eq 0) {
            $i = $Text.IndexOfAny($rootChars, $i)
            if ($i -lt 0) { break }
        }
        $unit = [int]$chars[$i]
        while ($state -ne 0 -and -not $goto.ContainsKey(([long]$state * 65536) + $unit)) { $state = $failA[$state] }
        if ($goto.TryGetValue(([long]$state * 65536) + $unit, [ref]$to)) { $state = $to } else { $state = 0 }
        $len = $longA[$state]
        if ($len -eq 0) { continue }
        $start = $i + 1 - $len
        # 모델(model/scrub-v3.js nameSpans)과 같은 스택 합치기(3회차 · codex 2R 포팅 주의): 지금 구간(curS·curE)이 스택의 꼭대기다.
        #   긴 이름이 끝나며 시작 자리가 앞으로 당겨지면, 이미 넘긴 앞 구간들 가운데 닿는 것을 꺼내 합친다 — 그래야 목록이 시작 자리 순이다.
        #   (2회차 꼴은 꼭대기 하나만 봐서 "Q Q Q Z" · 이름 Q·"Q Q Q Z" 에서 [0,1] [2,3] [0,7] 을 냈다 — 정렬이 그것을 가렸다.)
        if ($curE -ge 0 -and $start -le $curE) {
            if ($start -lt $curS) {
                $curS = $start
                $top = $SpanS.Count - 1
                while ($top -ge 0 -and $SpanE[$top] -ge $curS) {
                    if ($SpanS[$top] -lt $curS) { $curS = $SpanS[$top] }
                    $SpanS.RemoveAt($top); $SpanE.RemoveAt($top); $SpanR.RemoveAt($top)
                    $top--
                }
            }
            $curE = $i + 1
        } else {
            if ($curE -ge 0) { $SpanS.Add($curS); $SpanE.Add($curE); $SpanR.Add($script:V3NameRank) }
            $curS = $start; $curE = $i + 1
        }
    }
    if ($curE -ge 0) { $SpanS.Add($curS); $SpanE.Add($curE); $SpanR.Add($script:V3NameRank) }
}

# 이름 찾기 2 — 앞보기 정규식 한 번(.NET 이 훑는다) + 맞은 자리마다 PowerShell 반복
function Add-V3NameSpansRegex([string]$Text, $Names, $SpanS, $SpanE, $SpanR) {
    if ($Names.Count -eq 0) { return }
    $sorted = @($Names | Sort-Object -Property Length -Descending | ForEach-Object { [regex]::Escape($_) })
    $re = New-Object System.Text.RegularExpressions.Regex (('(?=(' + ($sorted -join '|') + '))'), [System.Text.RegularExpressions.RegexOptions]::None, $script:V3RegexTimeout)
    $curS = -1; $curE = -1
    $m = $re.Match($Text)
    while ($m.Success) {
        $start = $m.Index
        $end = $start + $m.Groups[1].Length
        if ($curE -ge 0 -and $start -le $curE) {
            if ($end -gt $curE) { $curE = $end }
        } else {
            if ($curE -ge 0) { $SpanS.Add($curS); $SpanE.Add($curE); $SpanR.Add($script:V3NameRank) }
            $curS = $start; $curE = $end
        }
        $m = $m.NextMatch()
    }
    if ($curE -ge 0) { $SpanS.Add($curS); $SpanE.Add($curE); $SpanR.Add($script:V3NameRank) }
}

function Invoke-V3ScrubPs([string]$Text, [string[]]$Names, [string]$Finder) {
    $Text = Get-V3Tidy $Text
    $script:V3Full = $false
    try {
        $seen = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::Ordinal)
        $list = New-Object 'System.Collections.Generic.List[string]'
        $units = 0
        foreach ($raw in @($Names)) {
            if ($null -eq $raw) { continue }
            $name = Get-V3Tidy ([string]$raw)
            if ($name.Length -eq 0) { continue }
            if ($seen.Add($name)) { $list.Add($name); $units += $name.Length }
        }
        if ($Text.Length -eq 0) { return '' }
        if ($list.Count -gt $script:V3NamesMax -or $units -gt $script:V3NameUnitsMax) { $script:V3Full = $true; return $script:V3Marks[$script:V3FullRank] }
        $SpanS = New-Object 'System.Collections.Generic.List[int]'
        $SpanE = New-Object 'System.Collections.Generic.List[int]'
        $SpanR = New-Object 'System.Collections.Generic.List[int]'
        if ($Finder -eq 'ac') { Add-V3NameSpansAc $Text $list $SpanS $SpanE $SpanR } else { Add-V3NameSpansRegex $Text $list $SpanS $SpanE $SpanR }
        Add-V3StructSpans $Text $SpanS $SpanE $SpanR
        Merge-V3Spans $SpanS $SpanE $SpanR
        for ($rescans = 0; ; $rescans++) {
            $out = Get-V3Rendered $Text
            $fs = New-Object 'System.Collections.Generic.List[int]'
            $fe = New-Object 'System.Collections.Generic.List[int]'
            $fr = New-Object 'System.Collections.Generic.List[int]'
            Add-V3StructSpans $out $fs $fe $fr
            if ($fs.Count -eq 0) { return $out }
            if ($rescans -eq $script:V3RescansMax) { $script:V3Full = $true; return $script:V3Marks[$script:V3FullRank] }
            $SpanS = New-Object 'System.Collections.Generic.List[int]' (,$script:RunS.ToArray())
            $SpanE = New-Object 'System.Collections.Generic.List[int]' (,$script:RunE.ToArray())
            $SpanR = New-Object 'System.Collections.Generic.List[int]' (,$script:RunR.ToArray())
            for ($i = 0; $i -lt $fs.Count; $i++) {
                $SpanS.Add((Get-V3Original $fs[$i] $false))
                $SpanE.Add((Get-V3Original ($fe[$i] - 1) $true))
                $SpanR.Add($fr[$i])
            }
            Merge-V3Spans $SpanS $SpanE $SpanR
        }
    } catch {
        $base = $_.Exception.GetBaseException()
        if ($base -is [System.Text.RegularExpressions.RegexMatchTimeoutException]) { throw $base }   # 측정용: 시간 초과는 따로 적는다
        $script:V3Full = $true
        return $script:V3Marks[$script:V3FullRank]
    }
}

# ---------------------------------------------------------------- 인라인 C#(C# 5 문법만 — .NET Framework 의 csc 로 컴파일된다)
$csharp = @'
using System;
using System.Collections.Generic;
using System.Text;
using System.Text.RegularExpressions;

public static class ScrubV3Bench
{
    static readonly Dictionary<string, Regex> Cache = new Dictionary<string, Regex>();
    static Regex Rule(string source) { Regex re; if (!Cache.TryGetValue(source, out re)) { re = new Regex(source); Cache[source] = re; } return re; }

    static string Tidy(string value)
    {
        // 순서가 명세다(3회차 · codex 2R 발견 1): NUL 제거가 먼저, 그 결과에 서러게이트 치환 — 한 번의 훑기로 합치면 NUL 을 사이에 둔 짝이 깨진다
        if (value.IndexOf('\0') >= 0) value = value.Replace("\0", "");
        var sb = new StringBuilder(value.Length);
        for (int i = 0; i < value.Length; i++)
        {
            char c = value[i];
            if (char.IsHighSurrogate(c)) { if (i + 1 < value.Length && char.IsLowSurrogate(value[i + 1])) { sb.Append(c).Append(value[i + 1]); i++; } else sb.Append('\uFFFD'); }
            else if (char.IsLowSurrogate(c)) sb.Append('\uFFFD');
            else sb.Append(c);
        }
        return sb.ToString();
    }

    static void Struct(string text, string[] sources, int[] ranks, List<int> s, List<int> e, List<int> r)
    {
        for (int i = 0; i < sources.Length; i++)
            for (Match m = Rule(sources[i]).Match(text); m.Success; m = m.NextMatch()) { s.Add(m.Index); e.Add(m.Index + m.Length); r.Add(ranks[i]); }
    }

    static void Names(string text, List<string> names, List<int> s, List<int> e, List<int> r, int nameRank)
    {
        if (names.Count == 0) return;
        var go = new Dictionary<long, int>();
        var fail = new List<int>(); var longest = new List<int>(); var kids = new List<List<int>>();
        fail.Add(0); longest.Add(0); kids.Add(new List<int>());
        foreach (string name in names)
        {
            int state = 0;
            foreach (char ch in name)
            {
                long key = ((long)state << 16) + ch; int to;
                if (!go.TryGetValue(key, out to)) { to = fail.Count; fail.Add(0); longest.Add(0); kids.Add(new List<int>()); go[key] = to; kids[state].Add(ch); }
                state = to;
            }
            if (name.Length > longest[state]) longest[state] = name.Length;
        }
        var queue = new List<int>();
        foreach (int unit in kids[0]) queue.Add(go[(long)unit]);
        for (int head = 0; head < queue.Count; head++)
        {
            int state = queue[head];
            foreach (int unit in kids[state])
            {
                int to = go[((long)state << 16) + unit];
                int f = fail[state]; int via;
                while (f != 0 && !go.ContainsKey(((long)f << 16) + unit)) f = fail[f];
                fail[to] = (go.TryGetValue(((long)f << 16) + unit, out via) && via != to) ? via : 0;
                if (longest[fail[to]] > longest[to]) longest[to] = longest[fail[to]];
                queue.Add(to);
            }
        }
        int st = 0, curS = -1, curE = -1;
        for (int i = 0; i < text.Length; i++)
        {
            int unit = text[i]; int to;
            while (st != 0 && !go.ContainsKey(((long)st << 16) + unit)) st = fail[st];
            st = go.TryGetValue(((long)st << 16) + unit, out to) ? to : 0;
            int len = longest[st];
            if (len == 0) continue;
            int start = i + 1 - len;
            if (curE >= 0 && start <= curE)
            {
                if (start < curS)
                {
                    curS = start; // 스택 합치기(모델과 같음): 앞서 넘긴 구간 가운데 닿는 것을 꺼내 합친다 → 목록이 시작 자리 순
                    int top = s.Count - 1;
                    while (top >= 0 && e[top] >= curS) { if (s[top] < curS) curS = s[top]; s.RemoveAt(top); e.RemoveAt(top); r.RemoveAt(top); top--; }
                }
                curE = i + 1;
            }
            else { if (curE >= 0) { s.Add(curS); e.Add(curE); r.Add(nameRank); } curS = start; curE = i + 1; }
        }
        if (curE >= 0) { s.Add(curS); e.Add(curE); r.Add(nameRank); }
    }

    static void Merge(List<int> s, List<int> e, List<int> r, List<int> rs, List<int> re, List<int> rr)
    {
        rs.Clear(); re.Clear(); rr.Clear();
        int n = s.Count; if (n == 0) return;
        int[] keys = s.ToArray(); int[] idx = new int[n];
        for (int i = 0; i < n; i++) idx[i] = i;
        Array.Sort(keys, idx);
        int cs = keys[0], ce = e[idx[0]], cr = r[idx[0]];
        for (int i = 1; i < n; i++)
        {
            int j = idx[i];
            if (keys[i] <= ce) { if (e[j] > ce) ce = e[j]; if (r[j] < cr) cr = r[j]; }
            else { rs.Add(cs); re.Add(ce); rr.Add(cr); cs = keys[i]; ce = e[j]; cr = r[j]; }
        }
        rs.Add(cs); re.Add(ce); rr.Add(cr);
    }

    static int Original(int pos, bool isEnd, int[] markS, int[] markE, List<int> rs, List<int> re)
    {
        int k = Array.BinarySearch(markS, pos);
        if (k < 0) k = ~k - 1;
        if (k < 0) return isEnd ? pos + 1 : pos;
        if (pos < markE[k]) return isEnd ? re[k] : rs[k];
        int at = re[k] + (pos - markE[k]);
        return isEnd ? at + 1 : at;
    }

    public static string Scrub(string input, string[] names, string[] sources, int[] ranks, string[] marks, int namesMax, int nameUnitsMax, int rescansMax)
    {
        string text = Tidy(input ?? "");
        const int NameRank = 5, FullRank = 6;
        try
        {
            var seen = new HashSet<string>(StringComparer.Ordinal); var list = new List<string>(); long units = 0;
            foreach (string raw in names ?? new string[0])
            {
                if (raw == null) continue;
                string name = Tidy(raw);
                if (name.Length == 0) continue;
                if (seen.Add(name)) { list.Add(name); units += name.Length; }
            }
            if (text.Length == 0) return "";
            if (list.Count > namesMax || units > nameUnitsMax) return marks[FullRank];
            var s = new List<int>(); var e = new List<int>(); var r = new List<int>();
            var rs = new List<int>(); var re = new List<int>(); var rr = new List<int>();
            Names(text, list, s, e, r, NameRank);
            Struct(text, sources, ranks, s, e, r);
            Merge(s, e, r, rs, re, rr);
            for (int rescans = 0; ; rescans++)
            {
                var sb = new StringBuilder(); int cursor = 0;
                int[] markS = new int[rs.Count]; int[] markE = new int[rs.Count];
                for (int k = 0; k < rs.Count; k++)
                {
                    sb.Append(text, cursor, rs[k] - cursor); markS[k] = sb.Length; sb.Append(marks[rr[k]]); markE[k] = sb.Length; cursor = re[k];
                }
                sb.Append(text, cursor, text.Length - cursor);
                string rendered = sb.ToString();
                var fs = new List<int>(); var fe = new List<int>(); var fr = new List<int>();
                Struct(rendered, sources, ranks, fs, fe, fr);
                if (fs.Count == 0) return rendered;
                if (rescans == rescansMax) return marks[FullRank];
                s = new List<int>(rs); e = new List<int>(re); r = new List<int>(rr);
                for (int i = 0; i < fs.Count; i++)
                {
                    s.Add(Original(fs[i], false, markS, markE, rs, re)); e.Add(Original(fe[i] - 1, true, markS, markE, rs, re)); r.Add(fr[i]);
                }
                var ns = new List<int>(); var ne = new List<int>(); var nr = new List<int>();
                Merge(s, e, r, ns, ne, nr); rs = ns; re = ne; rr = nr;
            }
        }
        catch (Exception) { return text.Length == 0 ? "" : marks[FullRank]; }
    }
}
'@

# ---------------------------------------------------------------- 환경
Write-Row @('ENV', 'powershell', $PSVersionTable.PSVersion.ToString())
Write-Row @('ENV', 'clr', [System.Environment]::Version.ToString())
Write-Row @('ENV', 'os', [System.Environment]::OSVersion.VersionString)
Write-Row @('ENV', 'cpu_count', [string][System.Environment]::ProcessorCount)
Write-Row @('ENV', 'language_mode', [string]$ExecutionContext.SessionState.LanguageMode)
$policy = 'n/a'
try { $policy = [string](Get-ExecutionPolicy) } catch { }
Write-Row @('ENV', 'execution_policy', $policy)

$wanted = @($Shapes -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$csharpOk = $false
if ($wanted -contains 'csharp') {
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        Add-Type -TypeDefinition $csharp -Language CSharp -ErrorAction Stop
        $watch.Stop()
        $csharpOk = $true
        Write-Row @('ADDTYPE', 'ok', [string][int]$watch.Elapsed.TotalMilliseconds, '')
    } catch {
        $watch.Stop()
        Write-Row @('ADDTYPE', 'FAIL', [string][int]$watch.Elapsed.TotalMilliseconds, (([string]$_.Exception.Message) -replace '\s+', ' '))
    }
}

function Invoke-Shape([string]$Shape, [string]$Text, [string[]]$Names) {
    if ($Shape -eq 'csharp') {
        return [ScrubV3Bench]::Scrub($Text, $Names, $script:V3Sources, $script:V3Ranks, $script:V3Marks, $script:V3NamesMax, $script:V3NameUnitsMax, $script:V3RescansMax)
    }
    if ($Shape -eq 'ps-ac') { return (Invoke-V3ScrubPs $Text $Names 'ac') }
    return (Invoke-V3ScrubPs $Text $Names 'regex')
}

$sha = [System.Security.Cryptography.SHA256]::Create()
function Get-Digest([string]$Text) {
    # 코드 단위를 그대로 두 바이트씩(UTF-16LE) — 인코더를 거치면 짝 잃은 서러게이트가 U+FFFD 로 바뀌어 서로 다른 답이 같은 해시가 된다
    $chars = $Text.ToCharArray()
    $bytes = New-Object byte[] ($chars.Length * 2)
    [System.Buffer]::BlockCopy($chars, 0, $bytes, 0, $bytes.Length)
    $hash = $sha.ComputeHash($bytes)
    return (([System.BitConverter]::ToString($hash)) -replace '-', '').ToLowerInvariant().Substring(0, 16)
}

function ConvertTo-Text($Units) {
    $chars = New-Object char[] ($Units.Count)
    for ($i = 0; $i -lt $Units.Count; $i++) { $chars[$i] = [char][int]$Units[$i] }
    return (New-Object string (,$chars))
}

# ---------------------------------------------------------------- 입력 만들기(model 쪽 gen-expected.js 의 CASES 와 글자가 같아야 한다)
$hong = ([string][char]0xD64D) + ([string][char]0xAE38) + ([string][char]0xB3D9)
function New-Case([string]$Id, [int]$N) {
    switch ($Id) {
        'log' {
            $sb = New-Object System.Text.StringBuilder
            for ($i = 0; $sb.Length -lt $N; $i++) {
                [void]$sb.Append('[').Append($i % 10).Append('/10] step ').Append($i).Append(' ok - /Users/hongtester/.local/bin/tool --flag - C:\Users\hongtester\AppData - user hongtester done - mail a').Append($i).Append('@example.com').Append([char]10)
            }
            $names = New-Object 'System.Collections.Generic.List[string]'
            for ($i = 0; $i -lt 194; $i++) { $names.Add('name' + $i + 'x') }
            $names.Add('hongtester')
            return @{ Text = $sb.ToString().Substring(0, $N); Names = $names.ToArray() }
        }
        'arun' { return @{ Text = ('a' * $N); Names = [string[]]@('aa', 'aaa') } }
        'chain' { return @{ Text = ('r' + ('x' * ($N - 1))); Names = [string[]]@('rx') } }
        'tilde' { return @{ Text = ('~' * $N); Names = [string[]]@(('~' * 256)) } }
        'nested' { return @{ Text = (('/Users/' * [int][Math]::Floor($N / 7)) + 'x'); Names = [string[]]@() } }
        'email' { return @{ Text = ('a@b.co ' * [int][Math]::Floor($N / 7)); Names = [string[]]@() } }
        'samehead' {
            $names = New-Object 'System.Collections.Generic.List[string]'
            for ($i = 0; $i -lt 256; $i++) { $names.Add(('a' * 200) + ([string]$i).PadLeft(56, [char]'b')) }
            return @{ Text = ('a' * $N); Names = $names.ToArray() }
        }
        'hits' { return @{ Text = ('ab ' * [int][Math]::Floor($N / 3)); Names = [string[]]@('ab') } }
        'korean' {
            $line = $hong + ' log /Users/' + $hong + '/x ok' + [char]10
            return @{ Text = ($line * [int][Math]::Floor($N / $line.Length)); Names = [string[]]@($hong) }
        }
    }
    throw "unknown case $Id"
}

# ---------------------------------------------------------------- 답이 같은가(벡터) + 속도
$sizeList = @($spec.sizes | ForEach-Object { [int]$_ })
if ($Sizes) { $sizeList = @($Sizes -split ',' | ForEach-Object { [int]$_.Trim() }) }
$caseList = @($spec.cases | ForEach-Object { [string]$_ })
if ($Cases) { $caseList = @($Cases -split ',' | ForEach-Object { $_.Trim() }) }

foreach ($shape in $wanted) {
    if ($shape -eq 'csharp' -and -not $csharpOk) { Write-Row @('SUMMARY', $shape, 'unavailable'); continue }
    $pass = 0
    foreach ($vector in $vectors) {
        $text = ConvertTo-Text $vector.input
        $names = [string[]]@($vector.names | ForEach-Object { ConvertTo-Text $_ })
        $got = ''
        try { $got = Invoke-Shape $shape $text $names } catch { $got = 'ERROR' }
        if ((Get-Digest ([string]$got)) -eq [string]$vector.digest) { $pass++ } else { Write-Row @('VECTORFAIL', $shape, [string]$vector.id) }
    }
    Write-Row @('VECTORS', $shape, ([string]$pass + '/' + [string]@($vectors).Count))

    $mismatch = 0; $timeout = 0; $skip = 0; $maxMs = 0
    foreach ($case in $caseList) {
        $slow = $false
        foreach ($size in $sizeList) {
            if ($slow) { $skip++; Write-Row @('RESULT', $shape, $case, [string]$size, '', '', 'SKIP'); continue }
            $made = New-Case $case $size
            $status = 'match'; $digest = ''; $ms = 0
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $out = Invoke-Shape $shape $made.Text $made.Names
                $watch.Stop()
                $ms = [int]$watch.Elapsed.TotalMilliseconds
                $digest = Get-Digest ([string]$out)
                if ($digest -ne [string]$expected.("$($case):$size").digest) { $status = 'MISMATCH'; $mismatch++ }
            } catch {
                $watch.Stop()
                $ms = [int]$watch.Elapsed.TotalMilliseconds
                if ($_.Exception.GetBaseException() -is [System.Text.RegularExpressions.RegexMatchTimeoutException]) { $status = 'TIMEOUT'; $timeout++ } else { $status = 'ERROR'; $mismatch++ }
            }
            if ($ms -gt $maxMs) { $maxMs = $ms }
            # 다음 크기는 약 3.5~4배다 — 이번이 예산의 1/4 을 넘었으면 건너뛴다
            if ($ms -gt ($BudgetSeconds * 250) -or $status -eq 'TIMEOUT') { $slow = $true }
            Write-Row @('RESULT', $shape, $case, [string]$size, [string]$ms, $digest, $status)
        }
    }
    Write-Row @('SUMMARY', $shape, "mismatch=$mismatch", "timeout=$timeout", "skip=$skip", "max_ms=$maxMs")
}
