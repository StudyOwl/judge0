# Elastic Beanstalk Complete Backup

**Backup Date:** January 30, 2026 at 15:47:19

## Environments Backed Up

| Environment Name | Type |
|------------------|------|
| Code-executor-v0-env-server-2-env | Server |
| Code-executor-v0-env-worker-env--env | Worker |

## Application Information
- **Application Name:** Code-executor-v0
- **VPC ID:** vpc-0259755c2ffc44a8d

---

## Backup Contents

### Elastic Beanstalk Configuration

| File | Description |
|------|-------------|
| `application-description.json` | Application details and metadata |
| `application-versions.json` | All deployed application versions |
| `server-environment-description.json` | Server environment details |
| `worker-environment-description.json` | Worker environment details |
| `server-configuration-settings.json` | Complete server env configuration |
| `worker-configuration-settings.json` | Complete worker env configuration |
| `server-environment-resources.json` | Resources attached to server env |
| `worker-environment-resources.json` | Resources attached to worker env |
| `server-environment-events.json` | Recent server environment events |
| `worker-environment-events.json` | Recent worker environment events |
| `server-environment-health.json` | Server environment health status |
| `available-solution-stacks.json` | Available EB solution stacks |

### VPC and Networking

| File | Description |
|------|-------------|
| `vpc-details.json` | VPC configuration details |
| `vpc-subnets.json` | All subnets in the VPC |
| `vpc-security-groups.json` | Security groups and rules |
| `vpc-route-tables.json` | Route tables configuration |
| `vpc-internet-gateways.json` | Internet gateway details |
| `vpc-nat-gateways.json` | NAT gateway details |
| `vpc-network-acls.json` | Network ACL rules |
| `elastic-ips.json` | Elastic IP addresses |

### EC2 and Compute

| File | Description |
|------|-------------|
| `server-ec2-instances.json` | Server environment EC2 instances |
| `worker-ec2-instances.json` | Worker environment EC2 instances |
| `auto-scaling-groups.json` | Auto Scaling group configurations |
| `launch-configurations.json` | Launch configurations |
| `launch-templates.json` | EC2 launch templates |
| `ec2-key-pairs.json` | EC2 key pairs |

### Load Balancing

| File | Description |
|------|-------------|
| `application-load-balancers.json` | ALB/NLB configurations |
| `classic-load-balancers.json` | Classic ELB configurations |
| `target-groups.json` | Target group configurations |
| `load-balancer-listeners.json` | Load balancer listeners |

### IAM

| File | Description |
|------|-------------|
| `iam-roles.json` | IAM roles |
| `iam-instance-profiles.json` | Instance profiles |

### CloudFormation

| File | Description |
|------|-------------|
| `cloudformation-stacks.json` | All CF stacks (EB creates these) |
| `server-stack-resources.json` | Server env CF stack resources |
| `worker-stack-resources.json` | Worker env CF stack resources |
| `server-stack-template.json` | Server CF template (for recreation) |
| `worker-stack-template.json` | Worker CF template (for recreation) |

### Account Information

| File | Description |
|------|-------------|
| `aws-account-info.json` | AWS account identity |
| `aws-regions.json` | Available AWS regions |

---

## How to Use This Backup

### To Recreate Environments

1. **Review Configuration Settings:**
   - Open `server-configuration-settings.json` and `worker-configuration-settings.json`
   - These contain all environment variables, instance types, scaling settings, etc.

2. **VPC Setup:**
   - Use `vpc-details.json` for VPC CIDR
   - Use `vpc-subnets.json` for subnet configurations
   - Use `vpc-security-groups.json` for security group rules

3. **Create New EB Environment:**
   ```bash
   # Create application (if needed)
   aws elasticbeanstalk create-application --application-name Code-executor-v0

   # Create environment using saved configuration
   aws elasticbeanstalk create-environment \
     --application-name Code-executor-v0 \
     --environment-name <new-env-name> \
     --solution-stack-name "<solution-stack-from-config>"
   ```

4. **Apply Configuration:**
   - Extract option settings from the configuration files
   - Apply them via AWS Console or CLI

### Important Values to Note

From `server-configuration-settings.json`:
- Instance Type
- Environment Variables
- Auto Scaling settings
- VPC/Subnet configurations

From `worker-configuration-settings.json`:
- Worker-specific settings
- Queue configurations (if any)

---

## CloudFormation Stack Names

| Environment | Stack Name |
|-------------|------------|
| Server | awseb-e-wjajvda5di-stack |
| Worker | awseb-e-mqtpzgjjiy-stack |

---

## Notes

- Health information for worker environment may not be available (worker environments don't support enhanced health)
- CloudFormation templates can be used to recreate the exact infrastructure
- Security group rules contain all inbound/outbound rules for the environments
