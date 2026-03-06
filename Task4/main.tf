
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100"
    }
  }
}

provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
  zone      = var.yc_zone
}

# ============================================================================
# DATA SOURCES
# ============================================================================

# Get available zones
data "yandex_compute_zones" "available" {}

# ============================================================================
# VPC AND NETWORKING
# ============================================================================

# Main VPC
resource "yandex_vpc_network" "main" {
  name        = "${var.project_name}-network-${var.environment}"
  description = "Main VPC for Future 2.0 infrastructure"
  
  labels = {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
    owner       = "platform-team"
  }
}

# Public Subnets (for Load Balancers, NAT instances)
resource "yandex_vpc_subnet" "public" {
  count = var.az_count
  
  name           = "${var.project_name}-public-subnet-${count.index + 1}"
  description    = "Public subnet for load balancers and NAT"
  v4_cidr_blocks = [cidrsubnet(var.vpc_cidr, 8, count.index)]
  zone           = data.yandex_compute_zones.available.zones[count.index]
  network_id     = yandex_vpc_network.main.id
  
  labels = {
    type        = "public"
    project     = var.project_name
    environment = var.environment
  }
}

# Private Subnets (for Kubernetes nodes, internal services)
resource "yandex_vpc_subnet" "private" {
  count = var.az_count
  
  name           = "${var.project_name}-private-subnet-${count.index + 1}"
  description    = "Private subnet for Kubernetes nodes"
  v4_cidr_blocks = [cidrsubnet(var.vpc_cidr, 8, count.index + var.az_count)]
  zone           = data.yandex_compute_zones.available.zones[count.index]
  network_id     = yandex_vpc_network.main.id
  route_table_id = yandex_vpc_route_table.private[count.index].id
  
  labels = {
    type        = "private"
    project     = var.project_name
    environment = var.environment
  }
}

# Database Subnets (isolated for managed PostgreSQL)
resource "yandex_vpc_subnet" "database" {
  count = var.az_count
  
  name           = "${var.project_name}-database-subnet-${count.index + 1}"
  description    = "Database subnet for managed PostgreSQL"
  v4_cidr_blocks = [cidrsubnet(var.vpc_cidr, 8, count.index + (var.az_count * 2))]
  zone           = data.yandex_compute_zones.available.zones[count.index]
  network_id     = yandex_vpc_network.main.id
  
  labels = {
    type        = "database"
    project     = var.project_name
    environment = var.environment
  }
}

# NAT Gateway (Yandex Cloud uses NAT instances)
resource "yandex_compute_instance" "nat" {
  count = var.enable_nat_gateway_per_az ? var.az_count : 1
  
  name        = "${var.project_name}-nat-${count.index + 1}"
  description = "NAT instance for private subnet internet access"
  zone        = data.yandex_compute_zones.available.zones[count.index]
  
  resources {
    cores  = 2
    memory = 2
  }
  
  boot_disk {
    initialize_params {
      image_id = "fd8v7ru46kt3s4o5f0uo"  # NAT instance image from Yandex
      size     = 10
      type     = "network-hdd"
    }
  }
  
  network_interface {
    subnet_id = yandex_vpc_subnet.public[count.index].id
    nat       = true
  }
  
  metadata = {
    serial-port-enable = 1
  }
  
  labels = {
    type        = "nat"
    project     = var.project_name
    environment = var.environment
  }
}

# Route Table for Private Subnets (через NAT)
resource "yandex_vpc_route_table" "private" {
  count = var.az_count
  
  name        = "${var.project_name}-private-rt-${count.index + 1}"
  description = "Route table for private subnet ${count.index + 1}"
  network_id  = yandex_vpc_network.main.id
  
  static_route {
    destination_prefix = "0.0.0.0/0"
    next_hop_address   = yandex_compute_instance.nat[var.enable_nat_gateway_per_az ? count.index : 0].network_interface.0.ip_address
  }
  
  labels = {
    project     = var.project_name
    environment = var.environment
  }
}

# ============================================================================
# SECURITY GROUPS
# ============================================================================

# Security Group for Kubernetes Cluster
resource "yandex_vpc_security_group" "k8s_cluster" {
  name        = "${var.project_name}-k8s-cluster-sg"
  description = "Security group for Kubernetes cluster"
  network_id  = yandex_vpc_network.main.id
  
  # Allow incoming traffic from load balancers
  ingress {
    protocol       = "TCP"
    description    = "Allow HTTPS from load balancers"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 443
  }
  
  ingress {
    protocol       = "TCP"
    description    = "Allow HTTP from load balancers"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }
  
  # Allow incoming traffic from Kubernetes API
  ingress {
    protocol       = "TCP"
    description    = "Kubernetes API"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 6443
  }
  
  # Allow inter-node communication
  ingress {
    protocol       = "ANY"
    description    = "Allow all traffic within cluster"
    predefined_target = "self_security_group"
  }
  
  # Allow all outbound traffic
  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  
  labels = {
    project     = var.project_name
    environment = var.environment
  }
}

