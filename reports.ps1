# VMware vSphere reporting
# Author: Szymon Kędzierski

<#
    .SYNOPSIS
        VMware vSphere reporting script

    .DESCRIPTION
        Script saves current state of the VMware vSphere virtual environment - basic vCenter Server objects including ESXi hosts, clusters, datastores and virtual machines. 
        Program also collects information about potential configuration errors affecting the efficiency of the environment, such as orphaned virtual machines or machines kept on the local ESXi storage.

    .PARAMETER vCenter_Server
        IP or FQDN vCenter server

    .PARAMETER Folder
        Folder where to save output files

    .OUTPUTS
       clusters.csv
       datastores.csv
       hosts.csv
       resourcepools.csv
       vds.csv
       vms.csv
       index.html

    .EXAMPLE
        .\reports.ps1 192.168.1.1 C:\Temp

    .LINK
        https://github.com/szymon-kedzierski/vSphere_reporting/blob/master/README.md

#>


[CmdletBinding()] 
Param (

#IP or FQDN vCenter server
[Parameter (Mandatory=$True)] [string] $vCenter_Server, 

# Folder where to save output
[Parameter (Mandatory=$True)] [string] $Folder 
)

#vCenter Server connection

 try 
 {
   if (!(Test-Path $Folder)) {throw "Folder does not exist. Exiting..."} #If folder exists
   Write-Host "Connecting to vCenter, please wait..."
   Connect-ViServer -server $vCenter_Server 
   if (!$?) {throw "Could not connect to vCenter. Exiting..."}
  }
catch [Exception]{
    Write-Host  $_.Exception.Message
    Exit
  }


#Configuration parameters
#------------------------------------------------------------------------------------------------------------------------
$snap_hours=5 #Number of days that snapshots can be held.

#------------------------------------------------------------------------------------------------------------------------
#finds all snapshots that exist for more than "$hours", for the virtual machine specified as "$vm"
#function returns table of snapshots
 
function find_snap([int]$hours, $vm)
{


     [array]$allsnapshots = $null
 
     $date = (Get-Date).AddHours(-1 * $hours)
     $found=0

    [array]$vmsnapshots = Get-VM -Id $vm.MoRef | Get-Snapshot
 
     # Checking if snapshot exist longer than specified in "$hours"
     Foreach ($snap in $vmsnapshots)
     {
        If ($snap.Created -le $date)
        {
            $allsnapshots += New-Object psobject -Property @{
             VMName = $vm.name
            "Snapshot created" =$snap.Created
            "Snapshot description" =$snap.Description
            }
            $found=1
       }
     }
      
     if ($found -ne 1)
     {
        return 0
     }
     else
     {
        return $allsnapshots
     }
}
 
 
#------------------------------------------------------------------------------------------------------------------------

# Virtual machine report

$vms= Get-View -ViewType VirtualMachine -property name, Parentvapp, Runtime.PowerState, RunTime.ConnectionState, guest.guestFullName, Guest.ToolsVersionStatus, Guest.ToolsVersion, config.version, config.hardware.NumCPU, config.hardware.NumCoresPerSocket, config.hardware.MemoryMB, Layout.disk, Guest.Disk, ResourcePool, runtime.host, Parent, Parentvapp, summary.config.vmpathname, summary.config.Uuid

$table = New-Object system.Data.DataTable "Results"

$col1 = New-Object system.Data.DataColumn Id,([string])
$col2 = New-Object system.Data.DataColumn Name,([string])
$col3 = New-Object system.Data.DataColumn "Power State",([string])
$col4 = New-Object system.Data.DataColumn "Guest OS",([string])
$col5 = New-Object system.Data.DataColumn 'Hardware version',([string])
$col6 = New-Object system.Data.DataColumn 'Number of CPUs',([string])
$col7 = New-Object system.Data.DataColumn 'Cores per socket',([string])
$col8 = New-Object system.Data.DataColumn 'Memory in MB',([string])
$col9 = New-Object system.Data.DataColumn 'Number of disks',([string])
$col10 = New-Object system.Data.DataColumn 'Provisioned space in GB',([string])
$col11 = New-Object system.Data.DataColumn 'Used Space in GB',([string])
$col12 = New-Object system.Data.DataColumn 'Resource Pool',([string])
$col13 = New-Object system.Data.DataColumn 'ESXi Host Name',([string])
$col15 = New-Object system.Data.DataColumn vApp,([string])
$col16 = New-Object system.Data.DataColumn Datacenter,([string])
$col17 = New-Object system.Data.DataColumn Cluster,([string])
$col18 = New-Object system.Data.DataColumn Datastore,([string])
$col19 = New-Object system.Data.DataColumn 'VMX Path',([string])
$col20 = New-Object system.Data.DataColumn UUID,([string])

