# Oracle Database Automation (Grid + Database)

Ansible project to automate installation of **Oracle Grid Infrastructure** and **Oracle Database 23ai** (single-instance, no RAC) on **Oracle Enterprise Linux (OEL) 8.x**. You provide the target server **IP address** and **root password** on the command line.

## Prerequisites

- **Control machine**: Ansible 2.9+ installed
- **Target**: Fresh OEL 8.x server, reachable via SSH as `root`
- **Oracle media**: Downloaded Oracle 23ai DB and Grid software zips on the control machine

## Project structure

```
ansible-db-create/
├── README.md
├── inventory.yml          # Dynamic inventory (hosts added at runtime)
├── site.yml               # Main playbook (Grid + Database)
├── group_vars/
│   └── oracle_db_servers.yml   # Oracle paths, versions, DB name, passwords, media paths
└── roles/
    ├── oracle_common/     # OS packages, users, groups, directories
    ├── oracle_grid/       # Grid Infrastructure (ASM) install
    └── oracle_db/         # Oracle RDBMS + DBCA create database
```

## Before you run

1. **Set Oracle media paths**  
   Edit `group_vars/oracle_db_servers.yml` and set:
   - `oracle_db_software_zip` – path to Oracle 23ai DB zip on the control machine
   - `oracle_grid_software_zip` – path to Oracle 23ai Grid zip on the control machine

2. **Set ASM disks** (if using your own block devices)  
   In the same file, adjust `asm_disks` to match your target server (e.g. `/dev/sdb`, `/dev/sdc`).

3. **Optional**: Store DB/Grid/ASM passwords in Ansible Vault instead of plain text in `group_vars/oracle_db_servers.yml`.

## How to run

From the project directory, run the playbook and pass the target **IP** and **root password** with `-e`:

```bash
cd /path/to/ansible-db-create

ansible-playbook -i inventory.yml site.yml \
  -e target_host_ip=YOUR_SERVER_IP \
  -e target_root_password='YOUR_ROOT_PASSWORD'
```

**Examples:**

```bash
# Single server at 192.168.1.10
ansible-playbook -i inventory.yml site.yml \
  -e target_host_ip=192.168.1.10 \
  -e target_root_password='MyRootPass123'

# Custom host name (default is oracle1)
ansible-playbook -i inventory.yml site.yml \
  -e target_host_ip=10.0.0.5 \
  -e target_root_password='SecretRoot' \
  -e oracle_target_name=prod-db-01
```

### Required variables (command line)

| Variable               | Description                    |
|------------------------|--------------------------------|
| `target_host_ip`       | IP address of the OEL 8.x host |
| `target_root_password` | Root user password             |

### Optional variables (command line)

| Variable             | Default   | Description                          |
|----------------------|-----------|--------------------------------------|
| `oracle_target_name` | `oracle1` | Ansible host name for the target     |

If you omit `target_host_ip` or `target_root_password`, the playbook will fail with a clear message asking you to pass them.

## After the run

- Grid Infrastructure and Oracle Database are installed and a database is created (default SID/name from `group_vars/oracle_db_servers.yml`, e.g. `ORCL`).
- Connect as `oracle` on the target and use `sqlplus` or your preferred client; listener runs on port 1521 by default.

## Optional: hide root password

To avoid putting the root password on the command line, use a vault file:

```bash
# Create a vault file (e.g. vault.yml) with:
# target_root_password: "YourRootPassword"

ansible-playbook -i inventory.yml site.yml \
  -e target_host_ip=192.168.1.10 \
  -e @vault.yml \
  --ask-vault-pass
```

Or use `ansible_password` in a vault-encrypted inventory if you prefer.
