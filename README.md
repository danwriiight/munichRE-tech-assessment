# munichRE-tech-assessment - Overview 

- We are delivering a **production-ready Azure Key Vault deployment built with Bicep**, parameterized for dev/test/prod, secured via RBAC, soft delete, purge protection, and private endpoints, plus an Azure DevOps pipeline that validates, plans, and deploys safely, and an Ansible playbook that configures Linux and Windows web hosts while pulling secrets from Key Vault without hardcoding. 
- The repository is structured to separate infrastructure, pipeline, and configuration management concerns, with supporting docs that explain security, tradeoffs, and assumptions for a clean engineering handover.

# Repository Structure

```
.
├─ README.md
├─ image.png
├─ PATH
├─ ansible/
│  ├─ README.md
│  ├─ playbook.yml
│  ├─ group_vars/
│  │  ├─ linux_web.yml
│  │  └─ windows_web/
│  │     └─ vault.yml
│  └─ inventory/
│     └─ hosts.ini
├─ bicep/
│  ├─ main.bicep
│  ├─ modules/
│  │  └─ keyvault.bicep
│  └─ parameters/
│     ├─ dev.bicepparam
│     ├─ test.bicepparam
│     └─ prod.bicepparam
├─ docs/
│  └─ pipeline-security.md
└─ pipelines/
   └─ azure-pipelines.yml
```

# Task 1: Bicep Key Vault Solution 

# IaC Tooling Selection 

### Reasons for choosing Bicep:
- **Azure-first estate**: My understanding from conversations with the team is that MunichRE is an Azure first estate
- **Developer Skillset**: I (as the only developer working on this project) have more recently used Bicep than Terraform
- **Azure Managed State**: No external state file to manage

### Reasons we could've chosen Terraform:
- **Cloud-agnostic estate**: Terraform works well for hybrid / multi-cloud estates or if we want to future proof against cloud migrations
- **Developer Skillset**: If the team already have experience with HCL / if modules are already built in Terraform.

