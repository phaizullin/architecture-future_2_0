## 1. Общая архитектура

### 1.1. Выбор облачного провайдера: Yandex Cloud

**Обоснование выбора Yandex Cloud:**

1. **Соответствие 152-ФЗ**: Данные хранятся на территории России, что критично для медицинской и финансовой компании
2. **ГОСТ-совместимость**: Поддержка российских стандартов криптографии и безопасности
3. **Независимость от санкций**: Российская инфраструктура, нет рисков блокировки сервисов
4. **Рублевое ценообразование**: Отсутствие валютных рисков, стабильное планирование бюджета
5. **Техподдержка на русском языке**: 24/7 поддержка специалистами, знакомыми с российскими реалиями
6. **Зрелость сервисов**: Managed Kubernetes, PostgreSQL, Object Storage на уровне мировых аналогов

**Регион: ru-central1 (3 зоны доступности)**
- ru-central1-a, ru-central1-b, ru-central1-c
- Все данные в России (152-ФЗ compliance)
- Низкая latency для российских пользователей (< 10ms из Москвы)
- Полная изоляция зон доступности (независимые ЦОДы)
- Наличие всех необходимых сервисов (Managed Kubernetes, PostgreSQL, Object Storage)

---

## 2. Сетевая архитектура (VPC Network)

### 2.1. Топология VPC

**Выбранная конфигурация:**
- **VPC CIDR**: 10.0.0.0/16 (65,536 IP-адресов)
- **Availability Zones**: 3 (ru-central1-a, ru-central1-b, ru-central1-c)
- **Типы подсетей**: Public, Private, Database

**Обоснование:**

1. **CIDR 10.0.0.0/16**:
   - Достаточно адресов для роста (65К+ IP)
   - Стандартный диапазон для корпоративных сетей
   - Не конфликтует с типичными on-premise сетями (192.168.x.x, 172.16.x.x)
   - Позволяет разделить на множество подсетей (/24) для разных целей

2. **3 Availability Zones** (vs 2 в AWS конфигурации):
   - **High Availability**: Отказ даже 2 AZ не влияет на работу системы
   - **Yandex Cloud особенность**: 3 зоны доступны в ru-central1 (используем все)
   - **Geographic distribution**: Физически разные ЦОДы в Московском регионе
   - **Cost consideration**: +50% к стоимости NAT instances, но +33% к надежности

### 2.2. Структура подсетей

**Public Subnets (10.0.0.0/24, 10.0.1.0/24, 10.0.2.0/24)**:
- **Назначение**: Load Balancers, NAT instances, Bastion hosts
- **Размер**: /24 (256 IP) × 3 = 768 IP
- **Public IP**: Назначаются через NAT или явно
- **Доступ**: Прямой доступ в интернет через routing

**Private Subnets (10.0.3.0/24, 10.0.4.0/24, 10.0.5.0/24)**:
- **Назначение**: Kubernetes worker nodes, application pods
- **Размер**: /24 (256 IP) × 3 = 768 IP
- **NAT**: Исходящий трафик через NAT instances (безопасность)
- **Isolation**: Нет прямого доступа из интернета

**Database Subnets (10.0.6.0/24, 10.0.7.0/24, 10.0.8.0/24)**:
- **Назначение**: Managed PostgreSQL clusters (Healthcare, Fintech)
- **Размер**: /24 (256 IP) × 3 = 768 IP
- **Изоляция**: Нет доступа в интернет вообще (максимальная безопасность)
- **Separation of Concerns**: Базы данных полностью изолированы от application layer

### 2.3. NAT Instances (vs NAT Gateway в AWS)

**Конфигурация**: 3 NAT instances (по одному на AZ)

**Спецификация NAT instance:**
- **Platform**: standard-v3
- **vCPU**: 2
- **RAM**: 2 GB
- **Image**: NAT instance из Yandex Marketplace
- **Disk**: 10 GB network-hdd
- **Public IP**: Elastic IP на каждый instance

**Обоснование:**

**Почему NAT instances, а не другие решения:**

1. **Yandex Cloud особенность**: Нет managed NAT Gateway (как в AWS), нужно использовать NAT instances
2. **Преимущества NAT instances**:
   - Полный контроль над конфигурацией
   - Возможность кастомизации (firewall rules, monitoring)
   - Доступ для troubleshooting (SSH)
   - Можно использовать preemptible для экономии (не для production)

3. **High Availability**: 1 NAT instance на AZ
   - Отказ NAT в одной AZ не влияет на другие
   - Private subnets в каждой AZ используют локальный NAT (нет cross-AZ трафика)
   - Route tables настроены per-AZ

