# weigele.art – Deploy

## Voraussetzungen
- Route 53 Hosted Zone für `weigele.art` existiert und wird _nicht_ von Terraform verwaltet (Nameserver zeigen bereits auf AWS).
- GitHub → AWS via OIDC Rollen:
  - `arn:aws:iam::093205941484:role/github-oidc-terraform`
  - `arn:aws:iam::093205941484:role/github-oidc-deploy`
- Lokal benötigte Tools: `aws` CLI, `terraform`, `jq`, `curl`.

## Terraform Backend Bootstrap
Einmalig den Remote-State vorbereiten (Namen nach Bedarf anpassen, Werte auch in `backend.tf.sample` hinterlegt):

```bash
aws s3api create-bucket --bucket weigele-terraform-state --region eu-central-1 --create-bucket-configuration LocationConstraint=eu-central-1
aws dynamodb create-table \
  --table-name weigele-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-central-1
```

## Provisionierung
```bash
cd infra/terraform/envs/prod
cp backend.tf.sample backend.tf
terraform init
terraform apply -var='domain=weigele.art' -var='bucket_name=weigele-art-site'
```

## Deploy (manuell oder via GitHub Action)
```bash
cd ../../..
./scripts/deploy.sh
```

## Verify
```bash
./scripts/verify_site.sh
```

## Security Headers
Die CloudFront-Distribution sendet über eine Response-Headers-Policy:
- HSTS (1 Jahr, includeSubDomains, preload)
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- Referrer-Policy: no-referrer-when-downgrade

Die Policy ist bereits im Default-Cache-Behavior verknüpft.

## Teardown (vorsichtig!)
```bash
./scripts/teardown.sh
./scripts/post_teardown_check.sh
```

Falls danach noch Ressourcen existieren, hilft:
```bash
./scripts/fix_leftovers.sh
# Optional ACM-Zertifikat löschen:
DELETE_UNUSED_ACM=1 ./scripts/fix_leftovers.sh
```

## Hinweise
- In den GitHub Workflows ist die AWS Account-ID `093205941484` bereits eingetragen (falls sich die Ziel-ID ändert, bitte anpassen).
- Deploy-Skript cached `index.html` kurz (60 s) und Assets 1 Jahr (`immutable`) und triggert eine CloudFront Invalidation.
- Budget-/Alarmierung optional separat konfigurieren (z. B. AWS Budgets, CloudWatch Alarme).
