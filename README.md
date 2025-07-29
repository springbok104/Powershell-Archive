## 🗃️ PowerShell Archive

An older set of scripts built to solve real problems, from onboarding users in Active Directory to monitoring file behavior across machines. These aren’t demo-perfect but they’re functional, focused, and often surprisingly handy. Most are scoped, commented, and readable… quirks and all.  

---

## 📁 Repository Structure

| Script     | Description     |
| ------------- | ------------- | 
|- [`AD-GUI-User-Creator`](https://github.com/springbok104/AD-GUI-User-Creator) | Click-to-create AD accounts with smart logic and template-driven provisioning. |
|- [`Bulk-ADUser-Creator`](https://github.com/springbok104/AD-GUI-User-Creator) | Imports and creates AD user accounts from a structured CSV.|
|- [`Monitor-Fileage`](https://github.com/springbok104/Monitor-Fileage) | Tracks file age in target folders and logs when cleanup thresholds are reached. |
|- [`Watch-JobDescription`](./current-utility-scripts/Watch-JobDescription.ps1) | Monitors a designated folder for new HR job files and sends notifications. |
|- [`AD-Password-Expiry-Checker`](./current-utility-scripts/AD-Password-Expiry-Checker.ps1) | Lists AD accounts with approaching password expiry dates. |
|- [`JSON-To-CSV-Converter`](./current-utility-scripts/JSON-To-CSV-Converter.ps1) | Converts JSON arrays to readable CSV format with optional field filtering. |
|- [`NIC-Info-Exporter`](./current-utility-scripts/NIC-Info-Exporter.ps1)  | Exports local NIC configuration data for inventory or auditing. |
|- [`System-Cleanup-Tool`](./current-utility-scripts/System-Cleanup-Tool.ps1) |  Runs temp file removal, log pruning, and system tweaks on Windows machines. |
|- [`Hyperv-Deployment`](./legacy-automation-examples/Hyperv-Deployment.ps1) | Automates creation of Hyper-V VMs from CSV input, with naming, folder setup, and ISO selection. |
|- [`SQL-GUI-Backup`](https://github.com/springbok104/SQL-GUI-Backup)  | Launches a basic GUI to trigger SQL Server backups across multiple hosts or instances. |
|- [`Silent-Software-Installer`](https://github.com/springbok104/Silent-Software-Installer)  | Performs unattended installs of common desktop apps with system tweaks and cleanup steps. |

---