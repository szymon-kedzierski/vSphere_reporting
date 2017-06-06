# vSphere_reporting
VMware vSphere virtual environment status reporting

<b>Description</b> <br/>
Script saves current state of the VMware vSphere virtual environment - basic vCenter Server objects including ESXi hosts, clusters, datastores and virtual machines. 
Program also collects information about potential configuration errors affecting the efficiency of the environment, such as orphaned virtual machines or machines kept on the local ESXi storage.

<b>Requirements</b>
* Microsoft PowerShell 5.0 or higher command interpreter installed
* VMware PowerCLI 6.0 or later installed to run the script 
* to be able to connect to the vCenter Server from which the report should be created (port 443)

The script consists of two files: reports.ps1 and html.ps1. Both files must be placed in the same folder.
Tests were performed on VMware vSphere 6.0.

<b>Inputs</b>
 * vCenter_Server - IP or FQDN vCenter server
 * Folder - Folder where to save output files

<b>Output</b>
When the program starts properly, the following CSV output files are generated:
* clusters.csv - a file containing a high availability cluster configuration report
* datastores.csv - file containing the datastore configuration report
* hosts.csv - file containing the ESXi host configuration report
* resourcepools.csv - file containing resourcepool settings
* vds.csv - a file containing configuration of the virtual distributed switches
* vms.csv - a file containing configuration of virtual machines
* index.html - containing the same data as CSV files, put into separated tabs, also potencial issues are included into report 

Values in a CSV file are separated by a semicolon.

<b>Mware vSphere issues</b>