4. **Performance**:
   - 2 vCPU достаточно для ~500 Мбит/с (типичная нагрузка)
   - Можно увеличить до 4 vCPU при необходимости
   - Network performance: до 5 Гбит/с на standard-v3

---

## 3. Yandex Managed Kubernetes

### 3.1. Почему Managed Kubernetes?

**Обоснование выбора Kubernetes:**

1. **Microservices Architecture**:
   - 4+ доменов (Healthcare, Fintech, AI/ML, Corporate), каждый с 5-10 микросервисами
   - Независимое развертывание и масштабирование доменов
   - Service mesh (Istio) для inter-domain communication

2. **Auto-scaling**:
   - Horizontal Pod Autoscaler (HPA): масштабирование по CPU/memory/custom metrics
   - Cluster Autoscaler: автоматическое добавление/удаление nodes
   - Экономия: scale-down в ночное время (до 50% экономии)

3. **Declarative Configuration**:
   - Infrastructure as Code для приложений (Helm charts, Kustomize)
   - GitOps workflow (ArgoCD, Flux)
   - Версионирование и rollback за секунды

4. **Portability**:
   - Multi-cloud готовность (Yandex Cloud → AWS → Azure)
   - Standard Kubernetes API
   - Минимизация vendor lock-in

5. **Ecosystem**:
   - Prometheus + Grafana для мониторинга
   - Calico для Network Policies
   - Cert-manager для TLS сертификатов
   - External Secrets Operator для интеграции с Yandex Lockbox

### 3.2. Конфигурация Managed Kubernetes

**Master (Control Plane):**
- **Version**: 1.28 (latest stable)
- **Type**: Zonal (в ru-central1-a)
- **Public IP**: Да (для доступа через kubectl)
- **Maintenance window**: Понедельник, 03:00-06:00 (автообновления)
- **Security Group**: Доступ к API server (443)

**Node Group конфигурация:**

```
Platform: standard-v3
vCPU: 4
Memory: 8 GB
Disk: 64 GB network-ssd

Node Count:
  - Min: 2 (high availability)
  - Desired: 3 (balanced capacity)
  - Max: 6 (peak load)

Allocation: Все 3 AZ (ru-central1-a/b/c)
```

**Обоснование sizing (4 vCPU, 8 GB RAM):**

1. **CPU**: 4 vCPU × 3 nodes = 12 vCPU total
   - Резервирование: ~1 vCPU для system pods (kubelet, kube-proxy, CNI, calico)
   - Available: ~11 vCPU для application pods
   - Capacity: 20-25 микросервисов с request: 200-400m CPU

2. **Memory**: 8 GB × 3 nodes = 24 GB total
   - Резервирование: ~2 GB для system pods
   - Available: ~22 GB для application pods
   - Capacity: 20-25 микросервисов с request: 1 GB memory

3**Comparison с меньшими instances**:
   - 2 vCPU, 4 GB: Мало памяти для Java/Python микросервисов
   - 2 vCPU, 8 GB: Недостаточно CPU для compute-intensive задач
   - **4 vCPU, 8 GB**: ✅ Balanced для mixed workloads

4**Comparison с большими instances**:
   - 8 vCPU, 16 GB: Избыточно для dev, подходит для production
   - 4 vCPU, 16 GB: Много памяти для типичных микросервисов

**Scaling стратегия:**

```
Normal load (day):   3 nodes (12 vCPU, 24 GB)
Peak load:           6 nodes (24 vCPU, 48 GB)
Night time:          2 nodes (8 vCPU, 16 GB) - экономия 33%
```

### 3.3. Kubernetes Networking (Calico)

**Network Policy Provider: Calico**

**Обоснование выбора Calico:**
- Yandex Managed Kubernetes использует Calico по умолчанию
- Высокая производительность (iptables/eBPF based)
- Поддержка Network Policies (fine-grained control)
- Battle-tested в production

**Pod Networking:**
- Каждый pod получает IP из subnet CIDR
- No overlay network (native routing через VPC)
- Security Groups для pods (Yandex specific feature)

**Capacity Planning:**

```
4 vCPU, 8 GB node поддерживает:
- Max Pods per node: ~110 (Kubernetes default)
- Практически: ~30-40 pods (ограничение по ресурсам)

3 nodes × 35 pods = 105 pods максимум (комфортно)
```

**IP Address planning (Private Subnet 10.0.3.0/24)**:
- Total IPs: 256
- Reserved (Yandex): 4
- Kubernetes nodes: 6 (max)
- Pods: ~200 (6 × 35)
- Available: 46 IPs (запас)

