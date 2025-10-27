# GitHub OIDC Role (AWS)

This folder contains the IAM JSON needed to enable GitHub Actions to assume a deploy role **without long‑lived access keys**.

Replace placeholders before applying:
- `<AWS_ACCOUNT_ID>`: Your 12‑digit account ID.
- `<TASK_EXEC_ROLE_ARN>`: ARN of your ECS task execution role.

## 1) OIDC Provider
Create OIDC provider in IAM (if not already present):
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

## 2) Trust Policy — Role: `GitHubActionsDeployRole`
Save as `trust-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<AWS_ACCOUNT_ID>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:afroteksouthafrica/afrotek:ref:refs/heads/main"
        },
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        }
      }
    }
  ]
}
```

## 3) Permissions Policy — `GitHubActionsDeployPolicy`
Save as `permissions-policy.json` (least‑priv):

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRPushPull",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSUpdate",
      "Effect": "Allow",
      "Action": [
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService",
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:ListTasks",
        "ecs:DescribeTasks"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PassExecutionRole",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "<TASK_EXEC_ROLE_ARN>"
      ]
    },
    {
      "Sid": "LogsMinimal",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": "*"
    }
  ]
}
```

## 4) Switch workflows to OIDC
Once role is created, replace the credentials step with:

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::<AWS_ACCOUNT_ID>:role/GitHubActionsDeployRole
    aws-region: af-south-1
```
