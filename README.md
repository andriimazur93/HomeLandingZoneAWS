# AWS Home Landing Zone

[![Terraform Security Scan (Tfsec)](https://github.com/your-username/HomeLandingZoneAWS/actions/workflows/tfsec.yml/badge.svg)](https://github.com/your-username/HomeLandingZoneAWS/actions/workflows/tfsec.yml)

**HomeLandingZoneAWS** is the foundational "Landing Zone" for a personal homelab AWS environment. 

It is a repository responsible *exclusively* for creating the baseline infrastructure required to securely deploy future AWS workloads. It establishes a highly secure, encrypted, and locked remote Terraform Backend, and ensures your AWS Cloud costs stay perfectly monitored with a $5.00/month hard budget limit.

---

## Architecture

This repository provisions:
1. **Amazon S3 Bucket**: Highly restricted bucket with Server-Side-Encryption (SSE-S3), Versioning, and 90-day lifecycle policies to securely store `terraform.tfstate` files.
2. **Amazon DynamoDB Table**: A `PAY_PER_REQUEST` On-Demand table mapping a `LockID` index to prevent concurrent pipeline runs from corrupting your state files.
3. **AWS Budgets**: A $5.00/month budget alerting you via email at 80% (Actual) and 100% (Forecasted) spend.

> [!IMPORTANT]
> Because this repository provisions the exact S3 bucket that it will use to store its *own* Terraform state, deploying it for the first time requires a circular dependency workaround known as the **"Bootstrap"** phase.

---

## Prerequisites

Before deploying the codebase, you must strictly secure your AWS account and configure secure access. Follow these 5 phases:

### Phase 1: Secure the Root Account
The Root user is the email and password you used to create the AWS account. It has absolute power and must be secured immediately.
1. **Log in**: Go to the AWS Management Console and log in as the Root user.
2. **Enable MFA**: Click your account name in the top right -> Security credentials. Under "Multi-factor authentication (MFA)", assign an authenticator app (like Authy, Bitwarden, or Google Authenticator) or a hardware key.
3. **Verify No Access Keys**: Scroll down to "Access keys" on the same page. Ensure there are **zero** access keys listed here. Never create access keys for the Root user.

### Phase 2: Grant Billing Access for Terraform
Your Terraform Landing Zone will create an AWS Budget. By default, AWS blocks non-root users from accessing billing APIs. You must enable this.
1. Click your account name in the top right -> Account.
2. Scroll down to **IAM User and Role Access to Billing Information**.
3. Click **Edit**, check the box for **Activate IAM Access**, and click **Update**.

### Phase 3: Set Up IAM Identity Center (Secure Access)
This replaces the outdated practice of downloading permanent, risky Access Keys.
1. In the top AWS search bar, type **IAM Identity Center** and open it.
2. Click **Enable**. (Note the AWS Region you are in, e.g., `us-east-1` or `eu-central-1`. You will need this later).
3. **Create a User**: In the left menu, click Users -> Add user. Fill out a username (e.g., `homelab-admin`), an email address, and your name. Click Next and Add user. (Check your email to set the password for this new user).
4. **Create a Permission Set**: In the left menu, click Permission sets -> Create permission set. Choose Predefined permission set -> Select `AdministratorAccess`. Click Next, leave defaults, and click Create.
5. **Assign User to Account**: In the left menu, click AWS accounts. Click your AWS account name/ID. Click Assign users or groups. Select your `homelab-admin` user, click Next. Select the `AdministratorAccess` permission set, click Next, then Submit.
6. **Copy Your Portal URL**: Go to the IAM Identity Center Dashboard. On the right side, find the AWS access portal URL (e.g., `https://d-123456789.awsapps.com/start`). Copy this URL.

> [!NOTE]
> You are now completely done with the Root user. Log out of the AWS Console entirely.

### Phase 4: Configure Your Local Terminal
Now you will connect your local computer to AWS using secure, temporary SSO tokens. Ensure you have installed Make, [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli), [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html), and [Pre-commit](https://pre-commit.com/).

Open your terminal and run:
```bash
aws configure sso
```

Answer the prompts exactly as follows:
- **SSO session name**: `homelab`
- **SSO start URL**: *(Paste the portal URL you copied in Phase 3)*
- **SSO region**: *(The region where you enabled IAM Identity Center, e.g., us-east-1)*
- **SSO registration scopes**: *(Press Enter to accept the default sso:account:access)*
- **Browser Authentication**: Your web browser will open. Log in with the `homelab-admin` credentials you created in Phase 3 and click Allow.

Return to your terminal to finish the prompts:
- **CLI default client Region**: *(Your preferred region, e.g., us-east-1)*
- **CLI default output format**: `json`
- **CLI profile name**: `default` *(Typing `default` here is highly recommended so Terraform automatically detects it without extra configuration).*

### Phase 5: Your New Daily Workflow
You are now fully set up. You have zero static secrets on your hard drive. Every time you sit down to work on your homelab infrastructure, you will open your terminal and type:

```bash
aws sso login
```
A browser window will pop up, you click "Allow," and your terminal is securely authenticated with temporary Admin credentials for the next 8–12 hours. Terraform natively understands this and will just work.

---

## The "Bootstrap" Deployment Workflow

We have abstracted the complex 3-phase Terraform bootstrap process into a simple `Makefile` workflow.

### Quick Start (Automated Bootstrap)

1. Clone this repository and navigate into it.
2. Run the initialization generator:
   ```bash
   make bootstrap
   ```
3. The script will automatically pause and generate a `terraform.tfvars` file. Open this file and fill in your desired AWS Region and alert email address.
4. Re-run `make bootstrap`.
5. Terraform will create the infrastructure using local state. Then, the script will automatically populate `backend.tfbackend` (which is gitignored) with the newly created S3 bucket name.
6. When prompted by Terraform: *"Do you want to copy existing state to the new backend?"*, type **`yes`**.

Your state is now securely hosted in AWS! The `backend.tfbackend` file on your local disk holds your Account ID and bucket name — it is listed in `.gitignore` and will never be committed. 

---

## Developer Guide & Pre-commit Hooks

This repository uses `pre-commit` to ensure code formatting, syntax validation, and zero security vulnerabilities (via `tfsec`) before code is merged.

1. Ensure [pre-commit](https://pre-commit.com/) is installed locally.
2. Run:
   ```bash
   pre-commit install
   ```

Now, every time you `git commit`, Terraform formats and validates your files automatically. You can manually run the suite anytime using:
```bash
pre-commit run --all-files
```

---

## Future Downstream Repositories

For any future repositories you create (e.g. `HomeAssistant-Alexa-AWS`), **do not recreate the S3 Backend**. Instead, simply point your new codebase at the global Landing Zone resources.

Add this block to your downstream `backend.tf`:

```hcl
terraform {
  backend "s3" {
    # Specify the exact bucket created by HomeLandingZoneAWS
    bucket         = "homelab-tfstate-123456789012-us-east-1" 
    
    # Needs to be a unique path specifically for the isolated repo
    key            = "other-repo/terraform.tfstate" 
    region         = "us-east-1"
    
    # Use the locking table
    dynamodb_table = "homelab-tfstate-locks"
    encrypt        = true
  }
}
```