# Security Group for Managed PostgreSQL
resource "yandex_vpc_security_group" "postgresql" {
  name        = "${var.project_name}-postgresql-sg"
  description = "Security group for managed PostgreSQL"
  network_id  = yandex_vpc_network.main.id
  
  # Allow PostgreSQL from Kubernetes nodes
  ingress {
    protocol          = "TCP"
    description       = "PostgreSQL from K8s nodes"
    security_group_id = yandex_vpc_security_group.k8s_cluster.id
    port              = 6432
  }
  
  # Allow all outbound traffic
  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  
  labels = {
    project     = var.project_name
    environment = var.environment
  }
}

# ============================================================================
# SERVICE ACCOUNTS AND IAM
# ============================================================================

# Service Account for Kubernetes Cluster
resource "yandex_iam_service_account" "k8s_cluster" {
  name        = "${var.project_name}-k8s-cluster-sa"
  description = "Service account for Kubernetes cluster"
}

# Service Account for Kubernetes Nodes
resource "yandex_iam_service_account" "k8s_nodes" {
  name        = "${var.project_name}-k8s-nodes-sa"
  description = "Service account for Kubernetes worker nodes"
}

# Role: k8s.clusters.agent (for cluster)
resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_agent" {
  folder_id = var.yc_folder_id
  role      = "k8s.clusters.agent"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

# Role: vpc.publicAdmin (for cluster - to manage load balancers)
resource "yandex_resourcemanager_folder_iam_member" "k8s_cluster_vpc_admin" {
  folder_id = var.yc_folder_id
  role      = "vpc.publicAdmin"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_cluster.id}"
}

# Role: container-registry.images.puller (for nodes - to pull images)
resource "yandex_resourcemanager_folder_iam_member" "k8s_nodes_images_puller" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_nodes.id}"
}

# Role: storage.editor (for nodes - to access Object Storage)
resource "yandex_resourcemanager_folder_iam_member" "k8s_nodes_storage_editor" {
  folder_id = var.yc_folder_id
  role      = "storage.editor"
  member    = "serviceAccount:${yandex_iam_service_account.k8s_nodes.id}"
}

# Service Account for Object Storage access
resource "yandex_iam_service_account" "storage" {
  name        = "${var.project_name}-storage-sa"
  description = "Service account for Object Storage access"
}

# Static Access Key for Object Storage
resource "yandex_iam_service_account_static_access_key" "storage" {
  service_account_id = yandex_iam_service_account.storage.id
  description        = "Static access key for Object Storage"
}

# ============================================================================
# MANAGED KUBERNETES CLUSTER
# ============================================================================

resource "yandex_kubernetes_cluster" "main" {
  name        = "${var.project_name}-k8s"
  description = "Managed Kubernetes cluster for Future 2.0"
  
  network_id = yandex_vpc_network.main.id
  
  master {
    version = var.k8s_version
    
    zonal {
      zone      = data.yandex_compute_zones.available.zones[0]
      subnet_id = yandex_vpc_subnet.public[0].id
    }
    
    public_ip = true
    
    maintenance_policy {
      auto_upgrade = true
      
      maintenance_window {
        day        = "monday"
        start_time = "03:00"
        duration   = "3h"
      }
    }
    
    security_group_ids = [yandex_vpc_security_group.k8s_cluster.id]
  }
  
  service_account_id      = yandex_iam_service_account.k8s_cluster.id
  node_service_account_id = yandex_iam_service_account.k8s_nodes.id
  
  release_channel         = "STABLE"
  network_policy_provider = "CALICO"
  
  kms_provider {
    key_id = yandex_kms_symmetric_key.k8s.id
  }
  
  labels = {
    project     = var.project_name
    environment = var.environment
  }
  
  depends_on = [
    yandex_resourcemanager_folder_iam_member.k8s_cluster_agent,
    yandex_resourcemanager_folder_iam_member.k8s_cluster_vpc_admin,
    yandex_resourcemanager_folder_iam_member.k8s_nodes_images_puller,
    yandex_resourcemanager_folder_iam_member.k8s_nodes_storage_editor
  ]
}

