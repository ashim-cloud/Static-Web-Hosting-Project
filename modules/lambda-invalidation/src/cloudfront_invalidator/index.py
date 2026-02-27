import json
import os

import boto3

cloudfront = boto3.client("cloudfront")
codepipeline = boto3.client("codepipeline")


def _put_success(job_id):
    if job_id:
        codepipeline.put_job_success_result(jobId=job_id)


def _put_failure(job_id, message):
    if job_id:
        codepipeline.put_job_failure_result(
            jobId=job_id, failureDetails={"type": "JobFailed", "message": message}
        )


def handler(event, context):
    distribution_id = os.environ["DISTRIBUTION_ID"]
    paths = ["/*"]
    job_id = None

    try:
        job = event.get("CodePipeline.job", {})
        if job:
            job_id = job.get("id")
            user_params = (
                job.get("data", {})
                .get("actionConfiguration", {})
                .get("configuration", {})
                .get("UserParameters")
            )
            if user_params:
                parsed = json.loads(user_params)
                if isinstance(parsed, dict) and parsed.get("paths"):
                    paths = parsed["paths"]
                elif isinstance(parsed, list):
                    paths = parsed

        response = cloudfront.create_invalidation(
            DistributionId=distribution_id,
            InvalidationBatch={
                "Paths": {"Quantity": len(paths), "Items": paths},
                "CallerReference": f"{context.aws_request_id}",
            },
        )

        _put_success(job_id)
        return {
            "statusCode": 200,
            "body": json.dumps(
                {
                    "message": "Invalidation created",
                    "invalidationId": response["Invalidation"]["Id"],
                    "paths": paths,
                }
            ),
        }
    except Exception as exc:
        _put_failure(job_id, str(exc))
        raise