$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)
$table.columns.add($col6)
$table.columns.add($col7)
$table.columns.add($col8)
$table.columns.add($col9)
$table.columns.add($col10)
$table.columns.add($col11)
$table.columns.add($col12)
$table.columns.add($col13)
$table.columns.add($col15)
$table.columns.add($col16)
$table.columns.add($col17)
$table.columns.add($col18)
$table.columns.add($col19)
$table.columns.add($col20)


$html_issues=""
$sn=""

foreach ($vm in $vms)
{

    $row = $table.NewRow()
    $row.Id= $vm.MoRef
    $row.Name= $vm.Name
    $row."Power State"= $vm.Runtime.PowerState
    $row."Guest OS"= $vm.guest.guestFullName
    $row."Hardware version"= $vm.config.version
    $row.'Number of CPUs' = $vm.config.hardware.NumCPU
    $row.'Cores per socket'= $vm.config.hardware.NumCoresPerSocket
    $row.'Memory in MB' = ($vm.config.hardware.MemoryMB)
    $row.'Number of disks' = ($vm.Layout.disk|measure).count

    #Disk size
    $cap=0
    Foreach ($disk in $vm.Guest.Disk){$cap=$cap+$disk.capacity}

    #Free space on disk
    $free=0
    Foreach ($disk in $vm.Guest.Disk){$free=$free+$disk.FreeSpace}

    $row.'Provisioned space in GB'=[math]::round((($cap)/1GB),0)
    $row.'Used Space in GB'=[math]::round((($cap-$free)/1GB),0)

    if ($vm.ResourcePool){
    $row.'Resource Pool'= (get-view -id $vm.ResourcePool -property name).name}

    $ESXi=get-view -id $vm.runtime.host -property name,Parent
    $row.'ESXi Host Name' = $ESXi.name 

    if ($vm.Parentvapp){
    $row.'vApp'= (get-view -id $vm.Parentvapp -property name).name  }

    #Datacenter name
    if ($vm.Parent){
        $parentObj = Get-View $vm.Parent}

    # Finding datacenter by parent
    while ($parentObj -isnot [VMware.Vim.Datacenter])
    {
        $parentObj = Get-View $parentObj.Parent 
    }
    $row.Datacenter= $parentObj.Name

    #$row.cluster=Get-Cluster -VM $vm.name
    $row.cluster= (Get-View -Id $ESXi.Parent -property name).Name

    #$row.datastore=Get-Datastore -VM $vm.name
    $d=$vm.summary.config.vmpathname

    #cutting vmpathname name to obtain datasotre
    $ds=$d.Substring(1,$d.IndexOf(']'))
    $ds=$ds.Substring(0,$ds.IndexOf(']'))

    $row.datastore=$ds

    $row.'VMX Path' =$vm.summary.config.vmpathname

    $row.'UUID'=$vm.summary.config.Uuid

    $table.Rows.Add($row) 

    # Finding snapshot older than "$snap_hours" and count is larger than "$snap_count"
    if($sn= find_snap $snap_hours $vm)
    {

        [array]$html_issues_snap += $sn |Select -property VMname, "Snapshot created", "Snapshot description"
    }
    $sn=""

    
    #vms with old vmtools
    if ($vm.Guest.ToolsVersionStatus -ne "guestToolsCurrent")
    {

      $vmtools = New-Object psobject -Property @{
            "VM Name" = $vm.name
            "VMTools Version Status" =$vm.Guest.ToolsVersionStatus
            "VMTools Version" =$vm.Guest.ToolsVersion
            }

        [array]$html_issues_vmtools += $vmtools|Select "VM Name", "VMTools Version Status", "VMTools Version" 
    }

    #disconnected, inaccessible, invalid, orphaned vms
    if (($vm.RunTime.ConnectionState -eq "disconnected") -or ($vm.RunTime.ConnectionState -eq "inaccessible") -or ($vm.RunTime.ConnectionState -eq "invalid") -or ($vm.RunTime.ConnectionState -eq "orphaned"))
    {
        $vmstate = New-Object psobject -Property @{
            "VM Name" = $vm.name
            "VM State" =$vm.RunTime.ConnectionState
            }
        [array]$html_issues_vm_state +=$vmstate|Select "VM Name","VM State"
    } 

}



