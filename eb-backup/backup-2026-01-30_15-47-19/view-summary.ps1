# Quick Reference Script - View Key Configuration Values
# Run this in the backup folder to extract important information

Write-Host "=== ELASTIC BEANSTALK BACKUP SUMMARY ===" -ForegroundColor Cyan
Write-Host ""

# Account Info
$account = Get-Content "aws-account-info.json" | ConvertFrom-Json
Write-Host "AWS Account ID: $($account.Account)" -ForegroundColor Yellow
Write-Host "AWS User ARN: $($account.Arn)" -ForegroundColor Yellow
Write-Host ""

# Server Environment
Write-Host "=== SERVER ENVIRONMENT ===" -ForegroundColor Green
$serverEnv = Get-Content "server-environment-description.json" | ConvertFrom-Json
$serverEnv.Environments | ForEach-Object {
    Write-Host "Environment Name: $($_.EnvironmentName)"
    Write-Host "Environment ID: $($_.EnvironmentId)"
    Write-Host "CNAME: $($_.CNAME)"
    Write-Host "Status: $($_.Status)"
    Write-Host "Health: $($_.Health)"
    Write-Host "Platform: $($_.PlatformArn)"
    Write-Host "Endpoint URL: $($_.EndpointURL)"
}
Write-Host ""

# Worker Environment
Write-Host "=== WORKER ENVIRONMENT ===" -ForegroundColor Green
$workerEnv = Get-Content "worker-environment-description.json" | ConvertFrom-Json
$workerEnv.Environments | ForEach-Object {
    Write-Host "Environment Name: $($_.EnvironmentName)"
    Write-Host "Environment ID: $($_.EnvironmentId)"
    Write-Host "CNAME: $($_.CNAME)"
    Write-Host "Status: $($_.Status)"
    Write-Host "Health: $($_.Health)"
    Write-Host "Platform: $($_.PlatformArn)"
}
Write-Host ""

# VPC Info
Write-Host "=== VPC INFORMATION ===" -ForegroundColor Magenta
$vpc = Get-Content "vpc-details.json" | ConvertFrom-Json
$vpc.Vpcs | ForEach-Object {
    Write-Host "VPC ID: $($_.VpcId)"
    Write-Host "CIDR Block: $($_.CidrBlock)"
    Write-Host "State: $($_.State)"
}
Write-Host ""

# Subnets
Write-Host "=== SUBNETS ===" -ForegroundColor Magenta
$subnets = Get-Content "vpc-subnets.json" | ConvertFrom-Json
$subnets.Subnets | ForEach-Object {
    $name = ($_.Tags | Where-Object { $_.Key -eq "Name" }).Value
    Write-Host "  $($_.SubnetId) - $($_.CidrBlock) - AZ: $($_.AvailabilityZone) - Name: $name"
}
Write-Host ""

# Security Groups
Write-Host "=== SECURITY GROUPS ===" -ForegroundColor Magenta
$sgs = Get-Content "vpc-security-groups.json" | ConvertFrom-Json
$sgs.SecurityGroups | ForEach-Object {
    Write-Host "  $($_.GroupId) - $($_.GroupName)"
}
Write-Host ""

# EC2 Instances
Write-Host "=== EC2 INSTANCES (Server) ===" -ForegroundColor Blue
$serverInstances = Get-Content "server-ec2-instances.json" | ConvertFrom-Json
$serverInstances.Reservations | ForEach-Object {
    $_.Instances | ForEach-Object {
        Write-Host "  $($_.InstanceId) - $($_.InstanceType) - $($_.State.Name) - $($_.PrivateIpAddress)"
    }
}
Write-Host ""

Write-Host "=== EC2 INSTANCES (Worker) ===" -ForegroundColor Blue
$workerInstances = Get-Content "worker-ec2-instances.json" | ConvertFrom-Json
$workerInstances.Reservations | ForEach-Object {
    $_.Instances | ForEach-Object {
        Write-Host "  $($_.InstanceId) - $($_.InstanceType) - $($_.State.Name) - $($_.PrivateIpAddress)"
    }
}
Write-Host ""

# Load Balancers
Write-Host "=== LOAD BALANCERS ===" -ForegroundColor Yellow
$albs = Get-Content "application-load-balancers.json" | ConvertFrom-Json
$albs.LoadBalancers | ForEach-Object {
    Write-Host "  $($_.LoadBalancerName) - $($_.Type) - $($_.DNSName)"
}
Write-Host ""

Write-Host "Backup complete! All files saved in current directory." -ForegroundColor Cyan
