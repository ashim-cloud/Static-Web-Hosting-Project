import os
import shutil
import zipfile

import boto3
from botocore.exceptions import ClientError

# Create AWS clients once per runtime container.
s3_client = boto3.client("s3")
codepipeline_client = boto3.client("codepipeline")


def _put_success(job_id: str) -> None:
    """Tell CodePipeline this action succeeded."""
    codepipeline_client.put_job_success_result(jobId=job_id)


def _put_failure(job_id: str, message: str) -> None:
    """Tell CodePipeline this action failed with a clear reason."""
    codepipeline_client.put_job_failure_result(
        jobId=job_id,
        failureDetails={
            "type": "JobFailed",
            "message": message,
        },
    )


def _artifact_from_event(event):
    """Read artifact bucket/key from CodePipeline event."""
    job = event["CodePipeline.job"]
    artifact = job["data"]["inputArtifacts"][0]
    s3_location = artifact["location"]["s3Location"]
    return job["id"], s3_location["bucketName"], s3_location["objectKey"]


def lambda_handler(event, _context):
    """Download artifact ZIP, check root index.html, then report result."""
    try:
        job_id, bucket_name, object_key = _artifact_from_event(event)
    except Exception as exc:
        # If event format is wrong, we cannot continue this action.
        raise RuntimeError(f"Invalid CodePipeline event payload: {exc}") from exc

    # Keep a per-job folder in /tmp so repeated runs do not conflict.
    job_work_dir = f"/tmp/{job_id}"
    zip_path = f"{job_work_dir}/artifact.zip"

    # Root of extracted artifact content.
    extract_dir = f"{job_work_dir}/extracted"
    try:
        if os.path.exists(job_work_dir):
            shutil.rmtree(job_work_dir)
        os.makedirs(extract_dir, exist_ok=True)

        # Download the artifact ZIP from bucket/key provided by CodePipeline.
        s3_client.download_file(bucket_name, object_key, zip_path)

        # Extract ZIP and validate root-level index.html.
        with zipfile.ZipFile(zip_path, "r") as artifact_zip:
            artifact_zip.extractall(extract_dir)

        root_index_path = os.path.join(extract_dir, "index.html")
        if not os.path.isfile(root_index_path):
            _put_failure(job_id, "index.html not found at artifact root.")
            return {
                "status": "FAILED",
                "reason": "index_html_missing",
                "bucket": bucket_name,
                "key": object_key,
            }

        _put_success(job_id)
        return {
            "status": "SUCCEEDED",
            "bucket": bucket_name,
            "key": object_key,
        }
    except ClientError as exc:
        error_code = exc.response.get("Error", {}).get("Code", "Unknown")
        _put_failure(job_id, f"Artifact read failed: {error_code}")
        return {"status": "FAILED", "reason": error_code, "bucket": bucket_name, "key": object_key}
    except zipfile.BadZipFile:
        _put_failure(job_id, "Artifact is not a valid ZIP file.")
        return {"status": "FAILED", "reason": "bad_zip", "bucket": bucket_name, "key": object_key}
    except Exception as exc:  # Broad catch ensures CodePipeline always gets a result.
        _put_failure(job_id, f"Unexpected error: {str(exc)}")
        return {"status": "FAILED", "reason": "unexpected_error", "bucket": bucket_name, "key": object_key}
