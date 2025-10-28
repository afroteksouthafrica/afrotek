param(
  [ValidateSet("ssh","ssm","tunnel")] [string]$Mode = "ssh"
)

$Region = "us-east-1"                             # Runner lives in us-east-1
$PrivIP = "172.31.30.179"                         # Runner private IP
$InstanceId = "i-0ce2abe163c5f45c9"               # Runner instance ID
$Key = Join-Path $env:USERPROFILE "Downloads\afrotek-actions-runner-keypair.pem"

function Get-InstanceAndSGs {
  aws ec2 describe-instances `
    --filters "Name=private-ip-address,Values=$PrivIP" `
    --query "Reservations[0].Instances[0]" `
    --output json --region $Region | ConvertFrom-Json
}

function Allow-MyIP-SSH([string[]]$GroupIds) {
  $my = (Invoke-RestMethod -Uri "https://checkip.amazonaws.com").Trim()
  $cidr = "$my/32"
  foreach ($sg in $GroupIds) {
    try {
      aws ec2 authorize-security-group-ingress --group-id $sg `
        --protocol tcp --port 22 --cidr $cidr --region $Region | Out-Null
      Write-Host "Allowed 22/tcp from $cidr on $sg"
    } catch { Write-Host "Rule for $cidr likely exists on $sg — ok" }
  }
}

$inst = Get-InstanceAndSGs
if (-not $inst) { throw "Runner instance not found in $Region" }
$sgIds = @($inst.SecurityGroups | ForEach-Object { $_.GroupId })

switch ($Mode) {
  "ssh" {
    Allow-MyIP-SSH $sgIds
    $pubIp = $inst.PublicIpAddress
    if (-not $pubIp -or $pubIp -eq "None") {
      $pubIp = aws ec2 describe-addresses `
        --filters "Name=instance-id,Values=$InstanceId" `
        --region $Region --query "Addresses[0].PublicIp" --output text
    }
    if (-not $pubIp -or $pubIp -eq "None") { throw "No public IP/EIP on instance." }
    ssh -o "IdentitiesOnly=yes" -o "ServerAliveInterval=30" -i "$Key" ec2-user@$pubIp
  }
  "ssm" {
    aws ssm start-session --target $InstanceId --region $Region
  }
  "tunnel" {
    # Start a local SSH tunnel via SSM on port 2222 → instance:22
    aws ssm start-session `
      --target $InstanceId --region $Region `
      --document-name AWS-StartSSHSession `
      --parameters portNumber=22,localPortNumber=2222
    # In a SECOND terminal:
    Write-Host "`nIn another terminal, run:"
    Write-Host "ssh -o `"IdentitiesOnly=yes`" -o `"ServerAliveInterval=30`" -p 2222 -i `"$Key`" ec2-user@127.0.0.1"
  }
}