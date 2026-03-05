import json
import os
import urllib.parse

import boto3


cloudfront_client = boto3.client("cloudfront")
codepipeline_client = boto3.client("codepipeline")


def lambda_handler(event, context):
    # Read CloudFront distribution ID from Lambda environment variable.
    distribution_id = os.environ["DISTRIBUTION_ID"]

    codepipeline_job = event.get("CodePipeline.job")
    if codepipeline_job:
        user_params = (
            codepipeline_job.get("data", {})
            .get("actionConfiguration", {})
            .get("configuration", {})
            .get("UserParameters", "")
        )
        paths = {"/*"}
        if user_params:
            try:
                parsed = json.loads(user_params)
                if isinstance(parsed, dict) and isinstance(parsed.get("paths"), list):
                    paths = set(parsed["paths"])
            except json.JSONDecodeError:
                pass
    else:
        # Build unique invalidation paths from uploaded S3 object keys.
        paths = set()
        for record in event.get("Records", []):
            key = record.get("s3", {}).get("object", {}).get("key")
            if not key:
                continue

            decoded_key = urllib.parse.unquote_plus(key)
            paths.add(f"/{decoded_key}")

    # If index.html changed, invalidate site root as well.
    if "/index.html" in paths:
        paths.add("/")

    # No file path found -> nothing to invalidate.
    if not paths:
        return {"statusCode": 200, "message": "No paths to invalidate"}

    try:
        response = cloudfront_client.create_invalidation(
            DistributionId=distribution_id,
            InvalidationBatch={
                "Paths": {
                    "Quantity": len(paths),
                    "Items": sorted(paths),
                },
                "CallerReference": context.aws_request_id,
            },
        )

        if codepipeline_job:
            codepipeline_client.put_job_success_result(jobId=codepipeline_job["id"])
    except Exception as exc:
        if codepipeline_job:
            codepipeline_client.put_job_failure_result(
                jobId=codepipeline_job["id"],
                failureDetails={
                    "type": "JobFailed",
                    "message": str(exc)[:512],
                },
            )
        raise

    return {
        "statusCode": 200,
        "invalidation_id": response["Invalidation"]["Id"],
        "paths": sorted(paths),
    }
