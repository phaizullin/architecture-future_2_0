# ============================================================================
# VPC AND NETWORKING OUTPUTS
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC network"
  value       = yandex_vpc_network.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = yandex_vpc_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = yandex_vpc_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "IDs of database subnets"
  value       = yandex_vpc_subnet.database[*].id
}

output "nat_instance_ips" {
  description = "Public IPs of NAT instances"
  value       = yandex_compute_instance.nat[*].network_interface[0].nat_ip_address
}

# ============================================================================
# KUBERNETES CLUSTER OUTPUTS
# ============================================================================

output "k8s_cluster_id" {
  description = "ID of the Kubernetes cluster"
  value       = yandex_kubernetes_cluster.main.id
}

output "k8s_cluster_name" {
  description = "Name of the Kubernetes cluster"
  value       = yandex_kubernetes_cluster.main.name
}

output "k8s_cluster_endpoint" {
  description = "Endpoint for Kubernetes cluster API server (external)"
  value       = yandex_kubernetes_cluster.main.master[0].external_v4_endpoint
  sensitive   = true
}

output "k8s_cluster_internal_endpoint" {
  description = "Endpoint for Kubernetes cluster API server (internal)"
  value       = yandex_kubernetes_cluster.main.master[0].internal_v4_endpoint
}

output "k8s_cluster_version" {
  description = "Kubernetes version of the cluster"
  value       = yandex_kubernetes_cluster.main.master[0].version
}

output "k8s_cluster_ca_certificate" {
  description = "CA certificate for Kubernetes cluster"
  value       = yandex_kubernetes_cluster.main.master[0].cluster_ca_certificate
  sensitive   = true
}

output "k8s_node_group_id" {
  description = "ID of the Kubernetes node group"
  value       = yandex_kubernetes_node_group.main.id
}

output "k8s_cluster_security_group_id" {
  description = "Security group ID for Kubernetes cluster"
  value       = yandex_vpc_security_group.k8s_cluster.id
}

# Kubectl config command
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "yc managed-kubernetes cluster get-credentials ${yandex_kubernetes_cluster.main.name} --external --force"
}

# ============================================================================
# MANAGED POSTGRESQL OUTPUTS
# ============================================================================

output "postgresql_healthcare_cluster_id" {
  description = "ID of the Healthcare PostgreSQL cluster"
  value       = yandex_mdb_postgresql_cluster.healthcare.id
}

output "postgresql_healthcare_hosts" {
  description = "Hosts of the Healthcare PostgreSQL cluster"
  value       = yandex_mdb_postgresql_cluster.healthcare.host[*].fqdn
  sensitive   = true
}

output "postgresql_healthcare_database_name" {
  description = "Database name for Healthcare domain"
  value       = yandex_mdb_postgresql_database.healthcare.name
}

output "postgresql_fintech_cluster_id" {
  description = "ID of the Fintech PostgreSQL cluster"
  value       = yandex_mdb_postgresql_cluster.fintech.id
}

output "postgresql_fintech_hosts" {
  description = "Hosts of the Fintech PostgreSQL cluster"
  value       = yandex_mdb_postgresql_cluster.fintech.host[*].fqdn
  sensitive   = true
}

output "postgresql_fintech_database_name" {
  description = "Database name for Fintech domain"
  value       = yandex_mdb_postgresql_database.fintech.name
}

output "postgresql_security_group_id" {
  description = "Security group ID for PostgreSQL clusters"
  value       = yandex_vpc_security_group.postgresql.id
}

# ============================================================================
# OBJECT STORAGE OUTPUTS
# ============================================================================

output "storage_bucket_name" {
  description = "Name of the Object Storage Data Lake bucket"
  value       = yandex_storage_bucket.data_lake.bucket
}

output "storage_bucket_domain" {
  description = "Domain name of the Object Storage bucket"
  value       = yandex_storage_bucket.data_lake.bucket_domain_name
}

output "storage_access_key" {
  description = "Access key for Object Storage"
  value       = yandex_iam_service_account_static_access_key.storage.access_key
  sensitive   = true
}

output "storage_secret_key" {
  description = "Secret key for Object Storage"
  value       = yandex_iam_service_account_static_access_key.storage.secret_key
  sensitive   = true
}

# ============================================================================
# CONTAINER REGISTRY OUTPUTS
# ============================================================================

output "container_registry_id" {
  description = "ID of the Container Registry"
  value       = yandex_container_registry.main.id
}

output "container_registry_name" {
  description = "Name of the Container Registry"
  value       = yandex_container_registry.main.name
}

# ============================================================================
# SERVICE ACCOUNTS OUTPUTS
# ============================================================================

output "k8s_cluster_sa_id" {
  description = "ID of the Kubernetes cluster service account"
  value       = yandex_iam_service_account.k8s_cluster.id
}

output "k8s_nodes_sa_id" {
  description = "ID of the Kubernetes nodes service account"
  value       = yandex_iam_service_account.k8s_nodes.id
}

output "storage_sa_id" {
  description = "ID of the Object Storage service account"
  value       = yandex_iam_service_account.storage.id
}

# ============================================================================
# CONNECTION STRINGS (for application configuration)
# ============================================================================

output "healthcare_db_connection_string" {
  description = "Connection string for Healthcare database (use first host)"
  value       = "postgresql://${var.db_master_username}:PASSWORD@${yandex_mdb_postgresql_cluster.healthcare.host[0].fqdn}:6432/${yandex_mdb_postgresql_database.healthcare.name}"
  sensitive   = true
}

output "fintech_db_connection_string" {
  description = "Connection string for Fintech database (use first host)"
  value       = "postgresql://${var.db_master_username}:PASSWORD@${yandex_mdb_postgresql_cluster.fintech.host[0].fqdn}:6432/${yandex_mdb_postgresql_database.fintech.name}"
  sensitive   = true
}

# ============================================================================
# LOGGING OUTPUTS
# ============================================================================

output "k8s_log_group_id" {
  description = "ID of the Kubernetes log group"
  value       = yandex_logging_group.k8s.id
}

output "postgresql_log_group_id" {
  description = "ID of the PostgreSQL log group"
  value       = yandex_logging_group.postgresql.id
}

# ============================================================================
# SUMMARY OUTPUT
# ============================================================================

output "infrastructure_summary" {
  description = "Summary of the deployed infrastructure"
  value = {
    project_name = var.project_name
    environment  = var.environment
    cloud_id     = var.yc_cloud_id
    folder_id    = var.yc_folder_id
    
    networking = {
      vpc_id     = yandex_vpc_network.main.id
      vpc_cidr   = var.vpc_cidr
      azs_count  = var.az_count
    }
    
    kubernetes = {
      cluster_name    = yandex_kubernetes_cluster.main.name
      cluster_version = yandex_kubernetes_cluster.main.master[0].version
      node_count      = "${var.k8s_node_min_size}-${var.k8s_node_max_size}"
      node_resources  = "${var.k8s_node_cores} vCPU, ${var.k8s_node_memory} GB RAM"
    }
    
    postgresql = {
      healthcare_cluster = yandex_mdb_postgresql_cluster.healthcare.name
      fintech_cluster    = yandex_mdb_postgresql_cluster.fintech.name
      resource_preset    = var.postgresql_resource_preset
      postgresql_version = var.postgresql_version
    }
    
    storage = {
      data_lake_bucket = yandex_storage_bucket.data_lake.bucket
    }
    
    container_registry = {
      registry_name = yandex_container_registry.main.name
    }
  }
}

