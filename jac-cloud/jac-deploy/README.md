# JAC Deployment Guide

This guide explains how to configure and run a deployment for your JAC application using a JSON configuration file using jac deploy plugin.

---
## Steps
### 1. setup Configuration File

All deployment settings are stored in a JSON file (e.g., `deploy.json`).
Here’s an example configuration:

```json
{
  "build": {
    "image_name": "jac-custom",
    "tag": "latest",
    "code_folder": "./littlex",
    "requirements_file": "requirements.txt",
    "entrypoint_file": "littleX.jac",
    "build_log_file": "build.log"
    },
  "deploy": {
    "ports": {
      "8080": "8000"
    },
    "env_file": ".env"
  }
}
```
### 2. Run deployment

Once configueration file is created run the below line in cmd to create the docker container and run it.It will follow following steps
1. Create dockerfile if it doesnt exist
2. create docker images based on configueration
3. Run the docker image locally

```bash
jac deploy deploy.json
```

## Furthur improvements for plugin
1. Integration of .env
2. Integration  of volume for the container
3. Support for image repository
4. Seperation of docker container building and deployment stage
5. Create proper structure for config.json file
6. proper return of log file
