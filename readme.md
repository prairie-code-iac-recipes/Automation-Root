# Automation Root Repository
## Purpose
The purpose of this project is to generate the infrastructure, permissions, and keys required by the rest of this infrastructure as code example.

## Branching Model
### Overview
Basic building blocks like this project can follow a simple branching model since they produce intermediate deliverables that will serve as ingredients for more complex projects.  The only caveat to this is that they MUST be careful NOT to DESTROY resources that dependent projects are already utilizing.
### Detail
1. Modifications are made to feature branches created from the master branch.
2. Feature branches are merged directly into master via pull-request.
3. Master will "deploy" when changed.

## Pipeline
1. All Terraform files will be validated whenever any branch is updated.
2. A Terraform Plan is run and the plan persisted whenever the master branch changes.
3. A Terraform Apply is run for the persisted plan whenever the master branch changes.

*Note: The SSH key resource will be "tainted" prior to running plan if a versioned CI/CD variable doesn't exist for the current commit. This is a little kludgy, but it was a simple solution to managing the versioned secret CI/CD variable lifecycle.*

## Terraform
## Inputs
| Variable | Description |
| -------- | ----------- |
| CI_API_V4_URL | This is the base URL for the Gitlab API. It is one of the standard environment variables exposed by the Gitlab platform. It is used to save versioned CI/CD variables since the Terraform Gitlab provider doesn't support this. |
| CI_COMMIT_SHORT_SHA | This is the first eight characters of the commit revision for which the project is being built. It is one of the standard environment variables exposed by the Gitlab platform. It is used as a version number for SSH key variables.
| GITLAB_TOKEN | This is a personal access token used to authenticate to the Gitlab API for the purpose of saving the versioned SSH key variables. |

## Processing
* Uses the tls_private_key resource to generate an SSH key pair. Keys will regenerate the first time the pipeline runs for the current commit.  This is controlled by the Gitlab pipeline by running a "terraform taint" command if a versioned environment variable doesn't exist for the current commit.
* Uses the null_resource resource and a custom Bash script to save a versioned copy of the public and private keys to group-level CI/CD variables. By using the null_resource we can allow the Terraform state to reset without actually destroying the variables. This will run whenever the SSH key pair changes.
* Uses the gitlab_group_variable resource to save the "latest" public and private SSH key values to group-level CI/CD variables whenever the SSH key pair changes.
* Uses the aws_dynamodb_table resource to create the "terraform-statelock" DynamoDB table that will be used by subsequent Terraform processes to ensure that only one instance of the process is running at a time. This will not be recreated unless directly changed or explicitely destroyed.
* Uses the aws_iam_role resource to create the "vmimport" role required to publish custom AMIs to AWS. This will not be recreated unless changed or explicitely destroyed.
* Uses the aws_iam_role resource to create a role that will enable processes running on provisioned EC2 instances to obtain the token required to pull images from ECR.

## Outputs
* Latest Value of the SSH Public Key
* Latest Value of the SSH Public Key (obfuscated by default)
