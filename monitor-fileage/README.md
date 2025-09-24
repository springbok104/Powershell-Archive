# 🕒 Monitor File Age & Alert

Scans a target folder for files older than a specified number of minutes and sends an alert email if any are detected. It supports filtering by extension or filename pattern and runs unattended using SMTP credentials.

---

## 📦 Features

- Monitors folders for aging files
- Supports extension filtering (`csv|xml`, etc.) or filename patterns (`*_*.csv`)
- Sends alert email listing matched files
- Customizable delay threshold (in minutes)
- SMTP authentication support

---

## 📋 Configuration Overview

| Variable           | Purpose                                                      |
|-------------------|--------------------------------------------------------------|
| `$minutesOld`      | Time (in minutes) after which a file is considered "old"     |
| `$folder`          | Directory path to monitor                                     |
| `$searchType`      | `"pattern"` to use `$searchPattern`; leave blank for extension filtering |
| `$searchPattern`   | Wildcard pattern (e.g. `*_*.csv`)                             |
| `$fileType`        | Pipe-separated list of extensions (e.g. `"csv|xml"`)         |
| `$mailUser` / `$mailPass` | SMTP credentials used to send the alert email        |
| `$mailTo`          | Email recipient                                               |

---

## 🧪 Requirements

- PowerShell 5.x or later
- SMTP access (for email alerts)
- Secure handling of credentials (do not commit passwords to public repos)

---

## 📧 Example Email Output

Hello,

There appears to be an old file or old files in the monitored folder:

Monitored Directory : C:\myfolder Old Files : file_01.csv, file_02.xml Age of Files : Older than 60 minutes

---

## ⚠️ Disclaimer

This script was built for internal use, learning, and practical automation. It’s shared as-is, without guarantees, and may need adjustment before use in production environments. Please review the logic, email settings, and file paths carefully to suit your context.
