# Ansible Notes (WSL)

This repo lives on Windows, so in WSL you should work from:

/mnt/c/Users/danwr/GitHub-Repositories/munichRE-tech-assessment

Common commands:

- Encrypt Windows password file:
  ansible-vault encrypt ansible/group_vars/windows_web/vault.yml

- Edit Windows password file:
  ansible-vault edit ansible/group_vars/windows_web/vault.yml

- Run playbook:
  ansible-playbook -i ansible/inventory/hosts.ini ansible/playbook.yml --ask-vault-pass