Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Forms.Application]::EnableVisualStyles()

$script:AllItems = @()

function New-ItemObject {
    param(
        [string]$Category,
        [string]$Name,
        [string]$Type,
        [string]$Path,
        [string]$Action,
        [string]$Source,
        [string]$Detail,
        [string]$InstallDate = '',
        [string]$UninstallString = '',
        [bool]$Recommended = $false,
        [string]$Risk = 'Médio'
    )
    [pscustomobject]@{
        Selecionar      = $false
        Categoria       = $Category
        Nome            = $Name
        Tipo            = $Type
        Caminho         = $Path
        Acao            = $Action
        Origem          = $Source
        Detalhe         = $Detail
        InstallDate     = $InstallDate
        UninstallString = $UninstallString
        Recomendado     = if ($Recommended) { 'Sim' } else { 'Não' }
        Risco           = $Risk
    }
}

function Get-FolderSizeMB {
    param([string]$TargetPath)
    try {
        if (Test-Path $TargetPath) {
            $sum = (Get-ChildItem -LiteralPath $TargetPath -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            if ($null -eq $sum) { return 0 }
            return [math]::Round(($sum / 1MB), 2)
        }
    } catch {}
    return $null
}

function Format-InstallDate {
    param([string]$RawDate)
    if (-not $RawDate -or $RawDate.Trim() -eq '') { return '' }
    if ($RawDate -match '^\d{8}$') {
        try {
            return ([datetime]::ParseExact($RawDate, 'yyyyMMdd', $null)).ToString('dd/MM/yyyy')
        } catch {
            return $RawDate
        }
    }
    return $RawDate
}

function Get-InstalledPrograms {
    $paths = @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    $items = foreach ($p in $paths) {
        Get-ItemProperty $p -ErrorAction SilentlyContinue | Where-Object {
            $_.DisplayName -and $_.DisplayName.Trim() -ne ''
        } | ForEach-Object {
            $publisher = if ($_.Publisher) { $_.Publisher } else { 'Desconhecido' }
            $installDate = Format-InstallDate $_.InstallDate
            $detail = "Versão=$($_.DisplayVersion); Fabricante=$publisher; InstallDate=$installDate"
            $recommended = $false
            $risk = 'Médio'
            if ($_.DisplayName -match 'Microsoft Visual C\+\+|\.NET|Realtek|Intel|AMD|NVIDIA|Qualcomm|Driver|Audio|Bluetooth|Wireless|Chipset') {
                $recommended = $true
                $risk = 'Alto'
            }
            New-ItemObject -Category 'Programas' -Name $_.DisplayName -Type 'Programa instalado' -Path '' -Action 'Desinstalar' -Source 'Registro do Windows' -Detail $detail -InstallDate $installDate -UninstallString $_.UninstallString -Recommended $recommended -Risk $risk
        }
    }

    $items | Sort-Object Nome -Unique
}

function Get-CommonCacheItems {
    $today = (Get-Date).ToString('dd/MM/yyyy')
    $paths = @(
        @{ Category='Caches'; Name='Temp do usuário'; Type='Temporários'; Path=$env:TEMP; Action='Limpar'; Source='Sistema'; Risk='Baixo' },
        @{ Category='Caches'; Name='Temp local'; Type='Temporários'; Path="$env:LOCALAPPDATA\Temp"; Action='Limpar'; Source='Sistema'; Risk='Baixo' },
        @{ Category='Python'; Name='pip cache (LocalAppData)'; Type='Cache'; Path="$env:LOCALAPPDATA\pip\Cache"; Action='Limpar'; Source='pip'; Risk='Baixo' },
        @{ Category='Python'; Name='pip cache (AppData)'; Type='Cache'; Path="$env:APPDATA\pip\Cache"; Action='Limpar'; Source='pip'; Risk='Baixo' },
        @{ Category='Node'; Name='npm cache (AppData)'; Type='Cache'; Path="$env:APPDATA\npm-cache"; Action='Limpar'; Source='npm'; Risk='Baixo' },
        @{ Category='Node'; Name='npm pasta roaming'; Type='Dados de ferramenta'; Path="$env:APPDATA\npm"; Action='Analisar'; Source='npm'; Risk='Médio' },
        @{ Category='Node'; Name='.npm do usuário'; Type='Cache'; Path="$env:USERPROFILE\.npm"; Action='Limpar'; Source='npm'; Risk='Baixo' },
        @{ Category='Java'; Name='.m2 do usuário'; Type='Cache Maven'; Path="$env:USERPROFILE\.m2"; Action='Analisar'; Source='Maven'; Risk='Médio' },
        @{ Category='Java'; Name='.gradle do usuário'; Type='Cache Gradle'; Path="$env:USERPROFILE\.gradle"; Action='Analisar'; Source='Gradle'; Risk='Médio' },
        @{ Category='NuGet'; Name='.nuget do usuário'; Type='Cache'; Path="$env:USERPROFILE\.nuget"; Action='Analisar'; Source='NuGet'; Risk='Médio' },
        @{ Category='Rust'; Name='.cargo do usuário'; Type='Dados de ferramenta'; Path="$env:USERPROFILE\.cargo"; Action='Analisar'; Source='Cargo'; Risk='Médio' },
        @{ Category='Go'; Name='go do usuário'; Type='Dados de ferramenta'; Path="$env:USERPROFILE\go"; Action='Analisar'; Source='Go'; Risk='Médio' },
        @{ Category='Android'; Name='.android do usuário'; Type='Dados de ferramenta'; Path="$env:USERPROFILE\.android"; Action='Analisar'; Source='Android'; Risk='Médio' },
        @{ Category='VS Code'; Name='.vscode do usuário'; Type='Dados de ferramenta'; Path="$env:USERPROFILE\.vscode"; Action='Analisar'; Source='VS Code'; Risk='Médio' }
    )

    $list = foreach ($p in $paths) {
        if (Test-Path $p.Path) {
            $size = Get-FolderSizeMB -TargetPath $p.Path
            $detail = "Existe=Sim; TamanhoMB=$size"
            New-ItemObject -Category $p.Category -Name $p.Name -Type $p.Type -Path $p.Path -Action $p.Action -Source $p.Source -Detail $detail -InstallDate $today -Recommended $false -Risk $p.Risk
        }
    }
    $list
}

function Get-SelectedItems {
    $selected = @()
    foreach ($row in $grid.Rows) {
        if ($row.Cells['Selecionar'].Value -eq $true) {
            $selected += $row.Tag
        }
    }
    return $selected
}

function Show-ConfirmDialog {
    param(
        [string]$Message,
        [string]$Title = 'Confirmação'
    )
    $result = [System.Windows.Forms.MessageBox]::Show(
        $Message,
        $Title,
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question,
        [System.Windows.Forms.MessageBoxDefaultButton]::Button2
    )
    return ($result -eq [System.Windows.Forms.DialogResult]::Yes)
}

function Refresh-Grid {
    param([string]$FilterText = '')
    $grid.Rows.Clear()
    $items = $script:AllItems
    if ($FilterText -and $FilterText.Trim() -ne '') {
        $needle = $FilterText.ToLowerInvariant()
        $items = $items | Where-Object {
            ($_.Categoria -and $_.Categoria.ToLowerInvariant().Contains($needle)) -or
            ($_.Nome -and $_.Nome.ToLowerInvariant().Contains($needle)) -or
            ($_.InstallDate -and $_.InstallDate.ToLowerInvariant().Contains($needle))
        }
    }

    foreach ($item in $items) {
        $index = $grid.Rows.Add()
        $row = $grid.Rows[$index]
        $row.Cells['Selecionar'].Value = $false
        $row.Cells['Nome'].Value = $item.Nome
        $row.Cells['Categoria'].Value = $item.Categoria
        $row.Cells['InstallDate'].Value = $item.InstallDate
        $row.Tag = $item
        if ($item.Recomendado -eq 'Sim') {
            $row.DefaultCellStyle.BackColor = [System.Drawing.Color]::MistyRose
        }
    }
    $lblStatus.Text = "Itens listados: $($items.Count)"
}

function Remove-DirectoryContents {
    param([string]$TargetPath)
    if (-not (Test-Path $TargetPath)) { return }
    Get-ChildItem -LiteralPath $TargetPath -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
        } catch {
            $txtLog.AppendText("[ERRO] Não foi possível remover: $($_.FullName) :: $($_.Exception.Message)`r`n")
        }
    }
}