#writing output to csv file
$table| Export-CSV $Folder\vms.csv -NoTypeInformation -Delimiter ";" 

#generating web page
$html_vms = $table| Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors |ConvertTo-Html -Fragment


if ($html_issues_snap){
$html_issues +="<b>Snapshots older than $snap_hours hours:</b><br><br>"
$html_issues +=$html_issues_snap |ConvertTo-Html -Fragment
}


if ($html_issues_vmtools){
$html_issues +="<b><br>VMs without current tools:</b><br><br>" 
$html_issues +=$html_issues_vmtools|ConvertTo-Html -Fragment
}

if ($html_issues_vm_state){
$html_issues +="<b><br>VMs disconnected, inaccessible, invalid or orphaned:</b><br><br>" 
$html_issues +=$html_issues_vm_state|ConvertTo-Html -Fragment
}



$table.clear()

#------------------------------------------------------------------------------------------------------------------------
# Cluster report

$clusters= Get-Cluster 

$results = foreach ($cluster in $clusters)
{

    $cluster|Select-Object id, Name, 
    @{N='Number of ESXi hosts';E={$_|Get-VMHost|measure|foreach{ $_.Count }}},
    @{N='Number of vms';E={$_|Get-VM|measure|foreach{ $_.Count }}},
    @{N='CPU Cores';E={$_.ExtensionData.Summary.NumCpuCores}},
    @{N='CPU Threads';E={$_.ExtensionData.Summary.NumCpuThreads}},
    @{N='CPU in MHz';E={$_.ExtensionData.Summary.TotalCPU}},
    @{N='Memory in GB';E={[math]::round(($_.ExtensionData.Summary.EffectiveMemory / 1KB),0)}},
    @{N='HA Enabled';E={$_.HAEnabled}},
    @{N='HA Admission Control Enabled';E={$_.HAAdmissionControlEnabled}},
    @{N='HA Restart Priority';E={$_.HARestartPriority}},
    @{N='HA Isolation Response';E={$_.HAIsolationResponse}},
    @{N='VM Swapfile Policy';E={$_.VMSwapfilePolicy}},
    @{N='HA CPU Slot in MHz';E={$_.HASlotCpuMHz}},
    @{N='HA memory Slot in MB';E={$_.HASlotMemoryMb}},
    @{N='DrsEnabled';E={$_.DrsEnabled}},
    @{N='Drs Mode';E={$_.DrsMode}},
    @{N='Drs Automation Level';E={$_.DrsAutomationLevel}},
    @{N='EVC Mode';E={$_.EVCMode}}

}

$results|Export-CSV $Folder\clusters.csv -NoTypeInformation -Delimiter ";" #zapis do pliku CSV

$html_clusters = $results| Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-Html -Fragment

#------------------------------------------------------------------------------------------------------------------------
# ESXi report

$hosts= Get-View -ViewType HostSystem -property Name, Summary, Hardware, Parent, vm, config.product.FullName

$table = New-Object system.Data.DataTable "Results"

$col1 = New-Object system.Data.DataColumn Name,([string])
$col2 = New-Object system.Data.DataColumn "CPU Model",([string])
$col3 = New-Object system.Data.DataColumn "Memory in MB",([string])
$col4 = New-Object system.Data.DataColumn "Cpu in Mhz",([string])
$col5 = New-Object system.Data.DataColumn "Cpu Cores",([string])
$col6 = New-Object system.Data.DataColumn "Cpu Threads",([string])
$col7 = New-Object system.Data.DataColumn "Number of Nics",([string])
$col8 = New-Object system.Data.DataColumn "Number of HBAs",([string])
$col9 = New-Object system.Data.DataColumn "Cluster",([string])
$col10 = New-Object system.Data.DataColumn "Number of vms",([string])
$col11 = New-Object system.Data.DataColumn "Vendor",([string])
$col12 = New-Object system.Data.DataColumn "Model",([string])
$col13 = New-Object system.Data.DataColumn "ESXi version",([string])
$col14 = New-Object system.Data.DataColumn "UUID",([string])

$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)
$table.columns.add($col6)
$table.columns.add($col7)
$table.columns.add($col8)
$table.columns.add($col9)
$table.columns.add($col10)
$table.columns.add($col11)
$table.columns.add($col12)
$table.columns.add($col13)
$table.columns.add($col14)

