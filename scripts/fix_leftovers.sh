#!/usr/bin/env bash
set -euo pipefail

DOMAIN=${DOMAIN:-weigele.art}
BUCKET=${BUCKET:-weigele-art-site}
REGION=${REGION:-eu-central-1}
DELETE_UNUSED_ACM=${DELETE_UNUSED_ACM:-0}

HZ_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN" --query 'HostedZones[0].Id' --output text | sed 's#.*/##')

disable_and_delete_cf() {
  local cf_id="$1"
  [ -z "$cf_id" ] || [ "$cf_id" = "None" ] && return 0

  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' RETURN

  local etag
  etag=$(aws cloudfront get-distribution-config --id "$cf_id" --query ETag --output text)
  aws cloudfront get-distribution-config --id "$cf_id" --output json | jq '.DistributionConfig.Enabled=false | .DistributionConfig' >"$tmpfile"
  aws cloudfront update-distribution --id "$cf_id" --if-match "$etag" --distribution-config "file://$tmpfile" >/dev/null || true

  for _ in {1..60}; do
    local status enabled
    status=$(aws cloudfront get-distribution --id "$cf_id" --query 'Distribution.Status' --output text || true)
    enabled=$(aws cloudfront get-distribution --id "$cf_id" --query 'Distribution.DistributionConfig.Enabled' --output text || true)
    [ "$status" = "Deployed" ] && [ "$enabled" = "False" ] && break
    sleep 5
  done

  local etag2
  etag2=$(aws cloudfront get-distribution-config --id "$cf_id" --query ETag --output text || true)
  [ -n "$etag2" ] && aws cloudfront delete-distribution --id "$cf_id" --if-match "$etag2" >/dev/null || true

  trap - RETURN
}

delete_dns_record() {
  local name="$1"
  local type="$2"

  [ -z "$HZ_ID" ] && return 0
  local rs
  rs=$(aws route53 list-resource-record-sets --hosted-zone-id "$HZ_ID" --query "ResourceRecordSets[?Name==\`$name.\` && Type==\`$type\`]" --output json)
  [ "$(jq 'length' <<<"$rs")" -eq 0 ] && return 0
  local cb
  cb=$(jq -c '{Changes:[{Action:"DELETE",ResourceRecordSet:.[0]}]}' <<<"$rs")
  aws route53 change-resource-record-sets --hosted-zone-id "$HZ_ID" --change-batch "$cb" >/dev/null || true
}

empty_bucket() {
  local bucket="$1"
  local region="$2"

  aws s3 rm "s3://$bucket" --recursive --region "$region" >/dev/null || true

  while true; do
    local payload
    payload=$(aws s3api list-object-versions --bucket "$bucket" --output json 2>/dev/null || echo '{}')
    local items
    items=$(jq '[.Versions[]? | {Key, VersionId}] + [.DeleteMarkers[]? | {Key, VersionId}]' <<<"$payload")
    [ "$(jq 'length' <<<"$items")" -eq 0 ] && break
    aws s3api delete-objects --bucket "$bucket" --delete "$(jq -c '{Objects: ., Quiet: true}' <<<"$items")" >/dev/null || true
  done
}

delete_bucket() {
  local bucket="$1"
  local region="$2"
  aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1 || return 0
  empty_bucket "$bucket" "$region"
  aws s3api delete-bucket --bucket "$bucket" --region "$region" >/dev/null || true
}

echo "==> Entferne verbleibende CloudFront-Distribution (falls vorhanden)"
CF_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Aliases.Items, '$DOMAIN')].Id | [0]" --output text)
disable_and_delete_cf "$CF_ID"

echo "==> Entferne DNS-Records (falls vorhanden)"
delete_dns_record "$DOMAIN" "A"
delete_dns_record "$DOMAIN" "AAAA"
delete_dns_record "www.$DOMAIN" "CNAME"

echo "==> Entferne S3-Bucket (falls vorhanden)"
delete_bucket "$BUCKET" "$REGION"

if [ "$DELETE_UNUSED_ACM" = "1" ]; then
  echo "==> Lösche ACM-Zertifikat (us-east-1) für $DOMAIN falls ungenutzt"
  CERT_ARN=$(aws acm list-certificates --region us-east-1 --query "CertificateSummaryList[?DomainName=='$DOMAIN'].CertificateArn | [0]" --output text)
  if [ -n "$CERT_ARN" ] && [ "$CERT_ARN" != "None" ]; then
    aws acm delete-certificate --certificate-arn "$CERT_ARN" --region us-east-1
    echo "ACM-Zertifikat $CERT_ARN wurde gelöscht."
  else
    echo "Kein ACM-Zertifikat für $DOMAIN gefunden."
  fi
else
  echo "ACM-Zertifikat bleibt bestehen (DELETE_UNUSED_ACM=1 setzen, um zu löschen)."
fi

echo "Aufräumarbeiten abgeschlossen."
