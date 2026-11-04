# Linux Administration & Automation Toolkit

[![Linux](https://img.shields.io/badge/Linux-Ubuntu%20%7C%20CentOS-FCC624?logo=linux&logoColor=black)](https://www.kernel.org/)
[![Bash](https://img.shields.io/badge/Language-Bash%205.0+-4EAA25?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Cron](https://img.shields.io/badge/Scheduler-Cron%20%7C%20Crond-blue)](https://man7.org/linux/man-pages/man5/crontab.5.html)
[![Security](https://img.shields.io/badge/Security-Permissions%20%26%20Auditing-red)](https://github.com/)

A modular suite of enterprise-grade Bash automation scripts engineered to automate routine Linux system administration tasks, including user and group provisioning, security permission enforcement, automated log rotation and cleanup, and scheduled system backups with SHA256 integrity verification.

Fully tested and compatible across both **Ubuntu (Debian family)** and **CentOS/RHEL (Red Hat family)** distributions.

---

## Architecture & Workflows

```
  +-------------------------------------------------------------------------+
  |                   Linux System Administration Toolkit                   |
  +-------------------------------------------------------------------------+
       │
       ├──> [manage_users.sh]
       │       ├── Provision user / group
       │       ├── Auto-detect Ubuntu (sudo) vs CentOS (wheel)
       │       ├── Enforce random passwords & chage expiry
       │       └── Batch provisioning via CSV
       │
       ├──> [set_permissions.sh]
       │       ├── Harden system files (/etc/shadow, /etc/sudoers)
       │       ├── Standardize Web/App paths (Dirs: 755, Files: 644)
       │       └── Security Audit (SUID & World-writable scans)
       │
       ├──> [log_cleanup.sh]
       │       ├── Rotate & gzip historical logs (> 2 days)
       │       ├── Purge archives exceeding retention window
       │       └── Vacuum systemd journal logs
       │
       ├──> [backup_manager.sh]
       │       ├── Tar & gzip critical directories (/etc, /var/www, /home)
       │       ├── Generate SHA-256 checksums
       │       └── Enforce 7-day backup retention
       │
       └──> [cron/install_cron.sh]
               └── Register automated recurring schedules in /etc/cron.d/
```

---

## Operating System Compatibility

| Feature | Ubuntu / Debian | CentOS / RHEL / Rocky | Implementation Note |
| :--- | :--- | :--- | :--- |
| **Admin Group** | `sudo` | `wheel` | Auto-detected dynamically |
| **Cron Daemon** | `cron` | `crond` | Auto-detected & enabled |
| **Journaling** | `journalctl` | `journalctl` | Standardized systemd vacuuming |
| **Shell** | `/bin/bash` | `/bin/bash` | POSIX & Bash 4/5 compatible |

---

## Toolkit Structure

```
linux-admin-automation-toolkit/
├── config/
│   └── toolkit.conf             # Centralized settings (retention, directories, thresholds)
├── cron/
│   ├── crontab_template         # Crontab schedule configuration
│   └── install_cron.sh          # One-click automated cron deployment script
├── examples/
│   └── users.csv                # Sample batch user creation template
├── scripts/
│   ├── backup_manager.sh        # Automated backup with SHA256 & retention
│   ├── log_cleanup.sh           # Automated log compression & journal vacuum
│   ├── manage_users.sh          # User/group management & batch provisioning
│   ├── set_permissions.sh       # Security permissions audit & enforcement
│   └── system_health_check.sh   # Live CPU, memory, disk & service monitor
├── tests/
│   └── test_syntax.sh           # Bash syntax validator
├── .gitignore
└── README.md
```

---

## Detailed Usage Guide

### 1. User & Group Management (`manage_users.sh`)

Automate user creation with enforced password change on initial login and home directory isolation (`chmod 700`):

```bash
# Add a regular user with an existing or new group
sudo ./scripts/manage_users.sh --add-user john --group developers

# Add an administrative user (adds to 'sudo' on Ubuntu or 'wheel' on CentOS)
sudo ./scripts/manage_users.sh --add-user alice --sudo

# Delete a user and automatically archive their home directory
sudo ./scripts/manage_users.sh --del-user bob --backup-home

# Lock and unlock accounts
sudo ./scripts/manage_users.sh --lock-user bad_actor
sudo ./scripts/manage_users.sh --unlock-user bad_actor

# Batch user provisioning from a CSV file
sudo ./scripts/manage_users.sh --batch examples/users.csv
```

---

### 2. Permissions Hardening & Auditing (`set_permissions.sh`)

Harden core operating system files and recursively standardize web applications:

```bash
# Harden critical system files (/etc/shadow, /etc/passwd, /etc/sudoers)
sudo ./scripts/set_permissions.sh --harden-system

# Standardize permissions for a web or application root (Dirs: 755, Files: 644)
sudo ./scripts/set_permissions.sh --fix-path /var/www/html --user www-data --group www-data

# Perform security audit for world-writable files and SUID binaries
sudo ./scripts/set_permissions.sh --audit
```

---

### 3. Log Cleanup & Compression (`log_cleanup.sh`)

Prevent root partition exhaustion by compressing older logs and pruning expired archives:

```bash
# Run cleanup with default retention (14 days)
sudo ./scripts/log_cleanup.sh

# Run cleanup targeting specific directory and retention window
sudo ./scripts/log_cleanup.sh --target /var/log/custom-app --days 30

# Perform a dry-run (simulation without deleting files)
sudo ./scripts/log_cleanup.sh --dry-run
```

---

### 4. Backup Management (`backup_manager.sh`)

Generate timestamped tar archives with checksums and rolling retention:

```bash
# Execute standard backup based on config/toolkit.conf
sudo ./scripts/backup_manager.sh

# Custom sources, destination, and retention window
sudo ./scripts/backup_manager.sh --sources "/etc,/var/www,/home" --dest /mnt/backup_drive --retention 14
```

Verification of created backup:
```bash
# Verify archive integrity via SHA-256
cd /var/backups/admin-toolkit
sha256sum -c backup_<hostname>_<timestamp>.tar.gz.sha256
```

---

### 5. Automated Scheduling via Cron (`cron/install_cron.sh`)

Deploy the entire suite into `/opt/linux-toolkit` and register scheduled execution:

```bash
sudo ./cron/install_cron.sh
```

**Configured Schedule:**
- **Daily at 03:00 AM**: System backup (`backup_manager.sh`).
- **Weekly on Sunday at 02:00 AM**: Log cleanup and journal vacuum (`log_cleanup.sh`).
- **Weekly on Monday at 04:00 AM**: Permissions and security audit (`set_permissions.sh`).

---

## Testing & Quality Assurance

Run the automated syntax test suite before deploying to production:

```bash
chmod +x tests/test_syntax.sh
./tests/test_syntax.sh
```
