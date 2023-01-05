# RestAD
This script create a Http.Listener that will provide a Rest API to get informations from Active Directory Domain Service.

Carrefull, the shared code, only performing "Get" actions, is not to be implemented in production environment without carefull consideration of things like:
- Code injection
- Permission
- Other scary stuff

# Prerequisites
The script rely on ActiveDirectory PowerShell Module.

# Usage
Run "Start-RestAD.ps1"

Navigate to 'http://localhost:8080/{0}/{1}?{2}' to start using the Rest API.

{0} - Endpoints are available:
/User
/Group
/Site
/Subnet

{1} - If you want to have information regarding a specific User, Group, Site or Subnet specify its Identity

{2} - Specify any parameter available in the ActiveDirectory PowerShell Module to add to your query