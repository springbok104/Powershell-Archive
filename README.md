# 🛠️ PowerShell Tools

An older collection of scripts I've put together to automate processes - from file watching to Active Directory onboarding. These aren't shiny demos; they’re solutions built around real needs and use cases. Some are still handy. Most are commented, scoped, and readable… with a few quirks.

---

## 📁 Repository Structure

### `current-utility-scripts`  
Useful, active, and ready for reuse or learning.

| Script     | Description     |
| ------------- | ------------- | 
|- [`Bulk-ADUser-Creator`](./current-utility-scripts/Bulk-ADUser-Creator.ps1) | Imports and creates AD user accounts from a structured CSV.|
|- [`Monitor-Fileage`](./current-utility-scripts/Monitor-Fileage.ps1) | Tracks file age in target folders and logs when cleanup thresholds are reached. |
|- [`Watch-JobDescription`](./current-utility-scripts/Watch-JobDescription.ps1) | Monitors a designated folder for new HR job files and sends notifications. |
|- [`AD-Password-Expiry-Checker`](./current-utility-scripts/AD-Password-Expiry-Checker.ps1) | Lists AD accounts with approaching password expiry dates. |
|- [`JSON-To-CSV-Converter`](./current-utility-scripts/JSON-To-CSV-Converter.ps1) | Converts JSON arrays to readable CSV format with optional field filtering. |
|- [`NIC-Info-Exporter`](./current-utility-scripts/NIC-Info-Exporter.ps1)  | Exports local NIC configuration data for inventory or auditing. |
|- [`System-Cleanup-Tool`](./current-utility-scripts/System-Cleanup-Tool.ps1) |  Runs temp file removal, log pruning, and system tweaks on Windows machines. |


---

### `legacy-automation-examples`  
Scripts with older dependencies or may not be as relevant today.

| Script     | Description     |
| ------------- | ------------- | 
|- [`Hyperv-Deployment`](./legacy-automation-examples/Hyperv-Deployment.ps1) | Automates creation of Hyper-V VMs from CSV input, with naming, folder setup, and ISO selection. |
|- [`SQL-GUI-Backup`](./legacy-automation-examples/SQL-GUI-Backup.ps1)  | Launches a basic GUI to trigger SQL Server backups across multiple hosts or instances. |
|- [`Silent-Software-Installer`](./legacy-automation-examples/Silent-Software-Installer.ps1)  | Performs unattended installs of common desktop apps with system tweaks and cleanup steps. |

---


