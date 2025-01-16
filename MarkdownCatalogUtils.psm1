Function Notes-List {
    Param(
        [Parameter(Position = 0)]
        [String]$group
    )

    class NotesObject {
        <# Properties #>
        [string]$Name
        [string]$Category
        [string]$BaseName
        [datetime]$LastWriteTime

        <# Constructor #>
        NotesObject([string]$nam, [string]$cat, [string]$bn, [datetime]$wt) {
            $this.Name = $nam
            $this.Category = $cat
            $this.BaseName = $bn
            $this.LastWriteTime = $wt
        }

        <# Static method to define default formatting instead of types.ps1xml #>
        static [void] RegisterFormatData() {
            <# Get the type name of the class #>
            $typeName = [NotesObject].FullName

            # Define the table view
            $tableView = @{
                Expression = { $_.Name }
                Label      = "Name"
                Width      = 45
            },
            @{
                Expression = { $_.Category }
                Label      = "Category"
                Width      = 20
            },
            @{
                Expression = { $_.BaseName }
                Label      = "BaseName"
                Width      = 30
            },
            @{
                Expression = { $_.LastWriteTime }
                Label      = "LastWriteTime"
                Width      = 25
                Alignment  = "Right"
            }

            # Create a scriptblock for dynamic format data generation
            $formatDataScript = {
                param($DataTypeName, $TableView)
                <# Create the View entry #>
                $viewEntry = New-Object -TypeName System.Management.Automation.FormatViewDefinition
                $viewEntry.Name = "TableView"
                $viewEntry.Control = New-Object -TypeName System.Management.Automation.FormatTableControl

                # Add columns to the table control
                $TableView | ForEach-Object {
                    $column = New-Object -TypeName System.Management.Automation.FormatColumn
                    $column.Alignment = $_.Alignment
                    $column.Label = $_.Label
                    $column.Width = $_.Width
                    $column.PropertyName = $_.Expression.Body
                    $viewEntry.Control.Columns.Add($column)
                }

                # Create the format entry
                $formatEntry = New-Object -TypeName System.Management.Automation.FormatEntry
                $formatEntry.EntrySelectedBy = New-Object -TypeName System.Management.Automation.FormatEntrySelectionCondition
                $formatEntry.EntrySelectedBy.TypeName = $DataTypeName
                $formatEntry.View = $viewEntry

                # Create a FormatEntryDefinition object
                $formatEntryDefinition = New-Object -TypeName System.Management.Automation.FormatEntryDefinition
                $formatEntryDefinition.FormatEntries.Add($formatEntry)

                # Create an array to hold the FormatEntryDefinition
                $formatEntryDefinitions = @($formatEntryDefinition)

                return $formatEntryDefinitions
            }

            # Create dynamic type data
            $typeData = New-Object -TypeName System.Management.Automation.TypeData -ArgumentList $typeName
            $typeData.DefaultDisplayPropertySet = New-Object -TypeName System.Management.Automation.PSPropertySet -ArgumentList 'DefaultDisplayPropertySet', @('Name', 'Category', 'BaseName', 'LastWriteTime')
            $typeData.FormatViewDefinition = & $formatDataScript -DataTypeName $typeName -TableView $tableView

            # Update format data
            Update-TypeData -TypeData $typeData
        }
    }

    <# markdown items which have sub category #>

    $items = $null;
    if (-NOT [string]::IsNullOrEmpty($group)) {
        $items = Get-ChildItem | Where-Object { $_.Name -like '*.md' -and $_.Name -notlike '.*' -and $_.Name -match '\.' -and $_.Name -like ('*.', $group, '.*' -join '') }
    } else {
        $items = Get-ChildItem | Where-Object { $_.Name -like '*.md' -and $_.Name -notlike '.*' -and $_.Name -match '\.' }
    }

    $items = $items | Sort-Object @{ Expression = "LastWriteTime"; Descending = $false }


    $values = $items | ForEach-Object {
        $bn = $_.BaseName
        $parts = $bn -split '\.';
        if ( -NOT $parts.Length -eq 2 ) {
            return 
        }; # case: too many periods; not a category note
        return [NotesObject]::new($parts[0], $parts[1], $bn, $_.LastWriteTime)
    }
    Write-Output $values 
}
Export-ModuleMember Notes-List

$CategoricalCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    class NotesObject {
        <# Properties #>
        [string]$Name
        [string]$Category
        [string]$BaseName
        [datetime]$LastWriteTime

        <# Constructor #>
        NotesObject([string]$nam, [string]$cat, [string]$bn, [datetime]$wt) {
            $this.Name = $nam
            $this.Category = $cat
            $this.BaseName = $bn
            $this.LastWriteTime = $wt
        }
    }
    # [System.Windows.Forms.MessageBox]::Show($wordToComplete)

    <# enumerate files which should have a group #>
    $items = Get-ChildItem | Where-Object {
        $_.Name -match '.*\..*\.md'
    }

    # Get all unique group names from filenames
    $matches = $items | ForEach-Object { 
        $bn = $_.BaseName
        $parts = $bn -split '\.';
        $cat = $parts[1]
        if ([String]::IsNullOrWhitespace($cat)) {
            return;
        };
        if ( -NOT $parts.Length -eq 2 ) {
            return; # case: too many periods; not a category note
        };
        return $cat
    } | Get-Unique

    if (-NOT [String]::IsNullOrWhiteSpace($wordToComplete) ) {
        $matches = $matches | Where-Object { ($_).StartsWith($wordToComplete) }
    }

    $matches | ForEach-Object {
        New-Object -Type System.Management.Automation.CompletionResult -ArgumentList @(
            $_          # completionText
            $_          # listItemText
            'ParameterValue' # resultType
            $_          # toolTip
        )
    }
}
Register-ArgumentCompleter -CommandName 'Notes-List' -ParameterName 'group' -ScriptBlock $CategoricalCompleter
