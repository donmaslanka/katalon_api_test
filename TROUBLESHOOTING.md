# Terraform Validation Troubleshooting

## Error: "Reference to undeclared input variable"

If you see errors like:
```
Error: Reference to undeclared input variable
  on main.tf line 22, in resource "aws_security_group" "jenkins":
  22:   vpc_id      = var.vpc_id
```

### Cause
This error occurs when you run `terraform validate` from inside a module directory instead of the root directory.

### Solution

**Always run Terraform commands from the ROOT directory** (the directory containing the main `main.tf` file and the `modules/` folder).

```bash
# ❌ WRONG - Inside a module
cd katalon-ecs-terraform/modules/jenkins
terraform validate  # This will fail!

# ✅ CORRECT - From root
cd katalon-ecs-terraform
terraform validate  # This works!
```

## Quick Fix

### Option 1: Navigate to Root Directory

```bash
# Find your project root
cd katalon-ecs-terraform

# Verify you're in the right place
ls -la
# You should see: main.tf, modules/, variables.tf, outputs.tf, etc.

# Now run terraform commands
terraform validate
terraform plan
terraform apply
```

### Option 2: Use the Validation Script

We've provided a helper script that automatically validates from the correct directory:

```bash
cd katalon-ecs-terraform
./validate-terraform.sh
```

This script:
- ✅ Checks you're in the right directory
- ✅ Validates the root module
- ✅ Validates each sub-module individually
- ✅ Shows clear success/error messages

## Understanding Terraform Module Structure

```
katalon-ecs-terraform/          ← ROOT (run terraform here)
├── main.tf                     ← Calls modules
├── variables.tf                ← Root variables
├── outputs.tf                  ← Root outputs
├── terraform.tfvars            ← Your configuration
└── modules/                    ← Module definitions
    ├── vpc/
    │   ├── main.tf            ← Module code (don't run terraform here)
    │   ├── variables.tf       ← Module variables
    │   └── outputs.tf         ← Module outputs
    ├── ecs/
    ├── iam/
    ├── security-groups/
    └── jenkins/
        ├── main.tf            ← Module code (don't run terraform here)
        ├── variables.tf       ← Module variables
        └── outputs.tf         ← Module outputs
```

**Rule:** Always run `terraform` commands from the **ROOT** directory, never from inside `modules/`.

## Common Mistakes

### Mistake 1: Wrong Directory
```bash
# ❌ Wrong
cd modules/jenkins
terraform validate

# ✅ Correct
cd katalon-ecs-terraform
terraform validate
```

### Mistake 2: Missing terraform.tfvars
```bash
# Error: No value for required variable
# Solution: Create terraform.tfvars
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
```

### Mistake 3: Not Initialized
```bash
# Error: Backend initialization required
# Solution: Initialize first
terraform init
```

## Validation Checklist

Before running `terraform validate`:

- [ ] In the ROOT directory (`katalon-ecs-terraform/`)
- [ ] `main.tf` file exists in current directory
- [ ] `modules/` folder exists in current directory
- [ ] Terraform is installed (`terraform version`)
- [ ] Terraform is initialized (`terraform init`)

If all checks pass, then run:
```bash
terraform validate
```

## Expected Output

When validation succeeds, you should see:
```
Success! The configuration is valid.
```

When validation fails, you'll see specific errors with file and line numbers.

## Module-Specific Validation

If you want to validate a specific module in isolation:

```bash
# From root directory
cd modules/jenkins
terraform init
terraform validate
cd ../..
```

But remember: this validates the module's syntax only. Full validation requires running from the root with all module dependencies.

## Other Common Terraform Errors

### Error: "Module not installed"
```
Error: Module not installed
  on main.tf line 80:
  80: module "jenkins" {
```

**Solution:**
```bash
terraform init
```

### Error: "No value for required variable"
```
Error: No value for required variable
  on variables.tf line 10:
  10: variable "jenkins_key_name" {
```

**Solution:** Create/update `terraform.tfvars`:
```bash
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars
# Add: jenkins_key_name = "your-key-name"
```

### Error: "Invalid provider configuration"
```
Error: Invalid provider configuration
```

**Solution:** Initialize Terraform:
```bash
terraform init
```

## Getting Help

If you continue having issues:

1. **Check your directory:**
   ```bash
   pwd
   ls -la
   ```

2. **Run the validation script:**
   ```bash
   ./validate-terraform.sh
   ```

3. **Check Terraform version:**
   ```bash
   terraform version
   # Should be >= 1.0
   ```

4. **Reinitialize if needed:**
   ```bash
   rm -rf .terraform .terraform.lock.hcl
   terraform init
   ```

5. **Review error messages carefully:**
   - Line numbers point to the file with the issue
   - Error messages usually explain what's wrong
   - Check for typos in variable names

## Pro Tips

1. **Always work from root:**
   ```bash
   # Set up alias
   alias tf='cd /path/to/katalon-ecs-terraform && terraform'
   ```

2. **Use the validation script:**
   ```bash
   ./validate-terraform.sh
   ```

3. **Format your code:**
   ```bash
   terraform fmt -recursive
   ```

4. **Plan before applying:**
   ```bash
   terraform plan -out=tfplan
   # Review the plan
   terraform apply tfplan
   ```

## Summary

**The main issue:** Running `terraform validate` from inside a module directory.

**The solution:** Always run Terraform commands from the root directory where your main `main.tf` file is located.

```bash
# Quick fix
cd katalon-ecs-terraform  # Go to root
terraform validate         # Run from here
```

✅ **You're ready to go!**
