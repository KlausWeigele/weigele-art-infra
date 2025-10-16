# PRD — weigele.art: Static Web Infra & CI/CD (Codex CLI)

## 0) Kontext & Ziel
- Projekt: `game_cars/` (reines Frontend: `index.html`, `main.js`, `styles.css`).
- Ziel: Produktionsfähiger Stack auf AWS inkl. Terraform (IaC), S3 + CloudFront (OAC), ACM (us-east-1), Route53 Records, Security-Header, www→apex Redirect per CloudFront Function, GitHub Actions (CI/CD via OIDC) und Skripte (deploy/verify/teardown/audit).
- Ist-Annahme: Route53 Hosted Zone für `weigele.art` existiert bereits (Nameserver bei Namecheap zeigen auf AWS).
- Nicht-Ziele: Hosted Zone anlegen/ändern; App-Code in `game_cars/` modifizieren.

## 1) Architektur (Soll)

```
User → Route53 (weigele.art) → CloudFront (TLS, WAF-ready)
                                    │
                                    ▼
                              S3 Bucket (privat)
                         (Zugriff nur via OAC/CF-SigV4)
```

- ACM-Zertifikat nur in `us-east-1` (für CloudFront).
- S3 privat, OAC aktiv.
- Security Headers via CloudFront Response Headers Policy.
- Redirect: `www.weigele.art` → `https://weigele.art{uri}` per CloudFront Function.

## 2) Anforderungen & Randbedingungen
- DNS: Nur Records managen (A/AAAA auf CloudFront; CNAME www→apex). Die Hosted Zone darf nicht gelöscht werden.
- Caching:
  - `index.html`: `Cache-Control: max-age=60, must-revalidate`.
  - Assets (`.js`, `.css`, Bilder): `Cache-Control: max-age=31536000, immutable`.
- Sicherheit: HSTS (preload, includeSubDomains), `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: no-referrer-when-downgrade`.
- CloudFront Function: Domain parametrisiert (keine Hardcodes).
- CI/CD: GitHub Actions mit OIDC. Keine statischen AWS-Schlüssel im Repo.

## 3) Repo-Struktur (Soll)

```
infra/terraform/envs/prod/
  providers.tf
  variables.tf
  outputs.tf
  backend.tf.sample       # S3+DynamoDB Remote State (nur Sample)
  main.tf                 # gesamte Infra (siehe unten)
.github/workflows/
  ci.yml                  # leichter CI-Check
  terraform.yml           # Plan/Apply via OIDC
  deploy-frontend.yml     # Buildless Sync + CF Invalidation via OIDC
scripts/
  deploy.sh
  verify_site.sh
  teardown.sh
  post_teardown_check.sh
  fix_leftovers.sh
README-DEPLOY.md
game_cars/
  index.html
  main.js
  styles.css
```

## 4) Konfiguration & Platzhalter
- Domain: `weigele.art`
- Bucket: `weigele-art-site`
- Regionen: `eu-central-1` (S3/CloudFront API/Route53), `us-east-1` (ACM)
- GitHub→AWS OIDC Rollen (Platzhalter):
  - `arn:aws:iam::<ACCOUNT_ID>:role/github-oidc-terraform`
  - `arn:aws:iam::<ACCOUNT_ID>:role/github-oidc-deploy`
- In Workflows `<ACCOUNT_ID>` nicht vergessen.

## 5) Aufgaben für Codex CLI (Dateien erzeugen/aktualisieren)

**Wichtig**
- Keine Änderungen an `game_cars/*`.
- Hosted Zone darf nicht gelöscht werden.
- Terraform so schreiben, dass `terraform destroy` nur CloudFront/S3/Records/Function entfernt, aber nicht die Zone.
- OAC-Bucket-Policy mit `AWS:SourceArn = arn:aws:cloudfront::ACCOUNT:distribution/...` (ohne Regions-Teil).

### 5.1 Terraform – `infra/terraform/envs/prod/`
- `providers.tf`
  - AWS Provider standard `eu-central-1` + Alias `us_east_1` für ACM.
  - S3-Backend nicht fest verdrahten (nur `backend.tf.sample`).
- `variables.tf`: `domain` (string), `bucket_name` (string), `tags` (map(string), default {}).
- `outputs.tf`: `cloudfront_domain`, `cloudfront_id`, `site_bucket`.
- `backend.tf.sample`: S3-State + DynamoDB Lock (als Beispiel, wird vom Nutzer kopiert).
- `main.tf` (gesamt):
  - `data "aws_route53_zone"` (Zone lesen).
  - `aws_acm_certificate` + `aws_route53_record` für Validation + `aws_acm_certificate_validation` (us-east-1).
  - `aws_s3_bucket` + Ownership + PublicAccessBlock.
  - `aws_cloudfront_origin_access_control` (OAC).
  - `aws_cloudfront_response_headers_policy` (Security Headers).
  - `aws_cloudfront_function` (www→apex) mit `${local.domain}` Interpolation.
  - `aws_cloudfront_distribution`:
    - `aliases = [local.domain, "www.${local.domain}"]`
    - `default_root_object = "index.html"`
    - `viewer_protocol_policy = "redirect-to-https"`
    - `response_headers_policy_id = <Security-Policy-ID>`
    - `function_association` (viewer-request) = CloudFront Function
  - `data "aws_iam_policy_document"` + `aws_s3_bucket_policy` (nur CloudFront darf lesen).
  - `aws_route53_record`:
    - A Alias apex → CloudFront
    - AAAA Alias apex → CloudFront
    - CNAME www → apex

