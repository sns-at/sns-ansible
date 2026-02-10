# sns-ansible

This repository contains the Ansible control configuration for SNS AI compute infrastructure.

It is used to:
- centrally manage baseline configuration on Linux machines
- apply OS patching in a controlled way
- manage local users and access
- refresh Docker Compose–based workloads in a controlled, reproducible way
- bootstrap and operate via a dedicated Ansible service user (sns-ansible)

The Ansible control node currently runs on the n8n VM, and the repository is located at:

/home/sns-ansible/infra-ansible

---

## Managed nodes

The inventory currently contains:

- Control node
  - n8n VM (runs Ansible itself)

- VMs
  - application / service VMs (e.g. n8n, qdrant, postgres, etc.)

- GPU nodes
  - DGX systems used for AI workloads

Nodes are grouped in the inventory as:
- control
- vm
- gpu
- docker

Groups allow different behavior (e.g. patching, reboots, container refresh).

---

## Authentication & access model

- All automation runs as the sns-ansible user
- SSH access is key-based
- Managed local users are centrally defined and enforced via Ansible
- Selected users are placed into shared Unix groups
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

---

## Repository structure
````bash
.
├── README.md
├── ansible.cfg
├── files/ssh_keys/
├── inventory/
│   ├── hosts.ini
│   ├── group_vars/all.yaml
│   └── host_vars/
├── playbooks/
│   ├── bootstrap.yaml
│   ├── baseline.yaml
│   ├── patching.yaml
│   ├── compose-refresh.yaml
│   ├── ssh-hardening.yaml
│   └── users.yaml
├── run-patching.sh
└── run-compose-refresh.sh
````
---

## Key playbooks

bootstrap.yaml  
Creates the sns-ansible user, installs SSH keys, configures passwordless sudo.

baseline.yaml  
Applies common OS baseline configuration.

patching.yaml  
Applies OS updates with group-specific behavior.

users.yaml  
Manages local users, SSH keys, groups, and directory permissions.

compose-refresh.yaml  
Refreshes Docker Compose workloads:
- pulls latest images
- recreates containers only if the image digest changed

Each host defines its own container scope via inventory/host_vars/<host>.yaml:

compose_base_dir: /usr/local/bin/container/04_DGX-99

---

## Common commands

Test connectivity:
````bash
ansible all -m ping
````
Run patching:
````bash
ansible-playbook -i inventory/hosts.ini playbooks/patching.yaml
````

Dry run:
````bash
ansible-playbook playbooks/baseline.yaml --check
````
---

## Add Linux machine to inventory

Add host to inventory/hosts.ini, then bootstrap:
````bash
ansible-playbook -i inventory/hosts.ini playbooks/bootstrap.yaml \
  --limit <host> \
  -e ansible_user=snsadmin \
  --ask-pass --ask-become-pass
````
---

## Schedules

Monthly OS patching
- cron: 0 3 3 * *
- script: run-patching.sh
- log: /home/sns-ansible/ansible-patching.log
- mail: cloud.status@sns.at

Monthly Docker Compose refresh
- cron: 15 3 3 * *
- script: run-compose-refresh.sh
- log: /home/sns-ansible/ansible-compose-refresh.log
- mail: cloud.status@sns.at
- behavior:
  - pulls latest images
  - containers are recreated only when image digests change

---

## Git usage

- Repository hosted in SNS GitHub org
- SSH over port 443
- No personal access tokens
- Operational Git access on hosts is handled by the sns-ansible service user

---

## Notes & future work

- move Ansible to a dedicated control VM
- refactor playbooks into roles
- integrate centralized identity (AD / Entra ID)
- introduce Ansible Vault for secrets
