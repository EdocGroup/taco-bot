$myDir = (Split-Path -Path $MyInvocation.MyCommand.Definition -Parent)
$manageHelm = (Join-Path $myDir "Manage-Helm.psm1")
#When Manage-Helm module exist,remove module and  import Manage-Helm module 
if ((get-module | Where-Object {$_.Name -eq "Manage-Helm"})) {
    Remove-Module -Name Manage-Helm
}
Import-Module $manageHelm -Function Manage-Helm -DisableNameChecking

Manage-Helm @args