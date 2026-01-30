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
- SSH is **key-based only**
- `sns-ansible` has **passwordless sudo** on managed hosts
- SSH host keys are auto-accepted for new hosts (`accept-new`)

This allows Ansible to run unattended and reproducibly.

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
ansible-playbook -i inventory/hosts.ini bootstrap.yaml
````
---

### baseline.yaml
Applies common baseline configuration:
- essential packages
- time synchronization
- basic OS hygiene

Run:
````bash
ansible-playbook -i inventory/hosts.ini baseline.yaml
````
---

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
ansible-playbook -i inventory/hosts.ini patching.yaml --limit vm
ansible-playbook -i inventory/hosts.ini patching.yaml --limit gpu
````
---

## Common commands

Test connectivity:
````bash
ansible all -m ping
````
Limit execution:
````bash
ansible-playbook patching.yaml --limit vm
````
Dry-run (check mode):
````bash
ansible-playbook baseline.yaml --check
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