function Invoke-UninstallProgram {
    param($Item)
    if (-not $Item.UninstallString -or $Item.UninstallString.Trim() -eq '') {
        $txtLog.AppendText("[AVISO] Sem comando de desinstalação registrado: $($Item.Nome)`r`n")
        return
    }

    $cmd = $Item.UninstallString.Trim()
    $txtLog.AppendText("[EXEC] Desinstalando: $($Item.Nome)`r`n")

    try {
        if ($cmd -match 'msiexec(\.exe)?\s') {
            $args = $cmd -replace '^["'']?[^ ]*msiexec(\.exe)?["'']?\s*', ''
            if ($args -notmatch '/x' -and $args -notmatch '/X') {
                $args = "/x $args"
            }
            if ($args -notmatch '/qn' -and $args -notmatch '/quiet') {
                $args = "$args /qn /norestart"
            }
            Start-Process -FilePath 'msiexec.exe' -ArgumentList $args -Wait
        } else {
            if ($cmd.StartsWith('"')) {
                $exe = ($cmd -split '"')[1]
                $args = $cmd.Substring($exe.Length + 2).Trim()
            } else {
                $parts = $cmd -split ' ', 2
                $exe = $parts[0]
                $args = if ($parts.Count -gt 1) { $parts[1] } else { '' }
            }
            if ($args -notmatch '/quiet' -and $args -notmatch '/qn' -and $args -notmatch '/S' -and $args -notmatch '/silent') {
                $args = "$args /quiet"
            }
            Start-Process -FilePath $exe -ArgumentList $args -Wait
        }
        $txtLog.AppendText("[OK] Desinstalação concluída ou iniciada: $($Item.Nome)`r`n")
    } catch {
        $txtLog.AppendText("[ERRO] Falha ao desinstalar $($Item.Nome) :: $($_.Exception.Message)`r`n")
    }
}

