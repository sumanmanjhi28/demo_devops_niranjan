# Batch user creation (create_users.sh)

This folder contains a script and a sample CSV to batch-create system users for HR.

Files added
- `create_users.sh` - main script. Supports dry-run and apply mode. Reads a CSV and creates users.
- `employees.csv` - sample CSV with 50 sample employees.

Quick steps

1. Inspect `employees.csv` and update with real HR data. CSV format (columns):

   username,full_name,uid,group,password

   - `username` may be left blank: script will generate username from full name.
   - `full_name` is the user's display name.
   - `uid` optional numeric UID; leave blank for automatic assignment.
   - `group` optional supplementary group name.
   - `password` optional plain password; if left blank and `--random-passwords` is used the script will generate a password.

2. Run a dry-run to see what will be done (recommended):

```bash
cd c:/Users/suman/project/DevOps_Session/demo_devops
bash create_users.sh --file employees.csv --dry-run --random-passwords
```

3. Apply for real (requires root):

```bash
sudo bash create_users.sh --file employees.csv --apply --random-passwords --group staff
```

Notes & safety
- The script writes created usernames and passwords (if any) to `created_credentials.csv`. Protect this file immediately.
- The script will not run any destructive operations other than creating users and setting passwords; it is still recommended to test in a safe environment first.
- If a username already exists the script will skip creation and optionally update the password if provided.

Limitations
- CSV parsing is simple and does not handle commas inside quoted fields.
- This script is intended for standard Linux systems with `useradd`, `chpasswd`, `chage` and `openssl` available.

If you want, I can:
- adapt the script to use an LDAP/AD provisioning command instead of local `useradd`.
- add support to create initial home directory contents (skeleton), copy an SSH key, or add to multiple groups.
