# VMware vSphere reporting
# VMware vSphere virtual environment status reporting
# Author: Szymon Kędzierski

#------------------------------------------------------------------------------------------------------------------------
# Generating webpage file


$html_index= @"
<!DOCTYPE html>
<html>
<style>
body {font-family: "Lato", sans-serif;}

table {border-collapse: collapse; border-width: 1px;
border-style: solid; border-color: black;}
tr {padding: 5px;}
th {border-width: 1px; border-style: solid; border-color: black;
background-color: #669999; color: white;}
td {border-width: 1px; border-style: solid; border-color: black;
background-color: ;}

ul.tab {
    list-style-type: none;
    margin: 0;
    padding: 0;
    overflow: hidden;
    border: 1px solid #ccc;
    background-color: #f1f1f1;
}

ul.tab li {float: left;}

ul.tab li a {
    display: inline-block;
    color: black;
    text-align: center;
    padding: 14px 16px;
    text-decoration: none;
    transition: 0.3s;
    font-size: 17px;
}

ul.tab li a:hover {
    background-color: #ddd;
}

ul.tab li a:focus, .active {
    background-color: #ccc;
}

.tabcontent {
    display: none;
    padding: 6px 12px;
    border: 1px solid #ccc;
    border-top: none;
}
</style>
<body>

<p style="text-align:center; font-size:300%">VMWARE VSPHERE RAPORT</p>

<ul class="tab">
  <li><a href="javascript:void(0)" class="tablinks" onclick="openTab(event, 'VMS')">VMS</a></li>
  <li><a href="javascript:void(0)" class="tablinks" onclick="openTab(event, 'Hosts')">HOSTS</a></li>
  <li><a href="javascript:void(0)" class="tablinks" onclick="openTab(event, 'Clusters')">CLUSTERS</a></li>
  <li><a href="javascript:void(0)" class="tablinks" onclick="openTab(event, 'rp')">RESOURCE POOLS</a></li>
  <li><a href="javascript:void(0)" class="tablinks" onclick="openTab(event, 'ds')">DATASTORES</a></li>
  <li><a href="javascript:void(0)" class="tablinks" onclick="openTab(event, 'vds')">VSPHERE DISTRIBUTED SWITCHES</a></li>
  <li><a href="javascript:void(0)" class="tablinks" onclick="openTab(event, 'issues')">ISSUES</a></li>
</ul>

<div id="VMS" class="tabcontent">
  <h3>Virtual machines</h3>
  $html_vms 
</div>

<div id="Hosts" class="tabcontent">
  <h3>ESXi hosts</h3>
  $html_hosts
</div>

<div id="Clusters" class="tabcontent">
  <h3>Clusters</h3>
  $html_clusters 
</div>

<div id="rp" class="tabcontent">
  <h3>Resource pools</h3>
  $html_rp 
</div>

<div id="ds" class="tabcontent">
  <h3>Datastores</h3>
  $html_ds 
</div>

<div id="vds" class="tabcontent">
  <h3>vSphere Distributed Switches</h3>
  $html_vds 
</div>


<div id="issues" class="tabcontent">
  <h3>Issues</h3>
  $html_issues 
</div>

<script>
function openTab(evt, cityName) {
    var i, tabcontent, tablinks;
    tabcontent = document.getElementsByClassName("tabcontent");
    for (i = 0; i < tabcontent.length; i++) {
        tabcontent[i].style.display = "none";
    }
    tablinks = document.getElementsByClassName("tablinks");
    for (i = 0; i < tablinks.length; i++) {
        tablinks[i].className = tablinks[i].className.replace(" active", "");
    }
    document.getElementById(cityName).style.display = "block";
    evt.currentTarget.className += " active";
}
</script>
     
</body>
</html> 

"@

$html_index > $Folder\index.html

Write-Host "Raport saved in $Folder"