# Kubernetes Node Group
resource "yandex_kubernetes_node_group" "main" {
  cluster_id  = yandex_kubernetes_cluster.main.id
  name        = "${var.project_name}-node-group"
  description = "Main node group for applications"
  version     = var.k8s_version
  
  instance_template {
    platform_id = "standard-v3"
    
    resources {
      cores         = var.k8s_node_cores
      memory        = var.k8s_node_memory
      core_fraction = 100
    }
    
    boot_disk {
      type = "network-ssd"
      size = var.k8s_node_disk_size
    }
    
    network_interface {
      subnet_ids         = yandex_vpc_subnet.private[*].id
      nat                = false
      security_group_ids = [yandex_vpc_security_group.k8s_cluster.id]
    }
    
    metadata = {
      ssh-keys = var.ssh_public_key != "" ? "ubuntu:${var.ssh_public_key}" : ""
    }
    
    scheduling_policy {
      preemptible = var.k8s_node_preemptible
    }
  }
  
  scale_policy {
    auto_scale {
      min     = var.k8s_node_min_size
      max     = var.k8s_node_max_size
      initial = var.k8s_node_desired_size
    }
  }
  
  allocation_policy {
    dynamic "location" {
      for_each = range(var.az_count)
      content {
        zone = data.yandex_compute_zones.available.zones[location.value]
      }
    }
  }
  
  maintenance_policy {
    auto_upgrade = true
    auto_repair  = true
    
    maintenance_window {
      day        = "monday"
      start_time = "03:00"
      duration   = "3h"
    }
  }
  
  labels = {
    project     = var.project_name
    environment = var.environment
  }
}

# KMS Key for Kubernetes encryption
resource "yandex_kms_symmetric_key" "k8s" {
  name              = "${var.project_name}-k8s-encryption-key"
  description       = "KMS key for Kubernetes secrets encryption"
  default_algorithm = "AES_256"
  rotation_period   = "8760h" # 1 year
  
  labels = {
    project     = var.project_name
    environment = var.environment
  }
}

# ============================================================================
# MANAGED POSTGRESQL CLUSTERS
# ============================================================================

# PostgreSQL Cluster for Healthcare Domain
resource "yandex_mdb_postgresql_cluster" "healthcare" {
  name        = "${var.project_name}-healthcare-pg"
  description = "PostgreSQL cluster for Healthcare domain"
  environment = upper(var.environment)
  network_id  = yandex_vpc_network.main.id
  
  config {
    version = var.postgresql_version
    
    resources {
      resource_preset_id = var.postgresql_resource_preset
      disk_type_id       = "network-ssd"
      disk_size          = var.postgresql_disk_size
    }
    
    postgresql_config = {
      max_connections                = 200
      shared_buffers                 = 2147483648  # 2 GB
      effective_cache_size           = 6442450944  # 6 GB
      maintenance_work_mem           = 536870912   # 512 MB
      checkpoint_completion_target   = 0.9
      wal_buffers                    = 16777216    # 16 MB
      default_statistics_target      = 100
      random_page_cost               = 1.1
      effective_io_concurrency       = 200
      work_mem                       = 10485760    # 10 MB
      min_wal_size                   = 1073741824  # 1 GB
      max_wal_size                   = 4294967296  # 4 GB
    }
    
    access {
      data_lens = false
      web_sql   = false
    }
    
    backup_window_start {
      hours   = 3
      minutes = 0
    }
    
    backup_retain_period_days = 7
  }
  
  dynamic "host" {
    for_each = range(var.postgresql_host_count)
    content {
      zone             = data.yandex_compute_zones.available.zones[host.value % var.az_count]
      subnet_id        = yandex_vpc_subnet.database[host.value % var.az_count].id
      assign_public_ip = false
    }
  }
  
  security_group_ids = [yandex_vpc_security_group.postgresql.id]
  
  maintenance_window {
    type = "WEEKLY"
    day  = "MON"
    hour = 3
  }
  
  labels = {
    project     = var.project_name
    environment = var.environment
    domain      = "healthcare"
  }
}

# PostgreSQL Database for Healthcare
resource "yandex_mdb_postgresql_database" "healthcare" {
  cluster_id = yandex_mdb_postgresql_cluster.healthcare.id
  name       = "healthcare"
  owner      = yandex_mdb_postgresql_user.healthcare.name
  
  extension {
    name = "uuid-ossp"
  }
  
  extension {
    name = "pg_stat_statements"
  }
}

# PostgreSQL User for Healthcare
resource "yandex_mdb_postgresql_user" "healthcare" {
  cluster_id = yandex_mdb_postgresql_cluster.healthcare.id
  name       = var.db_master_username
  password   = var.db_master_password
  
  permission {
    database_name = "healthcare"
  }
  
  conn_limit = 50
}

