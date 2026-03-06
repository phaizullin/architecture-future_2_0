# ============================================================================
# YANDEX CLOUD CREDENTIALS
# ============================================================================

# Получить OAuth token: https://oauth.yandex.ru/authorize?response_type=token&client_id={client_id}
# Или использовать IAM token: yc iam create-token
yc_token     = "YOUR_YC_TOKEN_HERE"  # ИЗМЕНИТЬ!

# Получить Cloud ID: yc resource-manager cloud list
yc_cloud_id  = "YOUR_CLOUD_ID_HERE"  # ИЗМЕНИТЬ!

# Получить Folder ID: yc resource-manager folder list
yc_folder_id = "YOUR_FOLDER_ID_HERE" # ИЗМЕНИТЬ!

# Зона по умолчанию (ru-central1-a, ru-central1-b, ru-central1-c)
yc_zone = "ru-central1-a"

# ============================================================================
# GENERAL CONFIGURATION
# ============================================================================

project_name = "future20"
environment  = "dev"

# ============================================================================
# NETWORKING CONFIGURATION
# ============================================================================

vpc_cidr = "10.0.0.0/16"  # Provides 65,536 IP addresses
az_count = 3              # Using all 3 AZs in ru-central1 for high availability

# Subnet allocation:
# - Public subnets:   10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24   (256 IPs each)
# - Private subnets:  10.0.3.0/24, 10.0.4.0/24, 10.0.5.0/24   (256 IPs each)
# - Database subnets: 10.0.6.0/24, 10.0.7.0/24, 10.0.8.0/24   (256 IPs each)

# ============================================================================
# KUBERNETES CLUSTER CONFIGURATION
# ============================================================================

k8s_version  = "1.28"  # Latest stable Kubernetes version

# Node resources (per node)
k8s_node_cores  = 4    # vCPU cores
k8s_node_memory = 8    # GB RAM
k8s_node_disk_size = 64 # GB SSD

# Node scaling
k8s_node_desired_size = 3  # Start with 3 nodes for better distribution
k8s_node_min_size     = 2  # Minimum 2 nodes for HA
k8s_node_max_size     = 6  # Scale up to 6 nodes under load

# Use preemptible instances for cost savings (not recommended for production)
k8s_node_preemptible = false

# SSH key for node access (optional, for debugging)
# Generate: ssh-keygen -t ed25519 -C "future20-k8s-nodes"
ssh_public_key = ""

# Node capacity:
# - 3 nodes × 4 vCPU, 8 GB RAM = 12 vCPU, 24 GB RAM total
# - Suitable for: ~20-25 microservices with moderate load
# - Can scale to 6 nodes = 24 vCPU, 48 GB RAM under peak load

# ============================================================================
# MANAGED POSTGRESQL CONFIGURATION
# ============================================================================

postgresql_version = "15"  # Latest PostgreSQL 15.x

# Resource preset determines CPU and RAM
# s3-c2-m8: 2 vCPU, 8 GB RAM (development)
# s3-c4-m16: 4 vCPU, 16 GB RAM (production)
# Full list: https://cloud.yandex.ru/docs/managed-postgresql/concepts/instance-types
postgresql_resource_preset = "s3-c2-m8"

# Disk size in GB
postgresql_disk_size = 100  # Start with 100 GB

# Number of hosts per cluster
# 1 = Single host (dev/staging)
# 2 = Primary + Replica (production with HA)
# 3 = Primary + 2 Replicas (maximum HA)
postgresql_host_count = 1

# Database credentials
# IMPORTANT: In production, use Yandex Lockbox instead of hardcoded values
db_master_username = "dbadmin"
db_master_password = "ChangeMe123!SecurePassword"  # CHANGE THIS IN PRODUCTION!

# Storage planning:
# - Healthcare DB: Medical data (non-PHI), appointments, billing → ~150 GB/year
# - Fintech DB: Transactions, accounts, credit history → ~100 GB/year
# - Initial 100 GB provides ~6-12 months of growth
# - Can extend up to 4096 GB

# ============================================================================
# OBJECT STORAGE CONFIGURATION
# ============================================================================

enable_storage_versioning     = true  # Enable versioning for data protection
storage_lifecycle_glacier_days = 180  # Move to ICE (cold storage) after 6 months

# Object Storage structure:
# - /raw/        - Raw data from sources (CDC, APIs)
# - /curated/    - Cleaned and transformed data
# - /analytics/  - Aggregated data for analytics
# - /archive/    - Historical data (auto-archived to ICE)

# ============================================================================
# FEATURE FLAGS
# ============================================================================

enable_nat_gateway_per_az = true  # NAT instance per AZ for HA

# ============================================================================
# ADDITIONAL LABELS
# ============================================================================

additional_labels = {
  cost_center = "engineering"
  team        = "platform"
  contact     = "platform-team@future20.com"
  compliance  = "152-fz"
  backup      = "daily"
}

# ============================================================================
# QUICK START
# ============================================================================

# 1. Install Yandex Cloud CLI:
#    curl https://storage.yandexcloud.net/yandexcloud-yc/install.sh | bash
#
# 2. Initialize:
#    yc init
#
# 3. Get credentials:
#    yc config list
#
# 4. Update this file with your credentials (yc_token, yc_cloud_id, yc_folder_id)
#
# 5. Initialize Terraform:
#    terraform init
#
# 6. Plan:
#    terraform plan
#
# 7. Apply:
#    terraform apply
#    (Will take ~20-25 minutes)
#
# 8. Configure kubectl:
#    yc managed-kubernetes cluster get-credentials future20-k8s --external --force
#
# 9. Verify:
#    kubectl get nodes
