# vSphere_reporting
VMware vSphere virtual environment status reporting

Requirements
* Microsoft PowerShell 5.0 or higher command interpreter installed
* VMware PowerCLI 6.0 or later installed to run the script 
* to be able to connect to the vCenter Server from which the report is to be created (port 443)

The tests were performed on VMware vSphere 6.0, but older versions of the environment will also work with the program.
The script consists of two files: reports.ps1 and html.ps1. Both files must be placed in the same folder.

Starting the program
The reporting program is a VMware PowerCLI script that, as input, assumes the vCenter server address and user name and password. This user must have sufficient authority to read information from the system. When you start, you also need to specify the path to the folder where you want to save the output. To run the program, enter the name of the script along with the path it contains:
.. \ reports.ps1
Then the user will be prompted to enter the IP address or name of the vCenter Server system and the folder to which the report is to be saved.

Output data
When the program starts properly, the following CSV output files are generated:
- clusters.csv - a file containing a high availability cluster configuration report
- datastores.csv - file containing the datastore configuration report
- hosts.csv - file containing the ESXi host configuration report
- resourcepools.csv - file containing resourcepool settings
- vds.csv - a file containing the configuration of the virtual distributed switches
- vms.csv - a file containing the configuration of virtual machines

Values in a CSV file are separated by a semicolon.
As a result of the program, there is also an HTML page named index.html containing the same data as CSV files, tabbed and tabbed with problems in the environment described in Table 5.1.

Possible reported issues with VMware vSphere
Name of the problem
Description of occurrences and implications
Virtual machines that have snapshots older than the specified time period.
The size of space occupied by snapshots grows over time. If they are stored for too long it may cause unnecessary occupying space on the matrix. The recommended time is 24-72 hours2.
Virtual machines without the latest version of vmtools installed
Vmtools is recommended to improve the performance of your operating system and to facilitate its management3.
Virtual machines that are disconnected, inaccessible, invalid or orphaned.
When vCenter Server, for some reason, is unable to communicate, the virtual machine displays one of the described messages. This may mean that the virtual machine is not working properly.
Virtual machines on local datastore
When virtual machines are not stored on shared disk space, ESXi will not be able to boot via the High Availability mechanism on another host4.
VCenter Server Alarms
Alarms are notifications that occur in response to events and conditions that occur on individual objects. They usually identify problems that have occurred in the environment.