# PostgreSQL Cluster for Fintech Domain
resource "yandex_mdb_postgresql_cluster" "fintech" {
  name        = "${var.project_name}-fintech-pg"
  description = "PostgreSQL cluster for Fintech domain"
  environment = upper(var.environment)
  network_id  = yandex_vpc_network.main.id
  
  config {
    version = var.postgresql_version
    
    resources {
      resource_preset_id = var.postgresql_resource_preset
      disk_type_id       = "network-ssd"
      disk_size          = var.postgresql_disk_size
    }
    
    postgresql_config = {
      max_connections                = 200
      shared_buffers                 = 2147483648  # 2 GB
      effective_cache_size           = 6442450944  # 6 GB
      maintenance_work_mem           = 536870912   # 512 MB
      checkpoint_completion_target   = 0.9
      wal_buffers                    = 16777216    # 16 MB
      default_statistics_target      = 100
      random_page_cost               = 1.1
      effective_io_concurrency       = 200
      work_mem                       = 10485760    # 10 MB
      min_wal_size                   = 1073741824  # 1 GB
      max_wal_size                   = 4294967296  # 4 GB
    }
    
    access {
      data_lens = false
      web_sql   = false
    }
    
    backup_window_start {
      hours   = 3
      minutes = 0
    }
    
    backup_retain_period_days = 7
  }
  
  dynamic "host" {
    for_each = range(var.postgresql_host_count)
    content {
      zone             = data.yandex_compute_zones.available.zones[host.value % var.az_count]
      subnet_id        = yandex_vpc_subnet.database[host.value % var.az_count].id
      assign_public_ip = false
    }
  }
  
  security_group_ids = [yandex_vpc_security_group.postgresql.id]
  
  maintenance_window {
    type = "WEEKLY"
    day  = "MON"
    hour = 3
  }
  
  labels = {
    project     = var.project_name
    environment = var.environment
    domain      = "fintech"
  }
}

# PostgreSQL Database for Fintech
resource "yandex_mdb_postgresql_database" "fintech" {
  cluster_id = yandex_mdb_postgresql_cluster.fintech.id
  name       = "fintech"
  owner      = yandex_mdb_postgresql_user.fintech.name
  
  extension {
    name = "uuid-ossp"
  }
  
  extension {
    name = "pg_stat_statements"
  }
}

# PostgreSQL User for Fintech
resource "yandex_mdb_postgresql_user" "fintech" {
  cluster_id = yandex_mdb_postgresql_cluster.fintech.id
  name       = var.db_master_username
  password   = var.db_master_password
  
  permission {
    database_name = "fintech"
  }
  
  conn_limit = 50
}

# ============================================================================
# OBJECT STORAGE (S3-compatible) - DATA LAKE
# ============================================================================

# Object Storage Bucket for Data Lake
resource "yandex_storage_bucket" "data_lake" {
  bucket     = "${var.project_name}-data-lake-${var.environment}"
  access_key = yandex_iam_service_account_static_access_key.storage.access_key
  secret_key = yandex_iam_service_account_static_access_key.storage.secret_key
  
  # Enable versioning
  versioning {
    enabled = var.enable_storage_versioning
  }
  
  # Server-side encryption
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = yandex_kms_symmetric_key.storage.id
      }
    }
  }
  
  # Lifecycle rules
  lifecycle_rule {
    id      = "archive-old-data"
    enabled = true
    
    transition {
      days          = 90
      storage_class = "COLD"
    }
    
    transition {
      days          = var.storage_lifecycle_glacier_days
      storage_class = "ICE"
    }
    
    expiration {
      days = 365
    }
  }
  
  tags = {
    project     = var.project_name
    environment = var.environment
    purpose     = "data-lake"
  }
}

# KMS Key for Object Storage encryption
resource "yandex_kms_symmetric_key" "storage" {
  name              = "${var.project_name}-storage-encryption-key"
  description       = "KMS key for Object Storage encryption"
  default_algorithm = "AES_256"
  rotation_period   = "8760h" # 1 year
  
  labels = {
    project     = var.project_name
    environment = var.environment
  }
}

# ============================================================================
# CONTAINER REGISTRY
# ============================================================================

resource "yandex_container_registry" "main" {
  name      = "${var.project_name}-registry"
  folder_id = var.yc_folder_id
  
  labels = {
    project     = var.project_name
    environment = var.environment
  }
}

# ============================================================================
# MONITORING AND LOGGING
# ============================================================================

# Log Group for Kubernetes
resource "yandex_logging_group" "k8s" {
  name             = "${var.project_name}-k8s-logs"
  folder_id        = var.yc_folder_id
  retention_period = "604800s" # 7 days
  
  labels = {
    project     = var.project_name
    environment = var.environment
    service     = "kubernetes"
  }
}

# Log Group for PostgreSQL
resource "yandex_logging_group" "postgresql" {
  name             = "${var.project_name}-postgresql-logs"
  folder_id        = var.yc_folder_id
  retention_period = "604800s" # 7 days
  
  labels = {
    project     = var.project_name
    environment = var.environment
    service     = "postgresql"
  }
}
