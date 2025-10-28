# ==============================
# Afrotek Product Service Deployment Script
# ==============================
<#
.SYNOPSIS
Deploys the Afrotek Product Service to ECS with digest-based image tags.

.DESCRIPTION
This script automates the deployment of the Product Service to ECS by:
1. Reading the version from package.json
2. Fetching the ECR image digest for that version
3. Registering a new ECS task definition
4. Updating the ECS service with the new task definition
5. Waiting for service stability
6. Verifying the deployment via health check

.PARAMETER WhatIf
Shows what changes would be made without actually making them.

.PARAMETER SkipHealth
Skips the final health check verification.

.PARAMETER Retries
Number of health check retry attempts. Default: 5

.PARAMETER RetryDelay
Seconds to wait between health check retries. Default: 5

.PARAMETER HealthUrl
URL for the health check endpoint. Can also be set via HEALTH_URL environment variable.
Default: https://afrotek.co.za/health

.PARAMETER SetDeregDelay
Updates the ALB target group deregistration delay to match container stop timeout (30s).

.EXAMPLE
.\deploy-product.ps1 -WhatIf
Shows the planned task definition changes without deploying.

.EXAMPLE
.\deploy-product.ps1 -Retries 8 -RetryDelay 10
Deploys with custom health check retry settings.

.EXAMPLE
$env:HEALTH_URL="https://staging.afrotek.co.za/health"
.\deploy-product.ps1
Deploys using environment-specified health check URL.

.EXAMPLE
.\deploy-product.ps1 -SetDeregDelay
Deploys and updates ALB deregistration delay to 30s.
#>

# Parameter block
param(
    [switch]$WhatIf,
    [switch]$SkipHealth,
    [int]$Retries = 5,
    [int]$RetryDelay = 5,
    [string]$HealthUrl,
    [switch]$SetDeregDelay
)

# Allow HealthUrl to be provided via environment variable HEALTH_URL, or fall back to default
if (-not $HealthUrl) {
    if ($env:HEALTH_URL) { $HealthUrl = $env:HEALTH_URL }
    else { $HealthUrl = 'https://afrotek.co.za/health' }
}

# Normalize and validate HealthUrl early to avoid Invalid URI errors later
$HealthUrl = $HealthUrl.Trim()
if ($HealthUrl -eq '') { $HealthUrl = 'https://afrotek.co.za/health' }
if ($HealthUrl -notmatch '^(http|https)://') {
    # If someone passed a hostname-only value, assume https
    $HealthUrl = 'https://' + $HealthUrl.TrimStart('/')
}
try {
    # Validate the base URL (without query)
    [void][uri]::new($HealthUrl)
}
catch {
    throw "Configured HealthUrl is not a valid URI: '$HealthUrl'"
}

# --- Configuration ---
$ACCOUNT      = "166023635884"
$REGION       = "af-south-1"
$REPO         = "afrotek/product-service"
$TD_FAMILY    = "afrotek-product-task"
$CLUSTER      = "afrotek-staging-cluster"
$SERVICE      = "afrotek-staging-product-service"
$PACKAGE_PATH = "package.json"

# --- Resolve version tag dynamically from package.json ---
if (Test-Path $PACKAGE_PATH) {
    try {
        $pkg = Get-Content $PACKAGE_PATH -Raw | ConvertFrom-Json
    $TAG = "v$($pkg.version)"
    Write-Host "Using version from package.json: $TAG"
    }
    catch {
        Write-Warning "Could not read version from package.json, falling back to manual tag."
        $TAG = "v0.0.3"
    }
}
else {
    Write-Warning "package.json not found, using fallback version."
    $TAG = "v0.0.3"
}

# --- Fetch ECR image digest ---
Write-Host "`nFetching ECR image digest for tag $TAG..."
$DIGEST = aws ecr describe-images `
    --repository-name $REPO `
    --image-ids imageTag=$TAG `
    --region $REGION `
    --query "imageDetails[0].imageDigest" `
    --output text

if (-not $DIGEST -or $DIGEST -eq "None") {
    throw "Could not fetch digest for ${REPO}:${TAG}"
}

$IMAGE_URI = "$ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO@$DIGEST"
Write-Host "Using image digest: $IMAGE_URI"

# --- Get current ECS task definition ---
Write-Host "`nFetching current task definition: $TD_FAMILY..."
$desc = aws ecs describe-task-definition `
    --task-definition $TD_FAMILY `
    --region $REGION | ConvertFrom-Json

$def = $desc.taskDefinition

