# Solution Stack Guide

## Error: Solution Stack Not Found

If you get this error when running Terraform:
```
Error: creating Elastic Beanstalk Environment: api error InvalidParameterValue: 
No Solution Stack named '64bit Amazon Linux 2023 v6.x.x running Node.js XX' found.
```

This means the solution stack version specified in your configuration is not available in your AWS region.

---

## Quick Fix

### Option 1: Use the Find Script (Recommended)

```bash
cd Terraform
chmod +x find-solution-stack.sh
./find-solution-stack.sh
```

This will show you all available Node.js solution stacks and suggest the latest versions.

### Option 2: Use AWS CLI Directly

```bash
# List all Node.js solution stacks
aws elasticbeanstalk list-available-solution-stacks \
  --region us-east-1 \
  --query "SolutionStacks[?contains(@, 'Node.js')]" \
  --output table

# Get the latest Node.js 20 stack
aws elasticbeanstalk list-available-solution-stacks \
  --region us-east-1 \
  --query "SolutionStacks[?contains(@, 'Node.js 20')] | [0]" \
  --output text

# Get the latest Node.js 18 stack
aws elasticbeanstalk list-available-solution-stacks \
  --region us-east-1 \
  --query "SolutionStacks[?contains(@, 'Node.js 18')] | [0]" \
  --output text
```

### Option 3: Use Common Stable Versions

Try these currently available solution stacks (as of November 2024):

**Node.js 22 (Latest - Recommended):**
```hcl
eb_solution_stack = "64bit Amazon Linux 2023 v6.12.1 running Node.js 22"
```

**Node.js 24 (Latest):**
```hcl
eb_solution_stack = "64bit Amazon Linux 2023 v6.12.1 running Node.js 24"
```

**Node.js 26 (Latest):**
```hcl
eb_solution_stack = "64bit Amazon Linux 2023 v6.12.1 running Node.js 26"
```

**Node.js 12 (Legacy - Amazon Linux 2):**
```hcl
eb_solution_stack = "64bit Amazon Linux 2 v5.0.2 running Node.js 12"
```

---

## How to Update Solution Stack

### 1. Update `terraform.tfvars`

Edit your `terraform.tfvars` file:

```hcl
eb_solution_stack = "64bit Amazon Linux 2023 v6.2.0 running Node.js 20"
```

### 2. Or Pass as Variable

When running Terraform:

```bash
terraform apply \
  -var="enable_elastic_beanstalk=true" \
  -var='eb_solution_stack=64bit Amazon Linux 2023 v6.2.0 running Node.js 20'
```

### 3. Or Update via GitHub Actions

In the GitHub Actions workflow, you can add the solution stack as an input parameter.

---

## Solution Stack Format

Elastic Beanstalk solution stacks follow this format:

```
<Architecture> <OS> <OS Version> running <Platform> <Platform Version>
```

Examples:
- `64bit Amazon Linux 2023 v6.2.0 running Node.js 20`
- `64bit Amazon Linux 2 v5.9.0 running Node.js 18`

---

## Why Solution Stacks Change

AWS regularly updates Elastic Beanstalk solution stacks to:
- Include security patches
- Update platform versions (Node.js, Python, etc.)
- Deprecate older versions
- Add new features

**Important:** Solution stacks are region-specific. A stack available in `us-east-1` might not be available in `eu-west-1`.

---

## Finding Solution Stacks in AWS Console

1. Go to AWS Console → Elastic Beanstalk
2. Click "Create application"
3. Under "Platform", select "Node.js"
4. View available platform versions in the dropdown
5. Copy the exact version string

---

## Automation: Keep Solution Stack Updated

Add this to your CI/CD pipeline to always use the latest:

```yaml
- name: Get latest solution stack
  id: get_stack
  run: |
    STACK=$(aws elasticbeanstalk list-available-solution-stacks \
      --region us-east-1 \
      --query "SolutionStacks[?contains(@, 'Node.js 20')] | [0]" \
      --output text)
    echo "stack=${STACK}" >> $GITHUB_OUTPUT

- name: Terraform Apply
  run: |
    terraform apply \
      -var="eb_solution_stack=${{ steps.get_stack.outputs.stack }}" \
      -auto-approve
```

---

## Common Solution Stack Patterns

### Amazon Linux 2023 (AL2023) - Latest
```
64bit Amazon Linux 2023 v6.12.1 running Node.js 22
64bit Amazon Linux 2023 v6.12.1 running Node.js 24
64bit Amazon Linux 2023 v6.12.1 running Node.js 26
64bit Amazon Linux 2023 v6.11.6 running Node.js 22
```

### Amazon Linux 2 (AL2) - Legacy
```
64bit Amazon Linux 2 v5.0.2 running Node.js 12
64bit Amazon Linux 2 v5.0.2 running Node.js 10
```

**Recommendation:** Use Amazon Linux 2023 (AL2023) for new deployments.

---

## Troubleshooting

### Issue: "Solution stack not found"
**Solution:** Update to a currently available version using one of the methods above.

### Issue: "Platform version deprecated"
**Solution:** AWS deprecates old versions. Always test with the latest stable version.

### Issue: "Different region, different stacks"
**Solution:** Solution stacks vary by region. Check your target region specifically:

```bash
aws elasticbeanstalk list-available-solution-stacks \
  --region YOUR_REGION \
  --query "SolutionStacks[?contains(@, 'Node.js')]"
```

---

## Version History

| Date | Default Version | Notes |
|------|----------------|-------|
| 2024-11 | Node.js 20 (AL2023 v6.2.0) | Current default |
| 2024-08 | Node.js 22 (AL2023 v6.1.11) | Was in terraform - not widely available |
| 2024-06 | Node.js 18 (AL2023 v6.0.0) | AL2023 introduced |
| 2023-12 | Node.js 18 (AL2 v5.9.0) | Previous stable |

---

## Quick Reference Commands

```bash
# List all available stacks
aws elasticbeanstalk list-available-solution-stacks --region us-east-1

# Filter for Node.js only
aws elasticbeanstalk list-available-solution-stacks \
  --region us-east-1 \
  --query "SolutionStacks[?contains(@, 'Node.js')]"

# Get latest Node.js 20
aws elasticbeanstalk list-available-solution-stacks \
  --region us-east-1 \
  --query "SolutionStacks[?contains(@, 'Node.js 20')] | [0]" \
  --output text

# Describe a specific platform
aws elasticbeanstalk describe-platform-version \
  --platform-arn "arn:aws:elasticbeanstalk:us-east-1::platform/Node.js 20 running on 64bit Amazon Linux 2023/6.2.0"
```

---

## Need Help?

1. Run `./find-solution-stack.sh` to see what's available
2. Check AWS Elastic Beanstalk documentation: https://docs.aws.amazon.com/elasticbeanstalk/latest/platforms/platforms-supported.html#platforms-supported.nodejs
3. Check the Terraform error message for hints
4. Verify your AWS credentials and region

---

**Updated:** November 2024  
**Default:** Node.js 20 on Amazon Linux 2023 v6.2.0
