locals {
  function_name        = "sample-fn"
  role_name            = "${local.function_name}-role"
  ecr_repo_name        = local.function_name
  function_source_path = "${path.module}/function"
}

resource "aws_iam_role" "execution" {
  name = local.role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sample-fn-role-policyattachment" {
  role       = aws_iam_role.execution.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# resource "aws_lambda_function" "this" {
#   function_name = local.function_name
#   role = aws_iam_role.this.arn
#   package_type = "Image"
#   image_uri = aws_ecr_repository.this.repository_url
#   architectures = ["x86_64"]
#   memory_size = 128
#   vpc_config {
#     subnet_ids = []
#     security_group_ids = []
#   }
# }

resource "aws_ecr_repository" "this" {
  name = local.ecr_repo_name
  # force delete if the repo contains images
  force_delete = true
}

data "aws_iam_policy_document" "repository_policy_doc" {
  statement {
    sid    = "LambdaECRImageRetrievalPolicy-${local.function_name}"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
  }
}

resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = data.aws_iam_policy_document.repository_policy_doc.json
}

# Problem with using aws_lambda_function: we cannot one-shot terraform apply
# 1. aws_lambda_function depends on the container image (ideally in ECR)
# 2. the container image first needs to be built
# 3. the image needs to be pushed to ECR.
# this means, initially, aws_lambda_function and aws_ecr_repository cannot be defined at the same time (we need to comment out aws_lambda_function for it to work)

# Build Docker image and push to a module-created ECR repo.
# Handles tagging by SHA, so a code change → new tag → Lambda updates.
module "docker_build" {
  # yes, the "//" is intentional (docker-build is a submodule of the lambda module)
  source = "terraform-aws-modules/lambda/aws//modules/docker-build" # TODO: pin a version

  create_ecr_repo = false
  ecr_repo        = local.ecr_repo_name

  source_path = local.function_source_path
  platform    = "linux/amd64"

  # Hash of source files → triggers a rebuild when code changes
  triggers = {
    dir_sha = sha1(join("", [
      for f in fileset(local.function_source_path, "**") : filesha1("${local.function_source_path}/${f}")
    ]))
  }

  ecr_repo_lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 5 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })

  depends_on = [aws_ecr_repository.this]
}

module "lambda_function" {
  source = "terraform-aws-modules/lambda/aws"

  function_name = local.function_name

  # create_package is true if we are using zip packages
  create_package = false
  package_type   = "Image"
  architectures  = ["x86_64"]
  image_uri      = module.docker_build.image_uri

  # otherwise this module will create one with AWSLambdaVPCAccessExecutionRole / AWSLambdaBasicExecutionRole
  create_role                   = false
  lambda_role                   = aws_iam_role.execution.arn
  attach_cloudwatch_logs_policy = true
}

variable "enable_function_url" {
  type    = bool
  default = false # flip to true only in regions that support it
}

resource "aws_lambda_function_url" "this" {
  function_name      = module.lambda_function.lambda_function_name
  authorization_type = "NONE"
}

output "function_url" {
  value = coalesce(try(aws_lambda_function_url.this.function_url, null), "")
}