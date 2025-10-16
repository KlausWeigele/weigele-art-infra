# Task Status — weigele.art Infrastructure & CI/CD

| Area | Task | Status | Notes |
| --- | --- | --- | --- |
| Repo & Structure | Align repository layout with PRD (infra/, workflows/, scripts/, game_cars/, docs) | ✅ Done | Matches Section 3 of PRD |
| Terraform | Implement providers, variables, outputs, backend sample | ✅ Done | Files under `infra/terraform/envs/prod/` |
| Terraform | Define full AWS stack (ACM, S3 + OAC, CloudFront, Route53, response headers, redirect function) | ✅ Done | Applied successfully; `terraform plan` clean |
| Terraform | Import existing CloudFront distribution & apply | ✅ Done | Distribution `E10XAH9K76973M` imported, outputs recorded |
| Terraform | Run `terraform fmt`, `terraform validate`, `terraform apply` | ✅ Tested | Latest apply creates/updates resources with no drift |
| GitHub Actions | Add CI workflow (`ci.yml`) | ✅ Done | Checks presence of frontend files |
| GitHub Actions | Add Terraform workflow with OIDC role `github-oidc-terraform` | ✅ Done | Runs plan/apply with backend copy step |
| GitHub Actions | Add frontend deploy workflow with OIDC role `github-oidc-deploy` | ✅ Done | Syncs assets, uploads `index.html`, invalidates CloudFront |
| Scripts | Implement `deploy.sh`, `verify_site.sh`, `teardown.sh`, `post_teardown_check.sh`, `fix_leftovers.sh` | ✅ Done | Executable, follow PRD Section 5.3 |
| Scripts | Test deploy & verify scripts against live stack | ✅ Tested | `./scripts/deploy.sh` → success, invalidation created; `./scripts/verify_site.sh` shows required headers/redirects |
| Documentation | Update `README-DEPLOY.md` with bootstrap, run, teardown steps | ✅ Done | Includes AWS account ID, security headers info |
| Documentation | Record PRD from ChatGPT prompt (`PRD.md`) | ✅ Done | Verbose requirements captured |
| AWS Prereqs | Ensure Route53 hosted zone exists and remains unmanaged by Terraform | 🔄 Pending validation | Confirm zone stays intact after operations |
| AWS Prereqs | Verify IAM roles `github-oidc-terraform` & `github-oidc-deploy` with required policies | 🔄 Pending validation | Roles referenced in workflows; policies must allow listed services |
| Monitoring/Budget | Configure budgets, alarms, or monitoring hooks | 🔄 Optional / Not Started | Mentioned in PRD Section 8 (future work) |
| Future Enhancements | Stage environment / additional QA automation / notifications | 🎯 Backlog | Refer to PRD Section 9 for ideas |
