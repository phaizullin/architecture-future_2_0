# ============================================================================
# YANDEX CLOUD CREDENTIALS
# ============================================================================

variable "yc_token" {
  description = "Yandex Cloud OAuth token or IAM token"
  type        = string
  sensitive   = true
}

variable "yc_cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "yc_folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "yc_zone" {
  description = "Default availability zone"
  type        = string
  default     = "ru-central1-a"
  
  validation {
    condition     = can(regex("^ru-central1-[abc]$", var.yc_zone))
    error_message = "Zone must be ru-central1-a, ru-central1-b, or ru-central1-c."
  }
}

# ============================================================================
# GENERAL VARIABLES
# ============================================================================

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "future20"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Project name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

# ============================================================================
# NETWORKING VARIABLES
# ============================================================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
  
  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "VPC CIDR must be a valid IPv4 CIDR block."
  }
}

variable "az_count" {
  description = "Number of Availability Zones to use (2-3 recommended for HA)"
  type        = number
  default     = 3
  
  validation {
    condition     = var.az_count >= 2 && var.az_count <= 3
    error_message = "AZ count must be between 2 and 3 for high availability."
  }
}

# ============================================================================
# KUBERNETES CLUSTER VARIABLES
# ============================================================================

variable "k8s_version" {
  description = "Kubernetes version for managed cluster"
  type        = string
  default     = "1.28"
}

variable "k8s_node_cores" {
  description = "Number of CPU cores for each Kubernetes node"
  type        = number
  default     = 4
  
  validation {
    condition     = contains([2, 4, 6, 8], var.k8s_node_cores)
    error_message = "Node cores must be 2, 4, 6, or 8."
  }
}

variable "k8s_node_memory" {
  description = "Memory in GB for each Kubernetes node"
  type        = number
  default     = 8
  
  validation {
    condition     = var.k8s_node_memory >= 4 && var.k8s_node_memory <= 32
    error_message = "Node memory must be between 4 and 32 GB."
  }
}

variable "k8s_node_disk_size" {
  description = "Boot disk size in GB for Kubernetes nodes"
  type        = number
  default     = 64
  
  validation {
    condition     = var.k8s_node_disk_size >= 64
    error_message = "Node disk size must be at least 64 GB."
  }
}

variable "k8s_node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 3
  
  validation {
    condition     = var.k8s_node_desired_size >= 2
    error_message = "Desired size must be at least 2 for high availability."
  }
}

variable "k8s_node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 2
  
  validation {
    condition     = var.k8s_node_min_size >= 2
    error_message = "Minimum size must be at least 2 for high availability."
  }
}

variable "k8s_node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 6
  
  validation {
    condition     = var.k8s_node_max_size >= var.k8s_node_desired_size
    error_message = "Maximum size must be greater than or equal to desired size."
  }
}

variable "k8s_node_preemptible" {
  description = "Use preemptible (spot) instances for cost savings"
  type        = bool
  default     = false
}

variable "ssh_public_key" {
  description = "SSH public key for access to nodes (optional)"
  type        = string
  default     = ""
}

# ============================================================================
# MANAGED POSTGRESQL VARIABLES
# ============================================================================

variable "postgresql_version" {
  description = "PostgreSQL version for managed clusters"
  type        = string
  default     = "15"
  
  validation {
    condition     = contains(["14", "15", "16"], var.postgresql_version)
    error_message = "PostgreSQL version must be 14, 15, or 16."
  }
}

variable "postgresql_resource_preset" {
  description = "Resource preset for PostgreSQL (determines CPU and RAM)"
  type        = string
  default     = "s3-c2-m8"
  
  validation {
    condition     = can(regex("^s[123]-c[248]-m[48]$|^s[123]-c[248]-m1[26]$|^s[123]-c[248]-m3[26]$", var.postgresql_resource_preset))
    error_message = "Invalid PostgreSQL resource preset. Examples: s3-c2-m8 (2 vCPU, 8 GB RAM)"
  }
}

variable "postgresql_disk_size" {
  description = "Disk size in GB for PostgreSQL clusters"
  type        = number
  default     = 100
  
  validation {
    condition     = var.postgresql_disk_size >= 10 && var.postgresql_disk_size <= 4096
    error_message = "PostgreSQL disk size must be between 10 and 4096 GB."
  }
}

variable "postgresql_host_count" {
  description = "Number of hosts in PostgreSQL cluster (1 for single, 2+ for HA)"
  type        = number
  default     = 1
  
  validation {
    condition     = var.postgresql_host_count >= 1 && var.postgresql_host_count <= 3
    error_message = "PostgreSQL host count must be between 1 and 3."
  }
}

variable "db_master_username" {
  description = "Master username for PostgreSQL clusters"
  type        = string
  default     = "dbadmin"
  sensitive   = true
  
  validation {
    condition     = length(var.db_master_username) >= 3
    error_message = "Database master username must be at least 3 characters."
  }
}

variable "db_master_password" {
  description = "Master password for PostgreSQL clusters"
  type        = string
  sensitive   = true
  
  validation {
    condition     = length(var.db_master_password) >= 8
    error_message = "Database master password must be at least 8 characters."
  }
}

# ============================================================================
# OBJECT STORAGE VARIABLES
# ============================================================================

variable "enable_storage_versioning" {
  description = "Enable versioning for Object Storage Data Lake bucket"
  type        = bool
  default     = true
}

variable "storage_lifecycle_glacier_days" {
  description = "Number of days before transitioning to ICE (Glacier equivalent)"
  type        = number
  default     = 180
  
  validation {
    condition     = var.storage_lifecycle_glacier_days >= 30
    error_message = "ICE transition must be at least 30 days."
  }
}

# ============================================================================
# FEATURE FLAGS
# ============================================================================

variable "enable_nat_gateway_per_az" {
  description = "Create NAT instance per AZ (recommended for production)"
  type        = bool
  default     = true
}

# ============================================================================
# TAGS VARIABLES
# ============================================================================

variable "additional_labels" {
  description = "Additional labels to apply to all resources"
  type        = map(string)
  default     = {}
}
