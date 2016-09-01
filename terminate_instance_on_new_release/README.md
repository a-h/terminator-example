# AWS Lambda Function to Destroy an Instance

An AWS Lambda function which destroys an instance from each auto-scaling group. This should be set to trigger on 
a new software release being put into an S3 bucket.

The destruction of an instance triggers the auto-scaling group to create a new instance which will be the latest
version of the software.

Another AWS Lambda Function (`terminate_old_versions`) runs every 5 minutes, checks the /Version endpoint on the
instances and terminates instances that are older than the latest version.

This directory should be packaged up as `terminate_instance_on_new_release.zip`