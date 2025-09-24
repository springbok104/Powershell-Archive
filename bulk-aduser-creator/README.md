# 📦 Bulk AD User Creator

Reads a structured CSV file and creates new Active Directory user accounts based on the entries provided. It supports optional password setting, OU assignment, and handling of missing data or failure.

Originally written for internal onboarding flows, it’s now generalized for use in any lab, test, or rollout scenario.

---

## 🧩 Features

- Imports users from a CSV file
- Supports optional password column
- Assigns to OU from either the CSV path or an override variable
- Creates disabled accounts when passwords are missing
- Handles errors cleanly with log-style output

---

## ⚙️ Configurable Variables & Parameters

| Parameter / Variable        | Description |
|-----------------------------|-------------|
| `-CSV_Path`                 | Full path to the input CSV file |
| `-Password_Column_name`     | Name of the column that contains password (optional) |
| `-Override_OU`              | Distinguished Name (DN) of the target OU for all accounts (optional override) |
| `$CSV_Delimiter`            | CSV delimiter (default is comma) |

---

## 🧪 Requirements

- PowerShell 5.1 or later  
- ActiveDirectory module  
- Domain admin credentials  

---

## 🚀 Usage

PS C:\Scripts> .\bulk-aduser-creator.ps1 `
    -CSV_Path "C:\Scripts\users.csv" `
    -Password_Column_name "password" `
    -Override_OU "OU=NewUsers,DC=example,DC=com"

---

## 📁 Sample CSV Format

objectClass,sAMAccountName,dn,password
User,jdoe,"CN=John Doe,OU=Sales,DC=example,DC=com",P@ssw0rd123
User,asmith,"CN=Alice Smith,OU=HR,DC=example,DC=com",Secure!Pass456
User,btaylor,"CN=Bob Taylor,OU=IT,DC=example,DC=com",

---

## ⚠️ Disclaimer

This tool is shared for educational and internal automation use. It may require changes to suit your AD layout or security policies. Always test in a controlled environment before production rollout.