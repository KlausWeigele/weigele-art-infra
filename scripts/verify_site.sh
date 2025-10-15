#!/usr/bin/env bash
set -euo pipefail

DOMAIN=${DOMAIN:-weigele.art}
CF_DOMAIN=$(aws cloudfront list-distributions --query "DistributionList.Items[?contains(Aliases.Items, '$DOMAIN')].DomainName | [0]" --output text)

curl -I "https://$DOMAIN/"
curl -I "https://www.$DOMAIN/"
curl -I "https://$CF_DOMAIN/"
