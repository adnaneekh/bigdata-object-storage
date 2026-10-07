# Lab 2 (S3) — local dry-run results

Executed on 2026-10-07 against a local S3-compatible mock (`moto_server`, port 8000) instead
of Onyxia, since Onyxia credentials/cluster were not available in this environment.
`s3/run_lab2.sh` reproduces the exact same `aws s3` / `aws s3api` commands as `lab-2-s3.md`;
only the endpoint, bucket name and credentials change when pointing it at Onyxia.

## What ran successfully

- **Upload / list / download / move / delete**: round trip confirmed, downloaded file identical
  to the source (`diff` clean).
- **Metadata**: `head-object` returned `ETag` matching the object's MD5; user metadata
  (`source`, `version`, `rows`) stored and retrieved correctly.
- **Presigned URL**: generated and fetched with `curl`, returned the CSV content.
- **Multipart upload**: a 20 MiB file uploaded as 3 parts, `ETag` suffix `-3` confirms it.
- **Versioning**: enabling versioning + 2 uploads produced 2 addressable versions (plus a
  pre-existing `null` version from before versioning was enabled); the oldest version was
  restored and matched the original file byte-for-byte.
- **Delete marker**: deleting a versioned object added a delete marker (object vanished from
  normal listing, all versions still recoverable via `list-object-versions`).
- **Lifecycle policy**: 3 rules (expire `large/` after 30 days, purge non-current versions
  after 7 days, abort incomplete multipart uploads after 7 days) applied and read back intact.
- **Bucket policy / access control**: a `Deny s3:DeleteObject` policy on `bronze/*` was applied,
  and deleting `bronze/protected.csv` then failed with `403 Forbidden` — this mock *does*
  enforce bucket policies. The lab warns that real backends vary (SeaweedFS/Ceph RGW/MinIO may
  return `AccessDenied` or ignore it); note which behavior Onyxia's backend exhibits.
- **Consistency**: a `PUT` followed immediately by a `GET` on the same key succeeded — strong
  read-after-write consistency, as expected.
- **Cleanup**: all versions and delete markers removed, versioning suspended, lifecycle config
  deleted, bucket left empty.

## What was NOT executed here (needs the real Onyxia platform)

- The **Kubernetes Job** section (`s3/job-upload-bronze.yaml`): uploading `users.csv`/`orders.csv`
  to the bronze layer from a `ConfigMap` + `Secret` + `Job`. This needs the Onyxia
  `vscode-pyspark` service and its Kubernetes namespace/service account. The YAML and the exact
  `kubectl` command sequence are ready in `lab-2-s3.md` and `s3/job-upload-bronze.yaml` — just
  run them once connected to Onyxia.

## To replay against the real Onyxia bucket

```bash
# 1. Paste the "S3 Profile Details" script from the Onyxia Data Storage tab (sets ~/.aws/*)
# 2. Then:
export S3_ENDPOINT_URL=$(aws configure get endpoint_url --profile 'default' || echo "https://$AWS_S3_ENDPOINT")
export LAB_BUCKET_NAME="$KUBERNETES_NAMESPACE"
./s3/run_lab2.sh
```