foreach ($ESXi in $hosts)
{

    $row = $table.NewRow()

    $row.Name= $ESXi.Name
    $row."Memory in MB" = [math]::round(($ESXi.Summary.Hardware.MemorySize/1MB),0)
    $row."CPU Model"=$ESXi.Summary.Hardware.CpuModel 
    $row."Cpu in Mhz" =$ESXi.Summary.Hardware.CpuMhz                      
    $row."Cpu Cores"=$ESXi.Summary.Hardware.NumCpuCores          
    $row."Cpu Threads" = $ESXi.Summary.Hardware.NumCpuThreads        
    $row."Number of Nics"=$ESXi.Summary.Hardware.NumNics            
    $row."Number of HBAs"=$ESXi.Summary.Hardware.NumHBAs  
    $row."Vendor"=$ESXi.Hardware.SystemInfo.Vendor
    $row."Model"=$ESXi.Hardware.SystemInfo.Model
         
    $row."Cluster"= (Get-View -Id $ESXi.Parent -property Name).name # zwraca nazwe klastra lub datacenter jesli host nie jest w klastrze

    $row."Number of vms"=($ESXi.vm|measure).count
    $row."ESXi version"=$ESXi.config.product.FullName
    $row."UUID" = $ESXi.hardware.systeminfo.uuid


    $table.Rows.Add($row) 
}

$table| Export-CSV $Folder\hosts.csv -NoTypeInformation -Delimiter ";"

$html_hosts = $table| Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors |ConvertTo-Html -Fragment

$table.clear()


#------------------------------------------------------------------------------------------------------------------------
# datastore report

$datastores= Get-View -ViewType Datastore

$table = New-Object system.Data.DataTable "Results"

$col1 = New-Object system.Data.DataColumn Name,([string])
$col2 = New-Object system.Data.DataColumn "Capacity in GB",([string])
$col3 = New-Object system.Data.DataColumn "Free Space",([string])
$col4 = New-Object system.Data.DataColumn Type,([string])
$col5 = New-Object system.Data.DataColumn "VMFS Version",([string])
$col6 = New-Object system.Data.DataColumn Url,([string])
$col7 = New-Object system.Data.DataColumn "Block Size in MB",([string])
$col8 = New-Object system.Data.DataColumn "Number of vms",([string])
$col9 = New-Object system.Data.DataColumn Extent,([string])
$col10 = New-Object system.Data.DataColumn Local,([string])
$col11 = New-Object system.Data.DataColumn UUID,([string])

$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)
$table.columns.add($col6)
$table.columns.add($col7)
$table.columns.add($col8)
$table.columns.add($col9)
$table.columns.add($col10)
$table.columns.add($col11)


foreach ($ds in $datastores)
{

    $row = $table.NewRow()

    $row.Name= $ds.Name
    $row.Url= $ds.summary.url
    $row."Free Space"=[math]::round(( $ds.summary.freespace/1GB),0)
    $row."Type"= $ds.summary.type
    $row."VMFS Version"= $ds.info.vmfs.version
    $row."Block Size in MB"= $ds.info.vmfs.BlockSizeMB

    $row."UUID"= $ds.info.vmfs.UUID
    $row."Extent"= $ds.info.vmfs.Extent.DiskName
    $row."Local"= $ds.info.vmfs.Local
    $row."Capacity in GB"= [math]::round(($ds.info.vmfs.Capacity/1GB),0)
    $row."Number of vms" = ($ds.vm|measure).count

    #vms on local storage
    if ($ds.info.vmfs.Local -eq "True") 
    {
       
       $ds_local = New-Object psobject -Property @{
            "VM Name" = (get-vm -id $ds.vm).name
            "Datastore" =$ds.Name
            }
        [array]$html_issues_ds+=$ds_local| Select "VM Name", "Datastore"
    }

    $table.Rows.Add($row) 
}

if ($html_issues_ds){
$html_issues +="<b><br>VMs on local storage:</b><br><br>"
$html_issues +=$html_issues_ds |ConvertTo-Html -Fragment
}


$table| Export-CSV $Folder\datastores.csv -NoTypeInformation -Delimiter ";"

$html_ds = $table| Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-Html -Fragment

$table.clear()

#------------------------------------------------------------------------------------------------------------------------
# vDS report

$dvs= Get-View -ViewType DistributedVirtualSwitch

$table = New-Object system.Data.DataTable "Results"

$col1 = New-Object system.Data.DataColumn Name,([string])
$col2 = New-Object system.Data.DataColumn Vendor,([string])
$col3 = New-Object system.Data.DataColumn Version,([string])
$col4 = New-Object system.Data.DataColumn "Number of vms connected",([string])
$col5 = New-Object system.Data.DataColumn "Number of hosts connected",([string])
$col6 = New-Object system.Data.DataColumn "Number of ports",([string])
$col7 = New-Object system.Data.DataColumn "Max MTU",([string])
$col8= New-Object system.Data.DataColumn "UUID",([string])

