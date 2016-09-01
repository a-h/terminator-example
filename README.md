Terminator Example
##################

A demonstration of how to use the Terminator to automatically upgrade deployments.

SSH keys generated with command:

```
ssh-keygen -t rsa -b 2048 -f ./terminator_example.pem -N ""
```

Zip files created with commands:

```
zip -r terminate_instance_on_new_release.zip ./terminate_instance_on_new_release/ -x ".*" -x "*/.*"
zip -r terminate_old_versions.zip ./terminate_old_versions/ -x ".*" -x "*/.*"
```