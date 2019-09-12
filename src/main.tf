# -----------------------------------------------------------------------------
# Versioned Provider Declarations
# -----------------------------------------------------------------------------
provider "aws" {
  version                        = "~> 2.23"
  region                         = "us-east-1"
}

provider "gitlab" {
  version                        = "~> 2.2"
}

provider "null" {
  version                        = "~> 2.1"
}

provider "tls" {
  version                        = "~> 2.0"
}

terraform {
  backend "s3" {
    bucket                       = "io.salte.terraform-state"
    key                          = "automation-root"
    region                       = "us-east-1"
  }
}

# -----------------------------------------------------------------------------
# Local Variable Declarations
# -----------------------------------------------------------------------------
locals {
  description_tag                = "Managed by Terraform"
  gitlab_group_id                = 0
  gitlab_group_name              = "prairie-code-iac-recipes"
  gitlab_ssh_private_key         = "SSH_PRIVATE_KEY"
  gitlab_ssh_public_key          = "SSH_PUBLIC_KEY"
  group_tag                      = "Shared Infrastructure"
  roles                          = [
    "vmimport",
    "docker"
  ]
}

# -----------------------------------------------------------------------------
# SSH Key Generation and Distribution
# -----------------------------------------------------------------------------
resource "tls_private_key" "ssh_key_pair" {
  algorithm                      = "RSA"
  rsa_bits                       = 4096
}

# Using Custom Script for Versioned Variable to Prevent Destruction
resource "null_resource" "ssh_private_key_versioned" {
  triggers = {
    key_change = "${md5(tls_private_key.ssh_key_pair.private_key_pem)}"
  }

  provisioner "local-exec" {
    command = "./scripts/save-versioned-variable.sh"

    environment = {
      GROUP_ID         = "${local.gitlab_group_id}"
      KEY              = "${local.gitlab_ssh_private_key}"
      VALUE            = "${base64encode(tls_private_key.ssh_key_pair.private_key_pem)}"
      VERSION          = "${var.CI_COMMIT_SHORT_SHA}"
      GITLAB_URL       = "${var.CI_API_V4_URL}"
      GITLAB_TOKEN     = "${var.GITLAB_TOKEN}"
    }
  }
}

# Using Custom Script for Versioned Variable to Prevent Destruction
resource "null_resource" "ssh_public_key_versioned" {
  triggers = {
    key_change = "${md5(tls_private_key.ssh_key_pair.public_key_openssh)}"
  }

  provisioner "local-exec" {
    command = "./scripts/save-versioned-variable.sh"

    environment = {
      GROUP_ID         = "${local.gitlab_group_id}"
      KEY              = "${local.gitlab_ssh_public_key}"
      VALUE            = "${base64encode(tls_private_key.ssh_key_pair.public_key_openssh)}"
      VERSION          = "${var.CI_COMMIT_SHORT_SHA}"
      GITLAB_URL       = "${var.CI_API_V4_URL}"
      GITLAB_TOKEN     = "${var.GITLAB_TOKEN}"
    }
  }
}

resource "gitlab_group_variable" "ssh_private_key" {
  group                          = "${local.gitlab_group_name}"
  key                            = "${local.gitlab_ssh_private_key}"
  value                          = "${base64encode(tls_private_key.ssh_key_pair.private_key_pem)}"
  protected                      = false

  depends_on = [
    null_resource.ssh_private_key_versioned,
    null_resource.ssh_public_key_versioned
  ]
}

resource "gitlab_group_variable" "ssh_public_key" {
  group                          = "${local.gitlab_group_name}"
  key                            = "${local.gitlab_ssh_public_key}"
  value                          = "${base64encode(tls_private_key.ssh_key_pair.public_key_openssh)}"
  protected                      = false

  depends_on = [
    null_resource.ssh_private_key_versioned,
    null_resource.ssh_public_key_versioned
  ]
}

# -----------------------------------------------------------------------------
# Terraform State Lock Table Provisioning
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "terraform_statelock" {
  name                           = "terraform-statelock"
  billing_mode                   = "PAY_PER_REQUEST"
  hash_key                       = "LockID"

  attribute {
    name                         = "LockID"
    type                         = "S"
  }

  tags = {
    Group                        = "${local.group_tag}"
    Description                  = "${local.description_tag}"
  }
}

# -----------------------------------------------------------------------------
# AWS Role Provisioning
# -----------------------------------------------------------------------------
resource "aws_iam_role" "default" {
  count              = "${length(local.roles)}"

  name               = "${local.roles[count.index]}"

  assume_role_policy = "${file("./aws-policies/${local.roles[count.index]}-assume-role-policy.json")}"

  tags = {
    Group            = "${local.group_tag}"
    Description      = "${local.description_tag}"
  }
}

resource "aws_iam_role_policy" "default" {
  count              = "${length(local.roles)}"

  name               = "${local.roles[count.index]}"
  role               = "${aws_iam_role.default[count.index].id}"
  policy             = "${file("./aws-policies/${local.roles[count.index]}-policy.json")}"
}
