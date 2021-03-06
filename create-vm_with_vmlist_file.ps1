﻿###### Variables definition
$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent

    # Création d'un fichier Log $ScriptDir\[SCRIPTNAME]_[YYYY_MM_DD].log
$dateDuJour = Get-Date -uformat %Y_%m_%d
$ScriptLogFile = "$ScriptDir\$([System.IO.Path]::GetFileNameWithoutExtension($MyInvocation.MyCommand.Definition))" + "_" + $dateDuJour + ".log"

$VMLoc = "" #Define location of Virtual Machines
$NetworkSwitch1 = "" #Define NetworkSwitch1 name
$NetworkSwitch1Type = "" #Define NetworkSwitch 1 Type. It should be "External", "Internal" or "Private".
$NetworkSwitch2 = "" #Define NetworkSwitch1 name
$NetworkSwitch2Type = "" #Define NetworkSwitch 2 Type. It should be "External", "Internal" or "Private".


###### Functions definition

function Stop-TranscriptOnLog
 {   
 	Stop-Transcript
   # On met dans le transcript les retour à la ligne nécessaires à Notepad
    [string]::Join("`r`n",(Get-Content $ScriptLogFile)) | Out-File $ScriptLogFile
 }

function Select-FileDialog
{
    param([string]$Titre,[string]$Filtre="Tous les fichiers *.*|*.*")
	[System.Reflection.Assembly]::LoadWithPartialName( 'System.Windows.Forms' ) | Out-Null
	$fileDialogBox = New-Object Windows.Forms.OpenFileDialog
	$fileDialogBox.ShowHelp = $false
	$fileDialogBox.initialDirectory = $ScriptDir
	$fileDialogBox.filter = $Filtre
    $fileDialogBox.Title = $Titre
	$Show = $fileDialogBox.ShowDialog( )

If ($Show -eq "OK")
    {
        Return $fileDialogBox.FileName
    }
    Else
    {
        Write-Error "Opération annulé" #MessageBox when the oparation is canceled
		[System.Windows.Forms.MessageBox]::Show("Le script ne peut continuer. Arrêt de l'opération." , "Opération annulé" , 0, [Windows.Forms.MessageBoxIcon]::Error)
        Stop-TranscriptOnLog
		Exit
    }

}


###### Démarrage du log et du script
Start-Transcript $ScriptLogFile | Out-Null

   # Create VM Folder and Network Switch
    MD $VMLoc -ErrorAction SilentlyContinue
    $TestSwitch = Get-VMSwitch -Name $NetworkSwitch1 -ErrorAction SilentlyContinue; if ($TestSwitch.Count -EQ 0){New-VMSwitch -Name $NetworkSwitch1 -SwitchType $NetworkSwitch1Type}
    $TestSwitch = Get-VMSwitch -Name $NetworkSwitch2 -ErrorAction SilentlyContinue; if ($TestSwitch.Count -EQ 0){New-VMSwitch -Name $NetworkSwitch2 -SwitchType $NetworkSwitch2Type}

   # Import CSV file
[System.Windows.Forms.MessageBox]::Show("Merci de sélectionner dans la fenêtre suivante le fichier CSV contenant la configuration des VM à créer.
Son contenu doit ressembler à ceci :

Name;DiskCapacityInGB;Generation;CPUNb;StartupRAMinMB;MinimumRAMinMB;SwitchName
VM01;200;2;2;1024;512;LAN 192.168.1.0
VM02;200;2;2;1024;512;LAN 192.168.1.0
VM03;200;2;2;1024;512;LAN 192.168.1.0
" , "Configuration des VM" , 0, [Windows.Forms.MessageBoxIcon]::Question)

	$CSVVMConfigFile = Select-FileDialog -Titre "Choisir le fichier CSV" -Filtre "Fichier CSV (*.csv) |*.csv"
    $VMList = Import-Csv $CSVVMConfigFile -Delimiter ';'

   # Create Virtual Machines
    foreach($VMList in $VMList)
{
                               $VMName = $VMList.Name
                               $DiskCapacityinGB = $VMList.DiskCapacityInGB
                               [int64]$DiskCapacity = 1GB*$DiskCapacityinGB
							   $Generation = $VMList.Generation
							   $CPU = $VMList.CPUNb
                               $MemoryStartupBytes = $VMList.StartupRAMinMB
                               $MemoryMinimumBytes = $VMList.MinimumRAMinMB
                               [int64]$startupmem = 1MB*$MemoryStartupBytes
                               [int64]$minimummem = 1MB*$MemoryMinimumBytes
                               $SwitchName = $VMList.SwitchName

   # Create Virtual Machines & VHDX
    New-VHD -Path "$VMLoc\$VMName\Virtual Hard Disks\$VMName.vhdx" -SizeBytes $DiskCapacity -Dynamic
    New-VM -Path $VMLoc -Name $VMName -Generation $Generation -MemoryStartupBytes $startupmem -VHDPath "$VMLoc\$VMName\Virtual Hard Disks\$VMName.vhdx" -SwitchName $SwitchName
    Set-VMProcessor –VMName $VMName –count $CPU
    Set-VMMemory -VMName $VMName -DynamicMemoryEnabled $true -StartupBytes $startupmem -MinimumBytes $minimummem
}


    $OUTPUT= [System.Windows.Forms.MessageBox]::Show("Les VM ont bien été créés. Souhaitez-vous les démarrer ?" , "Création des VM terminée" , 4, [Windows.Forms.MessageBoxIcon]::Question)
        if ($OUTPUT -eq "YES" )
        {
           # Import CSV file
            $VMList = Import-Csv $CSVVMConfigFile -delimiter ';'
           # Start all created VM
                foreach($VMList in $VMList)
                    {
                    $VMName = $VMList.Name
                    Start-VM $VMName
                    }
        }     
        else
                    {
                    [System.Windows.Forms.MessageBox]::Show("Les VM créés n'ont pas été démarrées." , "Création des VM terminée" , 0, [Windows.Forms.MessageBoxIcon]::Information)
                    }
    
   # Get VM
    Get-VM | Sort-Object Name | Select Name, State, CPUUsage, MemoryAssigned |Export-CliXML $ScriptDir\Get-VM.xml
    Import-CliXML $ScriptDir\Get-VM.xml | Out-GridView -Title Get-VM -PassThru


###### Arrêt du log
	Stop-TranscriptOnLog