function Invoke-RealCleanup {
    $selected = Get-SelectedItems
    if (-not $selected -or $selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Nenhum item selecionado.', 'Realizar limpeza', 'OK', 'Information') | Out-Null
        return
    }

    $summary = ($selected | Select-Object -ExpandProperty Nome | Select-Object -First 12) -join "`r`n- "
    $extra = if ($selected.Count -gt 12) { "`r`n... e mais $($selected.Count - 12) item(ns)." } else { '' }

    $confirm1 = Show-ConfirmDialog -Title 'Confirmar limpeza' -Message "Você realmente deseja continuar?`r`n`r`nOs itens abaixo serão processados:`r`n- $summary$extra"
    if (-not $confirm1) {
        $txtLog.AppendText("Ação cancelada pelo usuário na primeira confirmação.`r`n")
        return
    }

    $highRisk = $selected | Where-Object { $_.Recomendado -eq 'Sim' -or $_.Risco -eq 'Alto' }
    if ($highRisk.Count -gt 0) {
        $names = ($highRisk | Select-Object -ExpandProperty Nome | Sort-Object -Unique) -join "`r`n- "
        $confirm2 = Show-ConfirmDialog -Title 'Itens sensíveis selecionados' -Message "Atenção: há itens sensíveis selecionados.`r`n`r`n- $names`r`n`r`nDeseja continuar mesmo assim?"
        if (-not $confirm2) {
            $txtLog.AppendText("Ação cancelada pelo usuário na confirmação de itens sensíveis.`r`n")
            return
        }
    }

    $confirm3 = Show-ConfirmDialog -Title 'Confirmação final' -Message 'Última confirmação: deseja realmente realizar a limpeza e desinstalação agora?'
    if (-not $confirm3) {
        $txtLog.AppendText("Ação cancelada pelo usuário na confirmação final.`r`n")
        return
    }

    $txtLog.AppendText("--- EXECUÇÃO REAL INICIADA ---`r`n")
    foreach ($item in $selected) {
        switch ($item.Acao) {
            'Desinstalar' {
                Invoke-UninstallProgram -Item $item
            }
            'Limpar' {
                $txtLog.AppendText("[EXEC] Limpando: $($item.Caminho)`r`n")
                Remove-DirectoryContents -TargetPath $item.Caminho
                $txtLog.AppendText("[OK] Limpeza concluída: $($item.Caminho)`r`n")
            }
            default {
                $txtLog.AppendText("[PULAR] Item marcado como Analisar, ignorado nesta execução: $($item.Nome)`r`n")
            }
        }
    }
    $txtLog.AppendText("--- EXECUÇÃO REAL FINALIZADA ---`r`n")
    [System.Windows.Forms.MessageBox]::Show('Processo finalizado. Revise o log da janela.', 'Concluído', 'OK', 'Information') | Out-Null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Limpeza de PC - Interface gráfica'
$form.Size = New-Object System.Drawing.Size(1100, 840)
$form.StartPosition = 'CenterScreen'
$form.Topmost = $false

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = 'Escanear sistema'
$btnScan.Location = New-Object System.Drawing.Point(20, 20)
$btnScan.Size = New-Object System.Drawing.Size(160, 34)

$btnSelectAll = New-Object System.Windows.Forms.Button
$btnSelectAll.Text = 'Selecionar tudo'
$btnSelectAll.Location = New-Object System.Drawing.Point(190, 20)
$btnSelectAll.Size = New-Object System.Drawing.Size(150, 34)

$btnClear = New-Object System.Windows.Forms.Button
$btnClear.Text = 'Limpar seleção'
$btnClear.Location = New-Object System.Drawing.Point(350, 20)
$btnClear.Size = New-Object System.Drawing.Size(150, 34)

$btnSimulate = New-Object System.Windows.Forms.Button
$btnSimulate.Text = 'Simular limpeza'
$btnSimulate.Location = New-Object System.Drawing.Point(510, 20)
$btnSimulate.Size = New-Object System.Drawing.Size(150, 34)

$btnCopy = New-Object System.Windows.Forms.Button
$btnCopy.Text = 'Copiar seleção'
$btnCopy.Location = New-Object System.Drawing.Point(670, 20)
$btnCopy.Size = New-Object System.Drawing.Size(140, 34)

$btnExecute = New-Object System.Windows.Forms.Button
$btnExecute.Text = 'Realizar limpeza'
$btnExecute.Location = New-Object System.Drawing.Point(820, 20)
$btnExecute.Size = New-Object System.Drawing.Size(160, 34)

$txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(760, 70)
$txtFilter.Size = New-Object System.Drawing.Size(220, 24)

$lblFilter = New-Object System.Windows.Forms.Label
$lblFilter.Text = 'Filtro:'
$lblFilter.Location = New-Object System.Drawing.Point(720, 73)
$lblFilter.AutoSize = $true

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = 'Clique em Escanear sistema para listar itens.'
$lblStatus.Location = New-Object System.Drawing.Point(20, 73)
$lblStatus.AutoSize = $true

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Location = New-Object System.Drawing.Point(20, 110)
$grid.Size = New-Object System.Drawing.Size(1040, 500)
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $true
$grid.RowHeadersVisible = $false
$grid.ReadOnly = $false
$grid.AutoGenerateColumns = $false

$columns = @(
    @{ Name='Selecionar'; Header='Selecionar'; Type='CheckBox'; Width=90 },
    @{ Name='Nome'; Header='Nome'; Type='TextBox'; Width=470 },
    @{ Name='Categoria'; Header='Categoria'; Type='TextBox'; Width=180 },
    @{ Name='InstallDate'; Header='Data de instalação'; Type='TextBox'; Width=220 }
)

foreach ($c in $columns) {
    if ($c.Type -eq 'CheckBox') {
        $col = New-Object System.Windows.Forms.DataGridViewCheckBoxColumn
    } else {
        $col = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
        $col.ReadOnly = $true
    }
    $col.Name = $c.Name
    $col.HeaderText = $c.Header
    $col.Width = $c.Width
    $grid.Columns.Add($col) | Out-Null
}

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Location = New-Object System.Drawing.Point(20, 630)
$txtLog.Size = New-Object System.Drawing.Size(1040, 150)
$txtLog.Multiline = $true
$txtLog.ScrollBars = 'Vertical'
$txtLog.ReadOnly = $true

$form.Controls.AddRange(@($btnScan,$btnSelectAll,$btnClear,$btnSimulate,$btnCopy,$btnExecute,$txtFilter,$lblFilter,$lblStatus,$grid,$txtLog))

$btnScan.Add_Click({
    $txtLog.Clear()
    $txtLog.AppendText("Escaneando sistema...`r`n")
    $script:AllItems = @()
    $script:AllItems += Get-InstalledPrograms
    $script:AllItems += Get-CommonCacheItems
    Refresh-Grid -FilterText $txtFilter.Text
    $txtLog.AppendText("Escaneamento concluído. Itens encontrados: $($script:AllItems.Count)`r`n")
    $txtLog.AppendText("Linhas em vermelho claro indicam itens sensíveis.`r`n")
})

$btnSelectAll.Add_Click({
    foreach ($row in $grid.Rows) {
        $row.Cells['Selecionar'].Value = $true
    }
    $txtLog.AppendText("Todos os itens visíveis foram selecionados.`r`n")
})

$btnClear.Add_Click({
    foreach ($row in $grid.Rows) {
        $row.Cells['Selecionar'].Value = $false
    }
    $txtLog.AppendText("Seleção removida.`r`n")
})

$btnSimulate.Add_Click({
    $selected = Get-SelectedItems
    if (-not $selected -or $selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Nenhum item selecionado.', 'Simulação', 'OK', 'Information') | Out-Null
        return
    }

    $txtLog.AppendText("--- SIMULAÇÃO ---`r`n")
    foreach ($item in $selected) {
        switch ($item.Acao) {
            'Desinstalar' { $txtLog.AppendText("[SIMULAR] Desinstalar programa: $($item.Nome)`r`n") }
            'Limpar'      { $txtLog.AppendText("[SIMULAR] Limpar pasta/cache: $($item.Caminho)`r`n") }
            default       { $txtLog.AppendText("[ANALISAR] Revisar antes de agir: $($item.Nome) :: $($item.Caminho)`r`n") }
        }
    }
    $txtLog.AppendText("--- FIM DA SIMULAÇÃO ---`r`n")
})

$btnCopy.Add_Click({
    $selected = Get-SelectedItems
    if (-not $selected -or $selected.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Nenhum item selecionado para copiar.', 'Copiar seleção', 'OK', 'Information') | Out-Null
        return
    }

    $lines = New-Object System.Collections.Generic.List[string]
    $i = 0
    foreach ($item in $selected) {
        $i++
        $lines.Add("$i. [$($item.Categoria)] $($item.Nome) :: Data=$($item.InstallDate); Ação=$($item.Acao); Risco=$($item.Risco); NãoApagar=$($item.Recomendado); Caminho=$($item.Caminho); Detalhe=$($item.Detalhe)")
    }
    $text = ($lines -join "`r`n")
    [System.Windows.Forms.Clipboard]::SetText($text)
    $txtLog.AppendText("Seleção copiada para a área de transferência.`r`n")
    [System.Windows.Forms.MessageBox]::Show('Seleção copiada para a área de transferência.', 'Copiar seleção', 'OK', 'Information') | Out-Null
})

$btnExecute.Add_Click({
    Invoke-RealCleanup
})

$txtFilter.Add_TextChanged({
    Refresh-Grid -FilterText $txtFilter.Text
})

[void]$form.ShowDialog()
