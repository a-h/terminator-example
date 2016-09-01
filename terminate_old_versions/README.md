# AWS Lambda Function to Destroy Old Instances

An AWS Lambda function which destroys old instances from each auto-scaling group, based on a semantic version 
returned by a HTTP endpoint. This should be set to trigger on a timed basis.

The destruction of an instance triggers the auto-scaling group to create a new instance which will be the latest
version of the software.

Another AWS Lambda Function (`terminate_instance_on_new_release`) runs when a new release is added to S3, 
which triggers a single instance to be the latest version of the software.

This directory should be packaged up as `terminate_old_versions.zip`