$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)
$table.columns.add($col6)
$table.columns.add($col7)
$table.columns.add($col8)

foreach ($s in $dvs)
{

    $row = $table.NewRow()

    $row.Name= $s.Name
    $row.Vendor= $s.summary.productinfo.Vendor
    $row.Version= $s.summary.productinfo.Version
    $row."Number of vms connected" = ($s.summary.vm|measure).count
    $row."Number of hosts connected" = $s.summary.NumHosts
    $row."Number of ports" = $s.summary.Numports
    $row."Max MTU" = $s.config.maxmtu
    $row.UUID= $s.UUID

    $table.Rows.Add($row) 
}

$table| Export-CSV $Folder\vds.csv -NoTypeInformation -Delimiter ";"

$html_vds = $table| Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors | ConvertTo-Html -Fragment

$table.clear()

#------------------------------------------------------------------------------------------------------------------------
# Resource Pool report

$resourcepools= Get-View -ViewType ResourcePool 
$table = New-Object system.Data.DataTable "Results"

$col1 = New-Object system.Data.DataColumn id,([string])
$col2 = New-Object system.Data.DataColumn Name,([string])
$col3 = New-Object system.Data.DataColumn "CPU Reservation",([string])
$col4 = New-Object system.Data.DataColumn "CPU Limit",([string])
$col5 = New-Object system.Data.DataColumn "CPU share value",([string])
$col6 = New-Object system.Data.DataColumn "Memory Reservation",([string])
$col7 = New-Object system.Data.DataColumn "Memory Limit",([string])
$col8 = New-Object system.Data.DataColumn "Memory share value",([string])
$col9 = New-Object system.Data.DataColumn "Number of vms",([string])

$table.columns.add($col1)
$table.columns.add($col2)
$table.columns.add($col3)
$table.columns.add($col4)
$table.columns.add($col5)
$table.columns.add($col6)
$table.columns.add($col7)
$table.columns.add($col8)
$table.columns.add($col9)


foreach ($resourcepool in $resourcepools)
{

    $row = $table.NewRow()

    $row.id=$resourcepool.Moref
    $row.Name=$resourcepool.Name
    $row."CPU Reservation"= $resourcepool.summary.config.cpuallocation.reservation
    $row."CPU Limit"=$resourcepool.summary.config.cpuallocation.Limit
    $row."CPU Share value"=$resourcepool.summary.config.cpuallocation.shares.shares
    $row."Memory Reservation"= $resourcepool.summary.config.memoryallocation.reservation
    $row."Memory Limit"=$resourcepool.summary.config.memoryallocation.Limit
    $row."Memory share value"=$resourcepool.summary.config.memoryallocation.shares.shares
    $row."Number of vms"= ($resourcepool.vm|measure).count

    $table.Rows.Add($row) 
}

$table| Export-CSV $Folder\resourcepools.csv -NoTypeInformation -Delimiter ";"

$html_rp = $table| Select * -ExcludeProperty RowError, RowState, Table, ItemArray, HasErrors |ConvertTo-Html -Fragment

$table.clear()

#------------------------------------------------------------------------------------------------------------------------
# vCenter Server alarms

$rootFolder = Get-Folder "Datacenters"
$html_issues += "<b><br>vCenter Alarms:</b><br><br>"
 
	foreach ($ta in $rootFolder.ExtensionData.TriggeredAlarmState) {
		$alarm = "" | Select-Object EntityType, Alarm, Entity, Status, Time, Acknowledged, AckBy, AckTime
		$alarm.Alarm = (Get-View $ta.Alarm).Info.Name
		$entity = Get-View $ta.Entity
		$alarm.Entity = (Get-View  $ta.Entity).Name
		$alarm.EntityType = (Get-View $ta.Entity).GetType().Name	
		$alarm.Status = $ta.OverallStatus
		$alarm.Time = $ta.Time
		$alarm.Acknowledged = $ta.Acknowledged
		$alarm.AckBy = $ta.AcknowledgedByUser
		$alarm.AckTime = $ta.AcknowledgedTime		
		[array]$alarm_array +=$alarm
	}

$html_issues+= $alarm_array|ConvertTo-Html -Fragment

#web page script
. $PSScriptRoot\html.ps1
