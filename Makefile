.PHONY: help init plan apply bootstrap clean

help: ## Show this help menu
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize the Terraform working directory
	terraform init

plan: init ## Generate and show an execution plan
	terraform plan

apply: init ## Build or change infrastructure
	terraform apply

bootstrap: ## Run the 3-phase bootstrap process (Local Apply -> Migration)
	@echo "--- Phase 1: Local Apply ---"
	@if [ ! -f terraform.tfvars ]; then \
		echo "Creating terraform.tfvars from example..."; \
		cp terraform.tfvars.example terraform.tfvars; \
		echo "Please edit terraform.tfvars with your email and region before proceeding."; \
		exit 1; \
	fi
	terraform init -backend=false
	terraform apply -auto-approve
	@echo ""
	@echo "--- Phase 2: Configure Remote Backend ---"
	@if [ ! -f backend.tf ]; then \
		echo "Creating backend.tf from example..."; \
		cp backend.tf.example backend.tf; \
		BUCKET=$$(terraform output -raw terraform_state_s3_bucket_name); \
		REGION=$$(terraform output -raw aws_region); \
		sed -i "s/REPLACE_WITH_OUTPUT_BUCKET_NAME/$$BUCKET/" backend.tf; \
		sed -i "s/us-east-1/$$REGION/" backend.tf; \
		echo "backend.tf configured to use bucket $$BUCKET in region $$REGION"; \
	fi
	@echo ""
	@echo "--- Phase 3: State Migration ---"
	@echo "Terraform will now migrate your local state to the S3 backend."
	@echo "When prompted 'Do you want to copy existing state to the new backend?', type 'yes'."
	terraform init -migrate-state

clean: ## Remove local terraform configurations
	rm -rf .terraform
	rm -f .terraform.lock.hcl