## Production Readiness
Production Readiness is demonstrated through:
- **RBAC managed:** Access is controlled centrally via Azure AD roles, enabling least privilege and auditable, scalable permission management.
- **Soft delete:** Protects against accidental or malicious deletion by allowing recovery of deleted secrets and vaults within a retention period. 
- **Purge protection:** Prevents permanent deletion even after soft delete, ensuring critical secrets cannot be irreversibly removed.
- **Deny Public Access:** Restricts exposure from the public internet by enforcing a default deny network posture, reducing the overall attack surface.
- **Explicit network rules:** (see `bicep/modules/keyvault.bicep`) Enforces tightly controlled access by allowing only approved IPs or networks, complementing the default deny model.
- **Secrets can be injected at runtime using Key Vault references and service principal with federated identity in the pipeline:** (no secrets in source; see `pipelines/azure-pipelines.yml). Removes secrets from code and pipelines, reducing leakage risk and enabling secure, dynamic secret retrieval.
- **Environment separation via parameter files:** (in bicep/parameters/ with pipeline stage selection) Ensures consistent deployments while isolating configurations across dev/test/prod, reducing risk of cross-environment impact.

Planned Enhancements:
- **Private Endpoints** Will enable fully private connectivity over the Azure backbone, removing reliance on public endpoints.

## Secret Injection
- As above, we use a **service principal with federated identity** (for Azure DevOps Pipelines)
- Other secret injection patterns incl:
    - **Managed Identity** - best for Azure Services; managed without credentials 
    - **Service Principal w/ Client Secret** - best for CI/CD
    - **Client Certificate Authentication** - best for on-prem apps or third party integrations

## Multi Environment Setup
- In our solution, we use **separate bicep parameter files** and **separate resource groups with strict RBAC** to manage separate environments
- An alternative for managing multi-env setups is **separate subscriptions per envt** with identical templates and different service connections (great for managing billing separately per env)

# Task 2: Azure DevOps pipeline

![alt text](image.png)

- The pipeline is organized into stage-based deployments (dev → test → prod) with a consistent flow: 
    - **validate and lint** Bicep
    - run **`what-if`** against the target environment
    - then **deploy** using the environment-specific `.bicepparam` file (see `pipelines/azure-pipelines.yml` and `bicep/parameters/`). 
    - Each stage could consume outputs from the previous one only when appropriate, keeping environments isolated while still enabling promotion.
- Authentication uses a **service connection configured for workload identity (OIDC)** rather than secrets. The pipeline never stores static credentials; it requests short‑lived tokens at runtime and retrieves secrets from Key Vault only when needed for deployment tasks (no secrets in repo or variable groups).
- Production is protected via **Manual Approvals** (person to review the Production WhatIf for unintended actions)
- **Quality and safety checks** include Bicep compilation, linting, `what-if` previews, and (optionally) policy compliance checks before apply. This makes drift and non‑compliant changes visible before any deployment happens.
- **Rollback** is handled by redeploying the last known‑good build (artifacts are immutable) or, for infrastructure, by reverting to the previous parameter set and re‑running the deployment. Because Key Vault is declarative and protected by soft delete/purge protection, recovery is safe even if a change needs to be undone.

Further Enhancements:
- Protection via **Azure DevOps Environments** with required approvals and checks. This includes manual approval gates and optional branch policies on the main branch so only reviewed changes can reach prod.
- **Azure Policy** can audit, deny, or sometimes remediate non-compliant resources, and it evaluates whether deployed resources meet organisational rules

# Task 3: Ansible playbook

## Explanation
- **OS-specific handling:** 
    - The playbook splits Linux and Windows into separate plays targeting `linux_web` and `windows_web` inventory groups. 
    - Linux uses `become: true` to run with elevated privileges and shell-level package/service commands
    - Windows uses `win_chocolatey` and `win_service` to install and manage Apache. Chocolatey is required because Windows does not have a native package manager for Apache; the `apache-httpd` package is distributed via Chocolatey, which provides a consistent, automatable install/upgrade path.
- **Idempotency:** The Windows tasks are idempotent because the modules enforce `state: present/started`. 
- **Credential handling:** Windows credentials are kept in `ansible/group_vars/windows_web/vault.yml` and encrypted with Ansible Vault, and the playbook is run with `--ask-vault-pass`. Linux authentication should use SSH keys or agent forwarding rather than passwords.
- **CI/CD integration:** Run `ansible-playbook` from a pipeline job on a self‑hosted agent with network access to the target hosts. Store the Vault password as a secret variable (or secure file) and pass it at runtime, and keep inventory and playbooks versioned so deployments are repeatable and auditable.

Future Enhancements:
- The Linux task uses a `raw` command (`apt-get ... && systemctl ...`), which is **not idempotent** and bypasses Ansible’s state model. For production, replace it with `apt`/`yum` and `service`/`systemd` modules so repeated runs produce no changes.

# Security Considerations

- **Identity-first access:** Use Azure AD identities (RBAC, managed identities, workload identity/OIDC) and avoid long-lived secrets.
- **Least privilege:** Grant only required roles and scope to resource groups/environments; separate dev/test/prod access.
- **Network isolation:** Deny public access by default and restrict ingress/egress via explicit rules and private endpoints (in the future).
- **Secret hygiene:** No secrets in source or pipeline variables; retrieve from Key Vault at runtime only.
- **Change safety:** Validate, lint, and run `what-if` before deploy; require approvals for production.
- **Auditability:** Use immutable pipeline artifacts and centralised logs for deployment and access events.
- **Recoverability:** Enable soft delete and purge protection; treat IaC as the source of truth for rollback.

# Assumptions

## Explicit Assumptions
- The target Azure subscription(s) and resource groups exist (or are created outside this repo) and the deployer has Contributor on the RG scope plus Key Vault Administrator or equivalent.
- Azure DevOps has a service connection configured for workload identity (OIDC) with permission to deploy into the target subscription.
- The Key Vault name is globally unique
- We have access to either a configured self-hosted agent or a Microsoft-hosted agent that is approved for use.
- The self-hosted pipeline agent has Azure CLI and Bicep CLI available and can reach Azure control plane endpoints.
- Ansible control node can reach target hosts over SSH/WinRM and credentials are managed outside source control (vaulted or injected at runtime).

# Trade-offs

## Key Decisions And Trade-offs

- **Bicep vs Terraform:** Bicep simplifies Azure-native deployments and avoids external state, but reduces portability to other clouds.
- **Single shared template with env parameters:** Keeps logic DRY and consistent, but constrains per-environment deviations to parameter inputs.
- **RBAC over access policies:** Centralizes identity control and scales better, but requires Azure AD role management maturity.
- **Deny public access + explicit rules:** Strong default posture, but increases friction for ad-hoc access and troubleshooting.
- **Workload identity in pipeline:** Eliminates long-lived secrets, but depends on correct OIDC configuration and Azure DevOps setup.
- **What-if gating:** Improves change visibility, but adds time to pipeline execution.
- **Ansible raw commands (current Linux):** Fast to implement, but not idempotent and less reliable for long-term operations.

# AI usage and validation

- Draft the **initial Bicep structure and Azure DevOps pipeline skeleton**. I then **manually validated the output against Azure documentation** and my own experience, reviewed naming, security controls, and deployment flow, and corrected any generated content that did not meet production expectations.
- Produce an **initial documentation draft** quickly, and then manually validated it for accuracy.
- **Basic repo structure** 
- Relied more heavily on AI products for the Ansible task as, for clarity, this is a blindspot of mine that I enjoyed spending some time closing throughout this task. 
