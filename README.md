# munichRE-tech-assessment

## TODO: Populate and remove this

It should briefly cover:
- What is included
- Why you chose Bicep
- How the Key Vault design is production-ready
- How secrets are injected securely
- How multi-environment deployment works
- How the Azure DevOps pipeline is secured
- How the Ansible playbook handles Linux and Windows
- Assumptions, trade-offs, and enterprise improvements
- Where AI was used and how you validated it

 Use short supporting markdown files in /docs for the deeper explanation. That makes it easier to review and feels closer to a real engineering handover.

# Overview 

We are delivering a production-ready Azure Key Vault deployment built with Bicep, parameterized for dev/test/prod, secured via RBAC, soft delete, purge protection, and private endpoints, plus an Azure DevOps pipeline that validates, plans, and deploys safely, and an Ansible playbook that configures Linux and Windows web hosts while pulling secrets from Key Vault without hardcoding. 

The repository is structured to separate infrastructure, pipeline, and configuration management concerns, with supporting docs that explain security, tradeoffs, and assumptions for a clean engineering handover.

# Repository Structure

```
.
├─ README.md
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
│  ├─ ai-usage.md
│  ├─ architecture.md
│  ├─ assumptions.md
│  ├─ pipeline-security.md
│  ├─ security.md
│  └─ tradeoffs.md
└─ pipelines/
   └─ azure-pipelines.yml
```

# Task 1: Bicep Key Vault Solution 

Reasons for choosing Bicep:
- Azure-first estate: My understanding from conversations with the team is that MunichRE is an Azure first estate
- Developer Skillset: I (as the only developer working on this project) have more recently used Bicep than Terraform
- Azure Managed State: No ecternal state file to manage

Reasons we could've chosen Terraform:
- Cloud-agnostic estate: Terraform works well for hybrid / multi-cloud estates or if we want to future proof against cloud migrations
- Developer Skillset: If the team already have experience with HCL / if modules are already built in Terraform.

Production Readiness is demonstrated through:
- RBAC managed
- Soft delete 
- Purge protection
- Deny Public Access & Private Endpoints
- Explicit network rules (see `bicep/modules/keyvault.bicep` and `docs/security.md`). 
- Secrets are injected at runtime using Key Vault references and workload identity in the pipeline/Ansible flow (no secrets in source; see `pipelines/azure-pipelines.yml` and `ansible/README.md`). 
- Dev/test/prod are separated by environment‑specific parameter files in `bicep/parameters/` and the pipeline selects the right `.bicepparam` per stage (see `docs/architecture.md`).

# Task 2: Azure DevOps pipeline

TODO: 
- [ ] Explain:
  - [ ] Deployment flow
  - [ ] Service connection / workload identity / secret handling
  - [ ] Approvals and environment protections for prod
  - [ ] Validation, linting, what-if, policy checks
  - [ ] Rollback or recovery approach

# Task 3: Ansible playbook

TODO: 
- [ ] Explain:
  - [ ] OS-specific handling
  - [ ] Idempotency
  - [ ] Credential handling
  - [ ] CI/CD integration

# Security Considerations

TODO: 
- [ ] Cross-cutting controls across all tasks.

# Assumptions

TODO:
- [ ] Keep these explicit.

# Trade-offs

TODO:

# AI usage and validation

TODO: 

- [ ] Be transparent. For example:
  - [ ] Used AI to help draft initial Bicep structure and pipeline skeleton
  - [ ] Manually validated against Azure docs / your own experience
  - [ ] Reviewed naming, security controls, and deployment flow
  - [ ] Corrected any generated code that did not meet production expectations