### 5.2 GitHub Actions – `.github/workflows/`
- `ci.yml`: schneller Check (existieren die drei Frontend-Dateien).
- `terraform.yml`: On PR → Plan; On push main → Apply; OIDC Role `github-oidc-terraform`.
- `deploy-frontend.yml`: On push main (Pfade `game_cars/**`) → `aws s3 sync` (Assets) + `aws s3 cp` (index) + `cloudfront create-invalidation`. OIDC Role `github-oidc-deploy`.

### 5.3 Scripts – `scripts/`
- `deploy.sh`: Sync & CloudFront Invalidation (nutzt `BUCKET`, `DOMAIN`, `REGION` Defaults).
- `verify_site.sh`: `curl -I` auf Apex, WWW, CloudFront-Domain.
- `teardown.sh`: Disable/Delete CloudFront, löscht A/AAAA/CNAME, leert+löscht S3 (versioned tolerant).
- `post_teardown_check.sh`: prüft „nur Hosted Zone bleibt“; zeigt ggf. Validation-CNAMEs.
- `fix_leftovers.sh`: falls CloudFront/S3/DNS noch leben → idempotent entfernen (optional `DELETE_UNUSED_ACM=1`).

### 5.4 README – `README-DEPLOY.md`
- Bootstrap: State Bucket + Dynamo-Table anlegen (Befehle aufführen).
- Run-Steps:

```bash
cd infra/terraform/envs/prod
cp backend.tf.sample backend.tf
terraform init
terraform apply -var='domain=weigele.art' -var='bucket_name=weigele-art-site'
cd ../../..
./scripts/deploy.sh
./scripts/verify_site.sh
```

- Destroy/Checks: `./scripts/teardown.sh` & `./scripts/post_teardown_check.sh`.

## 6) CI/CD – OIDC Rollen (Beschreibung, keine Datei)
- Terraform-Role: Rechte für ACM (us-east-1), CloudFront, S3 (Bucket + Policy), Route53 (Records in Zone), optional `iam:PassRole` (wenn nötig).
- Deploy-Role: minimal `s3:List/Put/Delete` (Bucket+/*), `cloudfront:CreateInvalidation`, `cloudfront:ListDistributions`.
- Trust Policy: OIDC Provider `token.actions.githubusercontent.com`, `aud=sts.amazonaws.com`, `sub=repo:<OWNER>/<REPO>:*`.

## 7) Akzeptanzkriterien (Definition of Done)
1. `terraform apply` erzeugt:
   - Validiertes ACM in `us-east-1`.
   - S3 privat + OAC-Policy korrekt (`SourceArn` ohne Region).
   - CloudFront aktiv mit Security-Headers & CloudFront Function (www→apex).
   - Route53: Apex A/AAAA → CloudFront, CNAME www→apex.
2. `./scripts/deploy.sh`:
   - Assets mit `immutable`, HTML mit `max-age=60`.
   - CloudFront Invalidation erstellt.
3. `./scripts/verify_site.sh`:
   - `https://weigele.art/` → 200,
   - `https://www.weigele.art` → 301 auf Apex,
   - `https://<CF_DOMAIN>/` → 200.
4. `./scripts/teardown.sh` + `./scripts/post_teardown_check.sh`:
   - Keine CloudFront-Distribution, kein S3-Bucket, keine A/AAAA/CNAME; Hosted Zone bleibt.
   - Validation-CNAMEs optional (unschädlich).

## 8) Nicht-funktionale Anforderungen
- Kosten-Guardrail: CloudFront `PriceClass_100`; Logging optional; Budgets/Alerts (Hinweis im README).
- Sicherheit: keine Plain AWS Keys im Repo; alle Deploys via OIDC.
- Idempotenz: Skripte und Terraform mehrfach ausführbar ohne Seiteneffekte.

## 9) Ausgaben/Nutzen für den Nutzer (nach Abschluss)
- Liste der erzeugten/aktualisierten Dateien mit Pfaden.
- Kurzanleitung (Befehle in richtiger Reihenfolge):

```bash
cd infra/terraform/envs/prod
cp backend.tf.sample backend.tf
terraform init
terraform apply -var='domain=weigele.art' -var='bucket_name=weigele-art-site'
cd ../../..
./scripts/deploy.sh
./scripts/verify_site.sh
```

- Hinweis, wo `<ACCOUNT_ID>` zu ersetzen ist.

## 10) Don'ts
- Keine Änderung/Löschung an `game_cars/*`.
- Keine Löschung der Route53 Hosted Zone.
- Kein Festschreiben von Secrets oder PEMs im Repo.
- Keine Hardcodes der Domain im Function-Code (Interpolation nutzen).
