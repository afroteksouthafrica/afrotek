# Afrotek Monorepo

## Deployment Tools

### Product Service Deployment (`scripts/deploy-product.ps1`)

PowerShell script for deploying the Product Service to ECS. Features include:

- Digest-based image deployment
- Service update with rolling deployment
- Health check verification
- Dry-run capability
- ALB target group configuration

#### Usage

Basic deployment:
```powershell
.\scripts\deploy-product.ps1
```

Show changes without deploying:
```powershell
.\scripts\deploy-product.ps1 -WhatIf
```

Custom health check configuration:
```powershell
# Via parameters
.\scripts\deploy-product.ps1 -Retries 8 -RetryDelay 10 -HealthUrl "https://staging.afrotek.co.za/health"

# Via environment variable
$env:HEALTH_URL="https://staging.afrotek.co.za/health"
.\scripts\deploy-product.ps1
```

Update ALB deregistration delay:
```powershell
.\scripts\deploy-product.ps1 -SetDeregDelay
```

Skip health verification:
```powershell
.\scripts\deploy-product.ps1 -SkipHealth
```

#### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-WhatIf` | switch | - | Show planned changes without deploying |
| `-SkipHealth` | switch | - | Skip health check verification |
| `-Retries` | int | 5 | Number of health check retry attempts |
| `-RetryDelay` | int | 5 | Seconds between health check retries |
| `-HealthUrl` | string | https://afrotek.co.za/health | Health check endpoint URL |
| `-SetDeregDelay` | switch | - | Update ALB deregistration delay to 30s |

The health check URL can also be set via the `HEALTH_URL` environment variable.
