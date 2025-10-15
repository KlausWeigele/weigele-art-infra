#!/usr/bin/env bash
set -euo pipefail

BUCKET=${BUCKET:-weigele-art-site}
REGION=${REGION:-eu-central-1}
DOMAIN=${DOMAIN:-weigele.art}

aws s3 sync game_cars s3://"$BUCKET" --exclude "index.html" --cache-control "max-age=31536000, immutable" --delete --region "$REGION"
aws s3 cp game_cars/index.html s3://"$BUCKET"/index.html --cache-control "max-age=60, must-revalidate" --metadata-directive REPLACE --region "$REGION"
CF_ID=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Aliases.Items, '$DOMAIN')].Id | [0]" --output text)
aws cloudfront create-invalidation --distribution-id "$CF_ID" --paths "/*"
echo "Deployed → https://$DOMAIN"
