#!/usr/bin/env bash
set -euo pipefail

DOMAIN=${DOMAIN:-weigele.art}
BUCKET=${BUCKET:-weigele-art-site}
REGION=${REGION:-eu-central-1}

status=0

echo "==> Prüfe CloudFront-Distribution für $DOMAIN"
CF_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Aliases.Items, '$DOMAIN')].Id | [0]" --output text)
if [ -n "$CF_ID" ] && [ "$CF_ID" != "None" ]; then
  echo "WARN: CloudFront-Distribution $CF_ID existiert weiterhin."
  status=1
else
  echo "OK: Keine CloudFront-Distribution für $DOMAIN gefunden."
fi

echo
echo "==> Prüfe S3-Bucket $BUCKET"
if aws s3api head-bucket --bucket "$BUCKET" >/dev/null 2>&1; then
  echo "WARN: Bucket $BUCKET existiert noch."
  status=1
else
  echo "OK: Bucket $BUCKET wurde entfernt."
fi

echo
echo "==> Prüfe Route53-Records in Hosted Zone"
HZ_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query 'HostedZones[0].Id' --output text | sed 's#.*/##')
if [ -z "$HZ_ID" ] || [ "$HZ_ID" = "None" ]; then
  echo "WARN: Hosted Zone für $DOMAIN nicht gefunden."
  status=1
else
  apex_records=$(aws route53 list-resource-record-sets --hosted-zone-id "$HZ_ID" --query "ResourceRecordSets[?Name==\`$DOMAIN.\` && (Type==\`A\` || Type==\`AAAA\`)]" --output json)
  www_records=$(aws route53 list-resource-record-sets --hosted-zone-id "$HZ_ID" --query "ResourceRecordSets[?Name==\`www.$DOMAIN.\` && Type==\`CNAME\`]" --output json)

  if [ "$(jq 'length' <<<"$apex_records")" -gt 0 ] || [ "$(jq 'length' <<<"$www_records")" -gt 0 ]; then
    echo "WARN: DNS-Records für Apex oder www sind noch vorhanden."
    jq '.' <<<"$apex_records" | sed 's/^/  /'
    jq '.' <<<"$www_records" | sed 's/^/  /'
    status=1
  else
    echo "OK: Keine Apex/WWW-Records mehr vorhanden."
  fi

  echo
  echo "Hinweis: ACM-Validierungs-Records (falls vorhanden) dürfen bleiben:"
  val_records=$(aws route53 list-resource-record-sets --hosted-zone-id "$HZ_ID" --query "ResourceRecordSets[?contains(Name, '_acm-validation')]" --output json)
  if [ "$(jq 'length' <<<"$val_records")" -gt 0 ]; then
    jq '.' <<<"$val_records" | sed 's/^/  /'
  else
    echo "  Keine ACM-Validierungs-Records gefunden."
  fi
fi

echo
if [ "$status" -eq 0 ]; then
  echo "Post-Teardown-Check abgeschlossen: Nur Hosted Zone und ACM verbleiben."
else
  echo "Post-Teardown-Check abgeschlossen: Bitte Warnungen prüfen."
fi

exit "$status"