# --- Update container image and environment ---
foreach ($c in $def.containerDefinitions) {
    if ($c.name -eq "product") {
        $c.image = $IMAGE_URI

        if (-not $c.environment) {
            $c | Add-Member -Name environment -MemberType NoteProperty -Value @()
        }

        $env = $c.environment | Where-Object { $_.name -eq "APP_REV" }
        if ($env) { $env.value = "product-svc-$TAG" } 
        else { $c.environment += @{ name = "APP_REV"; value = "product-svc-$TAG" } }

        # Stop timeout
        $envTimeout = $c.environment | Where-Object { $_.name -eq "STOP_TIMEOUT_SECONDS" }
        if ($envTimeout) { $envTimeout.value = "30" } 
        else { $c.environment += @{ name = "STOP_TIMEOUT_SECONDS"; value = "30" } }

        $c.stopTimeout = 30
    }
}

# --- Build minimal payload ---
$new = [ordered]@{
    family                  = $def.family
    taskRoleArn             = $def.taskRoleArn
    executionRoleArn        = $def.executionRoleArn
    networkMode             = $def.networkMode
    containerDefinitions    = $def.containerDefinitions
    requiresCompatibilities = $def.requiresCompatibilities
    cpu                     = $def.cpu
    memory                  = $def.memory
    runtimePlatform         = $def.runtimePlatform
    volumes                 = $def.volumes
    placementConstraints    = $def.placementConstraints
    ephemeralStorage        = $def.ephemeralStorage
}

foreach ($key in @('taskRoleArn', 'executionRoleArn', 'ephemeralStorage', 'placementConstraints', 'volumes', 'runtimePlatform')) {
    if (-not $new[$key]) { $new.Remove($key) }
}

$json = $new | ConvertTo-Json -Depth 50

# --- Register new task definition revision ---
if ($WhatIf) {
    Write-Host "`nWhatIf mode: Dry-run only. Will NOT register or update ECS service."
    Write-Host "Planned task definition payload (json):"
    Write-Host $json
} else {
    Write-Host "`nRegistering new task definition revision..."
    $reg = aws ecs register-task-definition `
        --region $REGION `
        --cli-input-json $json | ConvertFrom-Json

    $newTdArn = $reg.taskDefinition.taskDefinitionArn
    Write-Host "`nNew Task Definition Registered: $newTdArn`n"

    # --- Update ECS service ---
    Write-Host "Updating ECS service to new task definition..."
    aws ecs update-service `
        --cluster $CLUSTER `
        --service $SERVICE `
        --task-definition $newTdArn `
        --region $REGION `
        --force-new-deployment | Out-Null

    Write-Host "`nDeployment triggered with digest-based image and APP_REV=$TAG."

    # --- Wait for ECS service stability ---
    Write-Host "`nWaiting for ECS service to reach a stable state..."
    aws ecs wait services-stable `
        --cluster $CLUSTER `
        --services $SERVICE `
        --region $REGION
    Write-Host "ECS service is stable."

    # --- Update ALB target group deregistration delay if requested ---
    if ($SetDeregDelay) {
        Write-Host "`nUpdating ALB target group deregistration delay to 30s..."
        aws elbv2 modify-target-group-attributes `
            --target-group-arn "arn:aws:elasticloadbalancing:af-south-1:166023635884:targetgroup/afrotek-staging-product-tg/7e92b13d4aa607d7" `
            --attributes Key=deregistration_delay.timeout_seconds,Value=30 `
            --region $REGION | Out-Null
        Write-Host "ALB deregistration delay updated."
    }
}

# --- Final verification ping ---
# Skip health checks in WhatIf mode or if user requested skipping
if ($WhatIf) { Write-Host "WhatIf: skipping health verification." }
elseif ($SkipHealth) { Write-Host "Skipping health verification as requested." }
else {
    $attempt = 0
    $success = $false
    Write-Host "`nPerforming final /health verification (up to $Retries attempts, delay ${RetryDelay}s)..."
    while ($attempt -lt $Retries -and -not $success) {
        $attempt++
        try {
            # Use a GUID per attempt to avoid caching and ensure unique query param
            $rand = [guid]::NewGuid().ToString()
            $healthUrlWithRand = $HealthUrl.TrimEnd('/') + "?x=$rand"

            # Validate URL before making the request to give clearer errors
            try { [void][uri]::new($healthUrlWithRand) } catch { throw "Invalid health URL: '$healthUrlWithRand'" }

            $response = Invoke-WebRequest -Uri $healthUrlWithRand -UseBasicParsing -TimeoutSec 10
            $respJson = $response.Content | ConvertFrom-Json
            $cacheHeader = $response.Headers['Cache-Control'] -join ','
            if (-not $cacheHeader) { $cacheHeader = 'none' }
            Write-Host "Health: Status=$($response.StatusCode), rev=$($respJson.rev), cache=$cacheHeader"
            $success = $true
        }
        catch {
            Write-Warning ("Health check attempt {0}/{1} failed: {2}" -f $attempt, $Retries, $_.Exception.Message)
            if ($attempt -lt $Retries) { Start-Sleep -Seconds $RetryDelay }
        }
    }
    if (-not $success) {
        Write-Warning "Health check failed after $Retries attempts."
        throw "Health verification failed."
    }
}


