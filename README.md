# sns-ansible

This repository contains the Ansible control configuration for SNS AI compute infrastructure.

It is used to:
- centrally manage baseline configuration on Linux machines
- apply OS patching in a controlled way
- bootstrap and operate via a dedicated Ansible service user (`sns-ansible`)

The Ansible control node currently runs on the **n8n VM**, and the repository is located at:

/home/sns-ansible/infra-ansible

---

## Managed nodes

The inventory currently contains:

- **Control node**
  - n8n VM (runs Ansible itself)

- **VMs**
  - application / service VMs (e.g. qdrant, postgres, etc.)

- **GPU nodes**
  - DGX systems used for AI workloads

Nodes are grouped in the inventory as:
- `control`
- `vm`
- `gpu`

This allows different behavior (e.g. patching & reboots) per group.

---

## Authentication & access model

- All automation runs as the **`sns-ansible`** user
- SSH access is **key-based**
- Managed local users are centrally defined and enforced via Ansible
- Selected users are placed into shared Unix groups to grant access to common directories
- Directory ownership and permissions are enforced to prevent configuration drift

This allows Ansible to run unattended and reproducibly.

---

## User and group management

Local users are centrally managed via Ansible:

- users are created if missing
- SSH public keys are installed from the repository
- passwords may be disabled to enforce key-based access
- users are added to predefined Unix groups
- shared directories are checked for:
  - existence
  - correct group ownership
  - correct permissions

This ensures consistent access control across all managed hosts.

---

## Repository structure

infra-ansible/<br>
├── inventory/<br>
│   └── hosts.ini<br>
├── ansible.cfg<br>
├── bootstrap.yaml<br>
├── baseline.yaml<br>
├── patching.yaml<br>
└── README.md

---

## Key playbooks

### bootstrap.yaml
One-time bootstrap playbook:
- creates the `sns-ansible` user on all hosts
- installs SSH keys
- configures passwordless sudo

Run once per host:
````bash
ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yaml
````

### baseline.yaml
Applies common baseline configuration:
- essential packages
- time synchronization
- basic OS hygiene

Run:
````bash
ansible-playbook -i inventory/hosts.ini playbooks/baseline.yaml
````

### patching.yaml
Applies OS updates with group-specific behavior.

VMs:
- dist-upgrade
- automatic reboot if required

GPU nodes:
- conservative upgrade
- no automatic reboot

Run examples:
````bash
ansible-playbook -i inventory/hosts.ini playbooks/patching.yaml --limit vm
ansible-playbook -i inventory/hosts.ini playbooks/patching.yaml --limit gpu
````

### users.yaml
Manages local user access:

- user creation and group membership
- SSH authorized keys
- optional password disabling
- shared group creation
- shared directory ownership and permission enforcement

Run examples:
````bash
ansible-playbook -i inventory/hosts.ini playbooks/patching.yaml --limit vm
````

---

## Common commands

Test connectivity:
````bash
ansible all -m ping
````
Limit execution:
````bash
ansible-playbook playbooks/patching.yaml --limit vm
````
Dry-run (check mode):
````bash
ansible-playbook playbooks/baseline.yaml --check
````

---

## Add Linux-Machine to Ansible-Inventory
Example: snsgb11
### Edit inventory
Add/assign new host to according group in [hosts.ini](inventory/hosts.ini) 
````bash
[gpu]
sbsgb10 ansible_host=...
snsgb11 ansible_host=<NEW_IP_OR_DNS>
````

### Bootstrap
````bash
cd /home/sns-ansible/infra-ansible

ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yaml \
  --limit snsgb11 \
  -e ansible_user=snsadmin \
  --ask-pass --ask-become-pass
````

### Apply initial playbooks
````bash
# optional connection test:
ansible -i inventory/hosts.ini snsgb11 -m ping

ansible-playbook -i inventory/hosts.ini playbooks/users.yaml --limit snsgb11
ansible-playbook -i inventory/hosts.ini playbooks/baseline.yaml --limit snsgb11
# optional:
ansible-playbook -i inventory/hosts.ini playbooks/ssh-hardening.yaml --limit snsgb11
````

---

## Git usage

- Repository is hosted in the SNS GitHub organization
- Authentication uses **SSH over port 443**
- No personal access tokens (PATs)

Typical workflow:
````bash
git status
git add .
git commit -m "Describe change"
git push
````
---

## Notes & future work

Planned or possible next steps:
- move Ansible to a dedicated control VM
- refactor playbooks into roles
- integrate centralized identity (e.g. Entra ID / AD via SSSD)
- add security hardening baselines
- introduce Ansible Vault for secrets if needed

This repository intentionally favors clarity and simplicity while the setup evolves.

