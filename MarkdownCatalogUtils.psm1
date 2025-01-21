Add-Type -ReferencedAssemblies "System.Runtime.InteropServices.dll" -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class GoInterop
{
    [DllImport("FrontmatterParse.dll")]
    public static extern IntPtr ProcessFrontmatter(string filePath);
}
"@
<#
    TODO:
    - turn this into nice cli with
    github.com/rivo/tview & github.com/gdamore/tcell/v2
    make the matching more uniform/ clear
#>

Function Notes-List {
    <#
        .SYNOPSIS
        Lists markdown files with optional subcategory grouping.

        .DESCRIPTION
        This function retrieves and lists markdown (.md) files from the current directory. It supports filtering by group if provided. The output is sorted by LastWriteTime in ascending order.

        .PARAMETER Group
        An optional parameter that specifies a subgroup of files to filter by. If not supplied, all markdown files are listed.

        .EXAMPLE
        PS> Notes-List

        Lists all markdown files without any grouping.

        .EXAMPLE
        PS> Notes-List -Group 'Category'
        PS> nls -g map

        Lists all markdown files grouped under the specified category.
    #>
    Param(
        [Parameter(Position = 0)]
        [String]$Group
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
    [Bool]$skipGroup = [string]::IsNullOrEmpty($Group)
    if ($skipGroup) {
        $items = Get-ChildItem -File | Where-Object { $_.Extension -eq '.md' -and $_.Name -notlike '.*' <#filter dotfiles#> } 
    } else {
        $items = Get-ChildItem | Where-Object { $_.Name -like '*.md' -and $_.Name -notlike '.*' -and $_.Name -match '\.' -and $_.Name -like ('*.', $group, '.*' -join '') }
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

Function Get-NLSTags {
    <#
        .SYNOPSIS
            Retrieves tags inspired by vim syntax (e.g., `|#tag|`) from markdown files in the current directory.

        .DESCRIPTION
            The Get-NLSTags function scans through all markdown files (*.md) in the current directory,
            extracting content that matches tags. These are lines with the format:
            |#[Tag Content]|.

        .EXAMPLE
            PS C:\> $tags = Get-NLSTags

            This command retrieves a collection of hashtable objects, each containing 'filename' and 
            'content', where 'content' consists of lines matching the navigational link syntax.

        .NOTES
            Author: Your Name
            Date: YYYY-MM-DD
    #>
    $a = Get-ChildItem -File | ForEach-Object {
        # @{ 'content' = (Get-Content $_.FullName | Where-Object { $_ -match '^\s*#.*' }) } 
        $Headings = ((Get-Content $_.FullName) | Where-Object { $_ -match '\|#[^|\s]+\|' })
        # if (-NOT ($Headings).Count -OR ($Headings).Count -eq 0) {
        #     continue
        # }
        return @{
            'filename' = $_.FullName
            'content'  = $Headings
        }
    }
    # $a = $a | Where-Object { $_.Content -match '^\s*#.*' } 
    return $a

    $b | ForEach-Object {
        # Match the regex pattern and capture groups if needed
        if ($_ -match '^(\s*\#\s*)([^\r\n]*)') {
            # "Whitespace or newline followed by '#' and an ASCII character: ($matches - join"
        }
    }
}
Export-ModuleMember Get-NLSTags

Function Parse-Metadata {

    $frontMatterPtr = [GoInterop]::ProcessFrontmatter("X:/Dropbox/Application_Files/Modules/MarkdownCatalogUtils/go-frontmatter/note.md")
    $frontMatter = [System.Runtime.InteropServices.Marshal]::PtrToStringUTF8($frontMatterPtr)
    Write-Host "Front Matter: " $frontMatter
}
Export-ModuleMember Parse-Metadata