### 3.4. Service Accounts и IAM

**Service Account для Kubernetes Cluster:**
- **Role**: `k8s.clusters.agent` (управление кластером)
- **Role**: `vpc.publicAdmin` (управление Load Balancers)

**Service Account для Kubernetes Nodes:**
- **Role**: `container-registry.images.puller` (pull Docker images)
- **Role**: `storage.editor` (доступ к Object Storage)

---

## 4. Yandex Managed PostgreSQL

### 4.1. Почему Managed PostgreSQL, а не PostgreSQL в Kubernetes?

**Для чего подойдет PostgreSQL в K8s:**
- Development/staging environments (экономия)
- Специфичные PostgreSQL extensions (не поддерживаемые Yandex)
- Hybrid cloud (одинаковая конфигурация везде)

**Для production: Managed PostgreSQL предпочтительнее**
- Критичные данные (финансы, медицина)
- Требования к uptime (99.95%+)
- Compliance (152-ФЗ, ГОСТ)

### 4.2. Конфигурация Managed PostgreSQL

**Resource Preset: s3-c2-m8**
- Platform: standard-v3
- vCPU: 2
- Memory: 8 GB
- Disk: network-ssd

**Обоснование s3-c2-m8:**

1. **Memory**: 8 GB для PostgreSQL
   - Shared buffers: 2 GB (25% от RAM)
   - Work mem: 64 MB × 50 connections = 3.2 GB
   - OS cache: 2.8 GB
   - Достаточно для БД размером 100-200 GB с умеренной нагрузкой

2. **CPU**: 2 vCPU
   - Обработка 100-200 queries/sec
   - Parallel queries (для аналитики)
   - Достаточно для OLTP workload

**Storage:**
- Type: network-ssd
- Initial: 100 GB
- Max: можно увеличить до 4096 GB
- IOPS: 9,000 (3 IOPS/GB × 100 GB × 30 burst)
- Throughput: 100 MB/s

---

## 5. Yandex Object Storage (Data Lake)

### 5.1. Почему Object Storage для Data Lake?

**Обоснование:**

1. **Durability**: 99.999999999% (11 девяток)
   - Данные реплицируются в 3 зоны доступности
   - Автоматическое восстановление при сбоях
   - 
2.**Scalability**:
   - Unlimited storage (петабайты)
   - Automatic scaling (no provisioning)
   - 7,000 requests/sec per prefix

3.**S3-compatible API**:
   - Работает с любыми S3-compatible инструментами (AWS CLI, boto3, s3fs)
   - Легкая миграция приложений с S3
   - Standard de-facto для Data Lake

4.**Integration**:
   - Yandex Data Proc (Spark, Hive)
   - Kafka S3 Sink Connector
   - Airflow, DBT, Great Expectations


---

## 7. Infrastructure as Code (IaC)

### 7.1. Почему Terraform?

**Обоснование выбора Terraform:**

1. **Multi-cloud**: Если в будущем мигрируем на AWS/Azure - 70% кода переиспользуется
2. **Ecosystem**: 3000+ providers (Yandex, Kubernetes, Datadog, PagerDuty)
3. **Community**: Огромное community, много примеров
4. **Declarative**: HCL легко читается и понимается (vs programming в Pulumi)
5. **Industry standard**: Terraform - де-факто стандарт для IaC

### 7.2. Преимущества IaC подхода

**1. Воспроизводимость (Reproducibility):**

```bash
# Та же конфигурация → идентичная инфраструктура
terraform apply  # Dev environment
terraform apply  # Staging environment
terraform apply  # Production environment
```

- Нет "configuration drift" (ручные изменения)
- Идентичные dev/staging/prod (кроме sizing параметров)
- Disaster Recovery: `terraform apply` восстанавливает инфраструктуру за 20-25 минут

**2. Версионирование:**

- История изменений инфраструктуры (кто, когда, что)
- Code review для infrastructure changes (через PR)
- Rollback к предыдущей версии за секунды

**3. Documentation as Code:**

- Terraform файлы = актуальная документация инфраструктуры
- Комментарии в коде объясняют решения
- `terraform show` - текущее состояние инфраструктуры

**4. Testing:**

```bash
terraform plan  # Dry run (preview changes)
terraform validate  # Syntax validation
tflint  # Linting для best practices
```

- Preview changes перед применением
- Automated tests в CI/CD (prevent misconfigurations)

**5. Collaboration:**

- Team работает над одной конфигурацией (Git)
- Object Storage backend - shared state
- Locking mechanism - предотвращает concurrent changes
