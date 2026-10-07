#!/usr/bin/env bash
# Lab 2 (S3) - full command sequence from lab-2-s3.md.
#
# Works against ANY S3-compatible endpoint configured on the AWS "default"
# profile (local moto mock for a quick dry-run today, or the real Onyxia
# bucket once you paste the "S3 Profile Details" script there).
#
# Usage:
#   LAB_BUCKET_NAME=<bucket> S3_ENDPOINT_URL=<url> ./s3/run_lab2.sh
# On Onyxia, LAB_BUCKET_NAME and S3_ENDPOINT_URL are already derived from
# $KUBERNETES_NAMESPACE / $AWS_S3_ENDPOINT as shown in the lab.
set -euo pipefail
cd "$(dirname "$0")/.."

: "${LAB_BUCKET_NAME:?set LAB_BUCKET_NAME first}"
: "${S3_ENDPOINT_URL:?set S3_ENDPOINT_URL first}"

echo "== Upload (PUT) =="
aws s3 --profile 'default' cp users.csv "s3://$LAB_BUCKET_NAME/bronze/users.csv"

echo "== List =="
aws s3 --profile 'default' ls "s3://$LAB_BUCKET_NAME/bronze/"
aws s3 --profile 'default' ls "s3://$LAB_BUCKET_NAME/" --recursive

echo "== Download (GET) =="
aws s3 --profile 'default' cp "s3://$LAB_BUCKET_NAME/bronze/users.csv" ./users_downloaded.csv
diff users.csv users_downloaded.csv && echo "identical"

echo "== Move/rename =="
aws s3 --profile 'default' mv "s3://$LAB_BUCKET_NAME/bronze/users.csv" "s3://$LAB_BUCKET_NAME/bronze/users_renamed.csv"
aws s3 --profile 'default' ls "s3://$LAB_BUCKET_NAME/bronze/"

echo "== Delete =="
aws s3 --profile 'default' rm "s3://$LAB_BUCKET_NAME/bronze/users_renamed.csv"

echo "== Metadata =="
aws s3 --profile 'default' cp users.csv "s3://$LAB_BUCKET_NAME/bronze/users.csv" \
  --metadata "source=dataset_users.py,version=1,rows=50"
aws s3api --profile 'default' head-object --bucket "$LAB_BUCKET_NAME" --key bronze/users.csv | jq '.Metadata'

echo "== Presigned URL =="
URL=$(aws s3 --profile 'default' presign "s3://$LAB_BUCKET_NAME/bronze/users.csv" --expires-in 300)
echo "$URL"
curl -s "$URL" | head -n 3

echo "== Multipart upload =="
dd if=/dev/urandom of=large_dataset.bin bs=1m count=20 2>/dev/null
aws s3 --profile 'default' cp large_dataset.bin "s3://$LAB_BUCKET_NAME/large/dataset.bin"
aws s3api --profile 'default' head-object --bucket "$LAB_BUCKET_NAME" --key large/dataset.bin | jq -r '.ETag'

echo "== Versioning =="
aws s3api --profile 'default' put-bucket-versioning --bucket "$LAB_BUCKET_NAME" --versioning-configuration Status=Enabled
aws s3 --profile 'default' cp users.csv "s3://$LAB_BUCKET_NAME/bronze/users.csv"
uv run dataset-users -c 40 -o csv > users_v2.csv
aws s3 --profile 'default' cp users_v2.csv "s3://$LAB_BUCKET_NAME/bronze/users.csv"
aws s3api --profile 'default' list-object-versions --bucket "$LAB_BUCKET_NAME" --prefix bronze/users.csv \
  | jq '.Versions[] | {VersionId, IsLatest, Size, LastModified}'
aws s3 --profile 'default' rm "s3://$LAB_BUCKET_NAME/bronze/users.csv"
aws s3api --profile 'default' list-object-versions --bucket "$LAB_BUCKET_NAME" --prefix bronze/users.csv | jq '.DeleteMarkers'

echo "== Lifecycle =="
aws s3api --profile 'default' put-bucket-lifecycle-configuration \
  --bucket "$LAB_BUCKET_NAME" --lifecycle-configuration file://s3/lifecycle.json
aws s3api --profile 'default' get-bucket-lifecycle-configuration --bucket "$LAB_BUCKET_NAME"

echo "== Access control =="
sed "s|BUCKET_NAME|$LAB_BUCKET_NAME|g" s3/policy.json.tpl > s3/policy.json
aws s3 --profile 'default' cp users.csv "s3://$LAB_BUCKET_NAME/bronze/protected.csv"
aws s3api --profile 'default' put-bucket-policy --bucket "$LAB_BUCKET_NAME" --policy file://s3/policy.json
aws s3 --profile 'default' rm "s3://$LAB_BUCKET_NAME/bronze/protected.csv" || echo "delete denied (bucket policy enforced) or AccessDenied/NotImplemented depending on backend"
aws s3api --profile 'default' delete-bucket-policy --bucket "$LAB_BUCKET_NAME"

echo "== Consistency =="
aws s3 --profile 'default' cp users.csv "s3://$LAB_BUCKET_NAME/bronze/users.csv"
aws s3 --profile 'default' cp "s3://$LAB_BUCKET_NAME/bronze/users.csv" /tmp/consistency_check.csv && echo "immediately available"
rm -f /tmp/consistency_check.csv

echo "== Cleanup =="
for prefix in bronze/ large/; do
  aws s3api --profile 'default' list-object-versions --bucket "$LAB_BUCKET_NAME" --prefix "$prefix" --output json \
  | jq -c '{Objects: ([.Versions[]?, .DeleteMarkers[]?] | map({Key, VersionId})), Quiet: true}' > delete.json
  if [ "$(jq '.Objects | length' delete.json)" -gt 0 ]; then
    aws s3api --profile 'default' delete-objects --bucket "$LAB_BUCKET_NAME" --delete file://delete.json
  fi
done
aws s3api --profile 'default' put-bucket-versioning --bucket "$LAB_BUCKET_NAME" --versioning-configuration Status=Suspended
aws s3api --profile 'default' delete-bucket-lifecycle --bucket "$LAB_BUCKET_NAME"
rm -f large_dataset.bin users_downloaded.csv users_v1.csv users_v2.csv delete.json s3/policy.json
aws s3 --profile 'default' ls "s3://$LAB_BUCKET_NAME/" --recursive || echo "(bucket empty)"
