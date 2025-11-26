# Jac Playground

This directory contains the built files for the Jac interactive playground.

## Source Repository

The playground source code is maintained in a separate repository:
**https://github.com/jaseci-labs/jac_playground**

## Deployment Process

The playground files in this directory are **dynamically generated** during the documentation deployment process:

1. The deployment workflow clones the `jac_playground` repository
2. Updates the `PLAYGROUND_PATH` configuration for the documentation environment
3. Installs dependencies and builds the React application
4. Copies the built files to this directory
5. Includes them in the Docker image for serving

## Important Notes

- **Do not commit built files** to this repository - they are generated automatically during deployment
- The playground is only available in the deployed documentation server
- All playground development should be done in the source repository linked above
