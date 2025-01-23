$fmp = (Resolve-Path "./FrontmatterParser.dll").Path.Replace('\', '/')
Write-Host $fmp, "  path"

$def = @"
using System;
using System.Runtime.InteropServices;
public class GoInterop
{
[DllImport("$($fmp)")]
public static extern IntPtr ProcessFrontmatter(string filePath);
}
"@
Write-Host $def

Add-Type -ReferencedAssemblies "System.Runtime.InteropServices.dll" -TypeDefinition $def

$ErrorActionPreference = "stop"
$p = (Resolve-Path "./note.md").Path.Replace('\', '/')

Write-Host "===FINISH LOADING DLL==="
Write-Host "Calling interop with path:", $p
$frontMatterPtr = ([GoInterop]::ProcessFrontmatter($p))

Try {
    $frontMatter = [System.Runtime.InteropServices.Marshal]::PtrToStringUTF8($frontMatterPtr)
} Catch {
    # Write-Output $frontMatterPtr
    $msg = "Error unmarshalling data from GoInterop.", $_.ToString() -join ', '
    Write-Error -Message $msg -ErrorAction 'Stop'
}
Write-Output $frontMatter
