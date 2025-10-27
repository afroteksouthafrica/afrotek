<# -----------------------------------------------
  Deploy-ProductService.ps1
  Idempotent ECS deploy for Afrotek product service.
  - Pins by :tag (default latest) OR by @sha256:digest
  - Upserts APP_REV so X-App-Rev header proves the rollout
  - Builds a minimal, null-free register payload
  - Updates the service and (optionally) watches rollout

  Prereqs: PowerShell 7+, AWS CLI v2 logged in with perms for:
    ecs:DescribeServices, DescribeTaskDefinition, RegisterTaskDefinition, UpdateService, ListTasks, DescribeTasks
    ecr:DescribeImages (only when resolving :latest -> digest)
------------------------------------------------ #>

[CmdletBinding()]
param(
  # AWS/ECS basics
  [string]$Region  = "af-south-1",
  [string]$Cluster = "afrotek-staging-cluster",
  [string]$Service = "afrotek-staging-product-service",

  # Image selection
  [string]$Repo,                     # e.g. 1660...ecr.af-south-1.amazonaws.com/afrotek/product-service
  [string]$Tag      = "latest",      # ignored if -Digest is provided
  [string]$Digest,                   # e.g. sha256:cf14...

  # Release labeling
  [string]$AppRev  = ("hsts-" + (Get-Date -Format 'yyyyMMdd-HHmmss')),

  # Convenience
  [switch]$ResolveLatestToDigest,    # if set, :latest -> resolves to @sha256:digest from ECR
  [switch]$Watch,                    # watch rollout summary after update
  [int]$WatchSeconds = 60            # how long to watch events
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-CurrentTaskDef {
  $tdArn = aws ecs describe-services `
    --cluster $Cluster --services $Service --region $Region `
    --query 'services[0].taskDefinition' --output text
  if (-not $tdArn -or $tdArn -eq "None") { throw "Could not resolve current task definition for $Service." }

  return aws ecs describe-task-definition --task-definition $tdArn --region $Region | ConvertFrom-Json
}

function Derive-RepoIfMissing([string]$currentImage) {
  # strip any @sha256... then drop trailing :tag if present
  $noDigest  = ($currentImage -split '@')[0]
  $lastColon = $noDigest.LastIndexOf(':')
  $lastSlash = $noDigest.LastIndexOf('/')
  if ($lastColon -gt $lastSlash) { return $noDigest.Substring(0, $lastColon) } else { return $noDigest }
}

function Resolve-LatestDigest([string]$repoNoTag) {
  # repoNoTag must be ".../afrotek/product-service"
  $repoName = $repoNoTag.Substring($repoNoTag.IndexOf('/', $repoNoTag.IndexOf('/')+1)+1) # "afrotek/product-service"
  $digest = aws ecr describe-images `
    --repository-name $repoName `
    --image-ids imageTag=latest `
    --region $Region `
    --query 'imageDetails[0].imageDigest' --output text
  if (-not $digest -or $digest -eq "None") { throw "Could not resolve :latest digest from ECR for $repoName." }
  return $digest
}

function Build-MinimalPayload($tdObj) {
  $def = $tdObj.taskDefinition
  $payload = [ordered]@{
    family                  = $def.family
    networkMode             = $def.networkMode
    requiresCompatibilities = $def.requiresCompatibilities
    cpu                     = $def.cpu
    memory                  = $def.memory
    containerDefinitions    = @($def.containerDefinitions)  # force array
  }
  if ($def.executionRoleArn)     { $payload.executionRoleArn     = $def.executionRoleArn }
  if ($def.taskRoleArn)          { $payload.taskRoleArn          = $def.taskRoleArn }
  if ($def.runtimePlatform)      { $payload.runtimePlatform      = $def.runtimePlatform }
  if ($def.volumes)              { $payload.volumes              = $def.volumes }
  if ($def.placementConstraints) { $payload.placementConstraints = $def.placementConstraints }
  return $payload
}

function Upsert-AppRevEnv([ref]$container, [string]$value) {
  if (-not $container.Value.environment) { $container.Value.environment = @() }
  $envList = @()
  foreach ($e in $container.Value.environment) {
    if ($e.name) { $envList += @{ name = "$($e.name)"; value = "$($e.value)" } }
  }
  $existing = $envList | Where-Object { $_.name -eq 'APP_REV' }
  if ($existing) { $existing.value = $value } else { $envList += @{ name='APP_REV'; value=$value } }
  $container.Value.environment = $envList
}

function Register-NewTd($payload) {
  $json = ($payload | ConvertTo-Json -Depth 100)
  $out  = aws ecs register-task-definition --region $Region --cli-input-json $json | ConvertFrom-Json
  $arn  = $out.taskDefinition.taskDefinitionArn
  if (-not $arn) { throw "register-task-definition returned no taskDefinitionArn" }
  return $arn
}

function Update-Service([string]$tdArn) {
  aws ecs update-service --cluster $Cluster --service $Service --task-definition $tdArn --region $Region | Out-Null
}

function Wait-And-Show() {
  Write-Host ""
  Write-Host "Watching events for $WatchSeconds sec..." -ForegroundColor Cyan
  $deadline = (Get-Date).AddSeconds($WatchSeconds)
  while ((Get-Date) -lt $deadline) {
    $msg = aws ecs describe-services --cluster $Cluster --services $Service --region $Region `
      --query 'services[0].events[0].message' --output text
    if ($msg) { Write-Host $msg }
    Start-Sleep -Seconds 5
  }

  # Show running task image + digest for proof
  $taskArn = aws ecs list-tasks --cluster $Cluster --service-name $Service --desired-status RUNNING --region $Region --query 'taskArns[0]' --output text
  if ($taskArn -and $taskArn -ne "None") {
    $cont = aws ecs describe-tasks --cluster $Cluster --tasks $taskArn --region $Region `
      --query 'tasks[0].containers[].{name:name,image:image,imageDigest:imageDigest}'
    Write-Host "`nActive container(s):`n$cont"
  }
}

# ---- Main ----
$td = Get-CurrentTaskDef
$payload = Build-MinimalPayload $td

# Identify the 'product' container
$containers = @($payload.containerDefinitions)
$product = $containers | Where-Object { $_.name -eq 'product' }
if (-not $product) { throw "Task definition has no container named 'product'." }

# Figure out Repo if not provided
if (-not $Repo -or $Repo -eq "") {
  $currentImage = ($td.taskDefinition.containerDefinitions | Where-Object name -eq 'product').image
  $Repo = Derive-RepoIfMissing $currentImage
  Write-Host "Derived Repo from TD: $Repo"
}

# Compose NEW_IMAGE
[string]$NewImage = $null
if ($Digest) {
  $NewImage = "$Repo@$Digest"
} elseif ($ResolveLatestToDigest) {
  $digest = Resolve-LatestDigest $Repo
  $NewImage = "$Repo@$digest"
  Write-Host "Resolved :latest -> $digest"
} else {
  $NewImage = "$Repo:$Tag"
}

if (-not $NewImage) { throw "Failed to compose image reference." }
$product.image = $NewImage
Upsert-AppRevEnv ([ref]$product) $AppRev

# Ensure modified containers array is back on payload
$payload.containerDefinitions = $containers

# Sanity echo
Write-Host ("Deploying image: " + $product.image) -ForegroundColor Yellow
Write-Host ("With X-App-Rev: " + $AppRev) -ForegroundColor Yellow

# Register & Update
$newTdArn = Register-NewTd $payload
Write-Host ("Registered " + $newTdArn) -ForegroundColor Green
Update-Service $newTdArn
Write-Host ("Service updated to " + $newTdArn) -ForegroundColor Green

if ($Watch) { Wait-And-Show }
