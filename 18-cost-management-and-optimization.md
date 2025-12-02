# Cost Management & Optimization

Comprehensive guide to automated cost management, resource optimization, and financial governance in enterprise cloud infrastructure automation.

## Table of Contents

1. [Project Structure](#project-structure)
2. [Core Concepts](#core-concepts)
3. [Resource Tagging Strategy](#resource-tagging-strategy)
4. [Cost Allocation & Chargeback](#cost-allocation--chargeback)
5. [Automated Cost Optimization](#automated-cost-optimization)
6. [Reserved Instances & Savings Plans](#reserved-instances--savings-plans)
7. [Instance Right-Sizing](#instance-right-sizing)
8. [Storage Optimization](#storage-optimization)
9. [Data Transfer Optimization](#data-transfer-optimization)
10. [Monitoring & Alerting](#monitoring--alerting)
11. [Cost Governance](#cost-governance)

## Project Structure

### Recommended Directory Layout

```
cost-management/
├── terraform/
│   ├── modules/
│   │   ├── tagging/
│   │   │   ├── main.tf              # Tagging strategy
│   │   │   ├── variables.tf
│   │   │   └── locals.tf
│   │   ├── autoscaling/
│   │   │   ├── main.tf              # Cost-optimized ASG
│   │   │   ├── variables.tf
│   │   │   └── spot-instances.tf
│   │   ├── backup-lifecycle/
│   │   │   ├── main.tf              # Backup cost optimization
│   │   │   └── archival-policy.tf
│   │   └── cost-alerts/
│   │       ├── main.tf              # Budget alerts
│   │       └── anomaly-detection.tf
│   ├── environments/
│   │   ├── development/
│   │   ├── staging/
│   │   └── production/
│   └── budgets.tf
├── ansible/
│   ├── roles/
│   │   ├── cost-optimization/
│   │   │   ├── tasks/
│   │   │   │   ├── cleanup-resources.yml
│   │   │   │   ├── optimize-storage.yml
│   │   │   │   └── schedule-instances.yml
│   │   │   └── defaults/main.yml
│   │   ├── tagging/
│   │   └── compliance-checks/
│   ├── playbooks/
│   │   ├── daily-cost-cleanup.yml
│   │   ├── weekly-optimization.yml
│   │   ├── monthly-rightsizing.yml
│   │   └── cost-compliance-check.yml
│   └── inventory/
├── python-scripts/
│   ├── cost-analyzer.py
│   ├── ri-optimizer.py
│   ├── cleanup-orphaned-resources.py
│   └── budget-alerts.py
├── kubernetes/
│   ├── cost-monitor/
│   │   ├── prometheus-rules.yaml
│   │   └── kubecost-config.yaml
│   └── resource-quotas/
│       └── namespace-limits.yaml
├── monitoring/
│   ├── dashboards/
│   │   └── cost-dashboard.json
│   ├── alerts/
│   │   └── cost-alerts.yaml
│   └── queries/
│       └── cost-analysis-queries.sql
└── docs/
    ├── cost-allocation-model.md
    ├── chargeback-procedure.md
    ├── optimization-strategy.md
    └── budget-planning.md
```

## Core Concepts

### 1. Cost Optimization Pillars

```
┌─────────────────────────────────────────────────────────────┐
│         Cost Optimization Framework                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Right-Sizing          Automation          Reserved Cap.   │
│  ├─ CPU/Memory         ├─ Cleanup          ├─ RIs         │
│  ├─ Storage            ├─ Scheduling       ├─ Savings     │
│  └─ Network            └─ Policies         └─ Plans       │
│                                                             │
│  Intelligent Tiering   Governance          Monitoring      │
│  ├─ Lifecycle          ├─ Policies         ├─ Anomalies   │
│  ├─ Archival           ├─ Budgets          ├─ Trends      │
│  └─ Retention          └─ Chargeback       └─ Forecasts   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 2. Cost Reduction Potential by Category

```yaml
cost_reduction_opportunities:
  compute:
    description: "Instance optimization"
    potential_savings: "40-60%"
    methods:
      - "Spot instances instead of On-Demand"
      - "Reserved instances for baseline"
      - "Right-sizing oversized instances"
      - "Auto-scaling non-production environments"
    
  storage:
    description: "Storage and backup optimization"
    potential_savings: "30-50%"
    methods:
      - "Intelligent-Tiering for variable access"
      - "Archival for rarely accessed data"
      - "Lifecycle policies for old backups"
      - "De-duplication and compression"
    
  data_transfer:
    description: "Network cost optimization"
    potential_savings: "20-40%"
    methods:
      - "CloudFront for content delivery"
      - "VPC endpoints to avoid NAT"
      - "Same-region communication"
      - "Data compression"
    
  database:
    description: "Database optimization"
    potential_savings: "25-45%"
    methods:
      - "Aurora for RDS workloads"
      - "Multi-AZ only when needed"
      - "Database read replicas optimization"
      - "Automated backup lifecycle"
    
  unused_resources:
    description: "Cleanup of orphaned resources"
    potential_savings: "10-30%"
    methods:
      - "Automated orphan detection"
      - "Unattached volume cleanup"
      - "Unused snapshot removal"
      - "Idle instance termination"
```

### 3. Cost Allocation Model

```
┌─────────────────────────────────────────┐
│   Cost Allocation by Entity             │
├─────────────────────────────────────────┤
│                                         │
│  Cost Center / Department               │
│  ├─ Engineering                         │
│  ├─ Product                             │
│  ├─ Operations                          │
│  └─ Finance                             │
│                                         │
│  Project / Application                  │
│  ├─ Project-A                           │
│  ├─ Project-B                           │
│  └─ Shared Services                     │
│                                         │
│  Environment                            │
│  ├─ Production                          │
│  ├─ Staging                             │
│  └─ Development                         │
│                                         │
│  Resource Type                          │
│  ├─ Compute (EC2)                       │
│  ├─ Storage (S3)                        │
│  ├─ Database (RDS)                      │
│  └─ Network (ELB)                       │
│                                         │
└─────────────────────────────────────────┘
```

## Resource Tagging Strategy

### Terraform Tagging Module

```hcl
# modules/tagging/main.tf

locals {
  # Standard tags applied to all resources
  common_tags = {
    Environment      = var.environment
    CostCenter       = var.cost_center
    Project          = var.project_name
    Application      = var.application_name
    Owner            = var.owner_email
    Team             = var.team_name
    CreatedDate      = formatdate("YYYY-MM-DD", timestamp())
    CreatedBy        = var.created_by
    ManagedBy        = "Terraform"
    ChargebackModel  = var.chargeback_model  # "FixedAllocation", "Usage", "Hybrid"
    CostAllocation   = var.cost_allocation   # "Direct", "Shared"
    BackupPolicy     = var.backup_policy     # "Daily", "Weekly", "None"
    Criticality      = var.criticality       # "Critical", "High", "Medium", "Low"
    DataClassification = var.data_class      # "Public", "Internal", "Confidential", "Restricted"
  }
}

output "standard_tags" {
  value = local.common_tags
  description = "Standard tags for all resources"
}

# Apply to all resources
resource "aws_instance" "tagged" {
  tags = merge(
    local.common_tags,
    {
      Name = "${var.application_name}-${var.environment}"
      ScheduleShutdown = var.environment != "production" ? "true" : "false"
    }
  )
}

# Cost Center breakdown
variable "cost_center" {
  type = string
  description = "Cost center for chargeback"
  validation {
    condition     = contains(["engineering", "product", "operations", "finance", "shared"], lower(var.cost_center))
    error_message = "Valid cost centers: engineering, product, operations, finance, shared"
  }
}

# Environment-specific tags
variable "environment" {
  type = string
  validation {
    condition     = contains(["development", "staging", "production"], lower(var.environment))
    error_message = "Valid environments: development, staging, production"
  }
}
```

### Automated Tagging Compliance

```yaml
# Ansible: Tag compliance enforcement
---
- name: Enforce resource tagging compliance
  hosts: localhost
  gather_facts: no
  vars:
    required_tags:
      - Environment
      - CostCenter
      - Project
      - Owner
      - Application

  tasks:
    - name: Get all untagged resources
      ec2_instance_info:
        filters:
          instance-state-name: running
      register: all_instances

    - name: Check tag compliance
      set_fact:
        untagged_resources: "{{ all_instances.instances | selectattr('tags', 'undefined') | list }}"
        missing_tag_resources: []

    - name: Find resources with missing tags
      set_fact:
        missing_tag_resources: "{{ missing_tag_resources + [item] }}"
      when: >
        not item.tags or
        not item.tags.get('Environment') or
        not item.tags.get('CostCenter') or
        not item.tags.get('Owner')
      loop: "{{ all_instances.instances }}"

    - name: Alert on non-compliant resources
      debug:
        msg: |
          ⚠️ Cost Allocation Alert: Non-compliant tags found
          
          Untagged Resources: {{ untagged_resources | length }}
          Missing Required Tags: {{ missing_tag_resources | length }}
          
          Untagged Instance IDs:
          {% for instance in untagged_resources %}
            - {{ instance.instance_id }}
          {% endfor %}
          
          Will be terminated in 7 days if tags not added
      when: untagged_resources | length > 0 or missing_tag_resources | length > 0

    - name: Tag resources with defaults if missing
      ec2_tag:
        resource: "{{ item.instance_id }}"
        state: present
        tags:
          AutoTagged: "true"
          AutoTagDate: "{{ ansible_date_time.iso8601 }}"
          TaggingAlert: "Please update with correct values"
      loop: "{{ missing_tag_resources }}"
      when: auto_tag_compliance | default(false)

    - name: Send compliance report
      sns:
        msg: |
          Resource Tagging Compliance Report
          
          Total Instances: {{ all_instances.instances | length }}
          Compliant: {{ (all_instances.instances | length) - (missing_tag_resources | length) }}
          Non-Compliant: {{ missing_tag_resources | length }}
          Compliance Rate: {{ ((all_instances.instances | length - missing_tag_resources | length) / all_instances.instances | length * 100) | round(1) }}%
        subject: "Daily Tagging Compliance Report"
        topic_arn: "{{ sns_topic_arn }}"
```

## Cost Allocation & Chargeback

### Cost Allocation Model

```yaml
# Cost allocation strategy by environment
---
cost_allocation_models:
  development:
    allocation_method: "shared_pool"
    cost_split: "equal_distribution"
    chargeback_frequency: "monthly"
    owner_responsibility: "false"
    notes: "Shared development resources charged equally to all teams"
    
  staging:
    allocation_method: "project_based"
    cost_split: "proportional_to_resources"
    chargeback_frequency: "monthly"
    owner_responsibility: "true"
    notes: "Each project charged for their staging environment"
    
  production:
    allocation_method: "direct_allocation"
    cost_split: "direct_100_percent"
    chargeback_frequency: "weekly"
    owner_responsibility: "true"
    notes: "Production costs charged directly to project owner"
    escalation:
      - threshold: "150%"
        action: "alert_owner"
        frequency: "daily"
      - threshold: "200%"
        action: "alert_owner_and_finance"
        frequency: "daily"
      - threshold: "250%"
        action: "alert_owner_finance_cto"
        frequency: "daily"

# Chargeback calculation
chargeback_calculation:
  formula: |
    Total Cost = 
      (Compute Cost × Resource Count) +
      (Storage Cost × Storage Size) +
      (Data Transfer Cost × GB Transferred) +
      (Database Cost × Instance Hours) +
      (Shared Infrastructure × Allocation %)
  
  example:
    project_a_production:
      compute: "150 instances × $0.096/hour = $14,400/month"
      storage: "2TB × $0.023/GB = $46/month"
      data_transfer: "50GB × $0.09/GB = $4.50/month"
      database: "1 RDS instance × $0.70/hour = $504/month"
      shared_infrastructure: "$50,000 × 15% = $7,500/month"
      total_monthly: "$22,454.50"
      daily_rate: "$748.48"
```

### Chargeback Reporting

```python
# cost-analyzer.py
import boto3
import pandas as pd
from datetime import datetime, timedelta

class CostAnalyzer:
    def __init__(self):
        self.ce_client = boto3.client('ce')
        self.s3_client = boto3.client('s3')
        
    def get_costs_by_tag(self, tag_key, days=30):
        """Get costs grouped by tag value"""
        response = self.ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d'),
                'End': datetime.now().strftime('%Y-%m-%d')
            },
            Granularity='DAILY',
            Metrics=['UnblendedCost'],
            GroupBy=[
                {'Type': 'TAG', 'Key': tag_key}
            ],
            Filter={
                'Dimensions': {'Key': 'PURCHASE_TYPE', 'Values': ['On Demand']}
            }
        )
        return response
    
    def get_costs_by_service(self, days=30):
        """Get costs by AWS service"""
        response = self.ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d'),
                'End': datetime.now().strftime('%Y-%m-%d')
            },
            Granularity='DAILY',
            Metrics=['UnblendedCost'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'SERVICE'}
            ]
        )
        return response
    
    def generate_chargeback_report(self, days=30):
        """Generate monthly chargeback report"""
        costs_by_project = self.get_costs_by_tag('Project', days)
        costs_by_costcenter = self.get_costs_by_tag('CostCenter', days)
        costs_by_service = self.get_cost_by_service(days)
        
        report = {
            'report_date': datetime.now().isoformat(),
            'period_days': days,
            'costs_by_project': self._parse_response(costs_by_project),
            'costs_by_costcenter': self._parse_response(costs_by_costcenter),
            'costs_by_service': self._parse_response(costs_by_service),
        }
        
        # Save to S3
        self._save_report_to_s3(report)
        
        # Send email
        self._send_email_report(report)
        
        return report
    
    def _parse_response(self, response):
        """Parse Cost Explorer response"""
        data = []
        for result in response['ResultsByTime']:
            for group in result['Groups']:
                data.append({
                    'entity': group['Keys'][0],
                    'cost': float(group['Metrics']['UnblendedCost']['Amount'])
                })
        
        df = pd.DataFrame(data)
        return df.groupby('entity')['cost'].sum().to_dict()
    
    def _save_report_to_s3(self, report):
        """Save report to S3 for archival"""
        key = f"cost-reports/{datetime.now().strftime('%Y/%m/%d')}/chargeback.json"
        self.s3_client.put_object(
            Bucket='cost-reports-bucket',
            Key=key,
            Body=json.dumps(report),
            ContentType='application/json'
        )
    
    def _send_email_report(self, report):
        """Send report via SNS"""
        sns = boto3.client('sns')
        
        summary = self._format_summary(report)
        
        sns.publish(
            TopicArn='arn:aws:sns:us-east-1:123456789:cost-reports',
            Subject=f"Monthly Chargeback Report - {datetime.now().strftime('%B %Y')}",
            Message=summary
        )
    
    def _format_summary(self, report):
        """Format report for email"""
        return f"""
        Monthly Chargeback Report
        ========================
        
        Report Date: {report['report_date']}
        Period: {report['period_days']} days
        
        Costs by Project:
        {self._format_dict(report['costs_by_project'])}
        
        Costs by Cost Center:
        {self._format_dict(report['costs_by_costcenter'])}
        
        Costs by Service:
        {self._format_dict(report['costs_by_service'])}
        """
```

## Automated Cost Optimization

### Spot Instance Automation

```hcl
# Terraform: Spot instance cost optimization
resource "aws_autoscaling_group" "cost_optimized" {
  name                = "${var.app_name}-asg"
  vpc_zone_identifier = var.private_subnet_ids
  
  # Mixed instances policy: 70% Spot, 30% On-Demand
  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 2
      on_demand_percentage_above_base_capacity = 30
      spot_allocation_strategy                 = "capacity-optimized"
    }
    
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.app.id
        version            = "$Latest"
      }
      
      # Multiple instance types for Spot flexibility
      override {
        instance_type     = "t3.large"
        weighted_capacity = "1"
      }
      
      override {
        instance_type     = "t3a.large"
        weighted_capacity = "1"
      }
      
      override {
        instance_type     = "m5.large"
        weighted_capacity = "1"
      }
    }
  }
  
  max_size         = 20
  min_size         = 2
  desired_capacity = 5
  
  # Termination policies
  termination_policies = ["OldestLaunchTemplate", "Default"]
}

# Cost savings: ~70% on compute cost
output "estimated_monthly_savings" {
  value = "On-demand cost: $5000/month → With Spot: $1500/month (70% savings)"
}
```

### Scheduled Instance Scaling

```yaml
# Ansible: Automated scheduling for non-production environments
---
- name: Configure cost-saving schedules
  hosts: localhost
  vars:
    dev_asg_name: "dev-app-asg"
    staging_asg_name: "staging-app-asg"

  tasks:
    # Development environment: Scale to 0 after 6 PM
    - name: Create dev scale-down schedule
      aws_autoscaling_schedule:
        scheduled_action_name: "dev-scale-down"
        autoscaling_group_name: "{{ dev_asg_name }}"
        desired_capacity: 0
        min_size: 0
        max_size: 0
        recurrence: "0 18 * * MON-FRI"  # 6 PM weekdays
        region: us-east-1
        
    # Development environment: Scale back up at 7 AM
    - name: Create dev scale-up schedule
      aws_autoscaling_schedule:
        scheduled_action_name: "dev-scale-up"
        autoscaling_group_name: "{{ dev_asg_name }}"
        desired_capacity: 2
        min_size: 1
        max_size: 5
        recurrence: "0 7 * * MON-FRI"   # 7 AM weekdays
        region: us-east-1
    
    # Staging: Reduced capacity after hours
    - name: Create staging scale-down schedule
      aws_autoscaling_schedule:
        scheduled_action_name: "staging-scale-down"
        autoscaling_group_name: "{{ staging_asg_name }}"
        desired_capacity: 1
        min_size: 1
        max_size: 2
        recurrence: "0 20 * * *"        # 8 PM daily
        region: us-east-1
    
    # Cost impact calculation
    - name: Calculate cost savings
      debug:
        msg: |
          Cost Savings Analysis:
          =====================
          
          Dev Environment Savings:
          - Daily shutdown: 6 PM - 7 AM (13 hours)
          - Weekdays only: 5 days/week
          - Instance type: t3.medium ($0.0416/hour)
          - Instances: 2
          - Monthly savings: $0.0416 × 2 × 13 × 22 = $23.65
          
          Staging Environment Savings:
          - Reduced capacity: 8 PM - 7 AM (11 hours)
          - Daily
          - Instance scaling: 5 → 1 (removing 4 instances)
          - Instance type: t3.large ($0.0832/hour)
          - Monthly savings: $0.0832 × 4 × 11 × 30 = $109.63
          
          Total Monthly Savings: $133.28
          Annual Savings: $1,599.36
```

### Automated Cleanup of Orphaned Resources

```python
# cleanup-orphaned-resources.py
import boto3
import json
from datetime import datetime, timedelta

class ResourceCleanup:
    def __init__(self):
        self.ec2 = boto3.resource('ec2')
        self.elb = boto3.client('elbv2')
        self.sns = boto3.client('sns')
        
    def cleanup_unattached_volumes(self, older_than_days=7):
        """Remove unattached EBS volumes older than X days"""
        volumes_to_delete = []
        
        for volume in self.ec2.volumes.all():
            # Check if unattached
            if volume.state == 'available':
                # Check age
                created_time = volume.create_time
                age_days = (datetime.now(created_time.tzinfo) - created_time).days
                
                if age_days > older_than_days:
                    # Get volume metadata
                    cost_monthly = self._calculate_volume_cost(volume.size)
                    
                    volumes_to_delete.append({
                        'volume_id': volume.id,
                        'size_gb': volume.size,
                        'age_days': age_days,
                        'monthly_cost': cost_monthly,
                        'yearly_cost': cost_monthly * 12,
                    })
        
        return volumes_to_delete
    
    def cleanup_unused_snapshots(self, older_than_days=30):
        """Remove snapshots with no associated volumes"""
        orphaned_snapshots = []
        
        for snapshot in self.ec2.snapshots.filter(OwnerIds=['self']):
            created_time = snapshot.start_time
            age_days = (datetime.now(created_time.tzinfo) - created_time).days
            
            # Check if volume still exists
            volume_exists = len(list(self.ec2.volumes.filter(
                Filters=[{'Name': 'snapshot-id', 'Values': [snapshot.id]}]
            ))) > 0
            
            if not volume_exists and age_days > older_than_days:
                cost_monthly = self._calculate_snapshot_cost(snapshot.volume_size)
                
                orphaned_snapshots.append({
                    'snapshot_id': snapshot.id,
                    'volume_size_gb': snapshot.volume_size,
                    'age_days': age_days,
                    'monthly_cost': cost_monthly,
                    'yearly_cost': cost_monthly * 12,
                })
        
        return orphaned_snapshots
    
    def cleanup_unused_eips(self):
        """Remove Elastic IPs not associated with instances"""
        unused_eips = []
        
        for address in self.ec2.meta.client.describe_addresses()['Addresses']:
            if 'InstanceId' not in address or not address['InstanceId']:
                unused_eips.append({
                    'allocation_id': address['AllocationId'],
                    'public_ip': address['PublicIp'],
                    'monthly_cost': 0.0,  # EIP unused costs money
                })
        
        return unused_eips
    
    def cleanup_unused_load_balancers(self):
        """Remove load balancers with no targets"""
        unused_lbs = []
        
        response = self.elb.describe_load_balancers()
        
        for lb in response['LoadBalancers']:
            # Get target health
            targets = self.elb.describe_target_health(
                TargetGroupArn=lb['LoadBalancerArn']
            )
            
            if not targets['TargetHealthDescriptions']:
                unused_lbs.append({
                    'lb_arn': lb['LoadBalancerArn'],
                    'lb_name': lb['LoadBalancerName'],
                    'monthly_cost': 16.20,  # ALB cost
                    'yearly_cost': 194.40,
                })
        
        return unused_lbs
    
    def _calculate_volume_cost(self, size_gb):
        """Calculate EBS volume cost"""
        return size_gb * 0.10  # $0.10/GB-month for gp3
    
    def _calculate_snapshot_cost(self, size_gb):
        """Calculate snapshot storage cost"""
        return size_gb * 0.023  # $0.023/GB-month for S3
    
    def execute_cleanup(self, dry_run=True):
        """Execute cleanup operations"""
        orphaned_volumes = self.cleanup_unattached_volumes()
        orphaned_snapshots = self.cleanup_unused_snapshots()
        unused_eips = self.cleanup_unused_eips()
        unused_lbs = self.cleanup_unused_load_balancers()
        
        total_monthly_savings = sum([
            item['monthly_cost'] for item in orphaned_volumes +
            orphaned_snapshots + unused_eips + unused_lbs
        ])
        
        cleanup_report = {
            'timestamp': datetime.now().isoformat(),
            'dry_run': dry_run,
            'orphaned_volumes': orphaned_volumes,
            'orphaned_snapshots': orphaned_snapshots,
            'unused_eips': unused_eips,
            'unused_load_balancers': unused_lbs,
            'total_monthly_savings': total_monthly_savings,
            'total_annual_savings': total_monthly_savings * 12,
        }
        
        if not dry_run:
            # Execute actual cleanup
            for volume in orphaned_volumes:
                self._delete_volume(volume['volume_id'])
            
            for snapshot in orphaned_snapshots:
                self._delete_snapshot(snapshot['snapshot_id'])
            
            for eip in unused_eips:
                self._release_eip(eip['allocation_id'])
        
        # Send report
        self._send_cleanup_report(cleanup_report)
        
        return cleanup_report
    
    def _send_cleanup_report(self, report):
        """Send cleanup report via SNS"""
        message = f"""
        Cost Optimization Cleanup Report
        ================================
        
        Timestamp: {report['timestamp']}
        Dry Run: {report['dry_run']}
        
        Orphaned EBS Volumes: {len(report['orphaned_volumes'])}
        Orphaned Snapshots: {len(report['orphaned_snapshots'])}
        Unused EIPs: {len(report['unused_eips'])}
        Unused Load Balancers: {len(report['unused_load_balancers'])}
        
        Monthly Savings Potential: ${report['total_monthly_savings']:.2f}
        Annual Savings Potential: ${report['total_annual_savings']:.2f}
        
        Details:
        {json.dumps(report, indent=2, default=str)}
        """
        
        self.sns.publish(
            TopicArn='arn:aws:sns:us-east-1:123456789:cost-optimization',
            Subject='Cost Optimization Cleanup Report',
            Message=message
        )
```

## Reserved Instances & Savings Plans

### Reserved Instance Optimization

```python
# ri-optimizer.py
import boto3
from datetime import datetime, timedelta

class RIPricingOptimizer:
    def __init__(self):
        self.ce_client = boto3.client('ce')
        self.ec2_client = boto3.client('ec2')
        self.pricing_client = boto3.client('pricing')
        
    def analyze_ri_opportunity(self, days=90):
        """Analyze opportunities for Reserved Instances"""
        # Get on-demand usage patterns
        response = self.ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d'),
                'End': datetime.now().strftime('%Y-%m-%d')
            },
            Granularity='MONTHLY',
            Metrics=['UnblendedCost', 'UsageQuantity'],
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'INSTANCE_TYPE'},
                {'Type': 'DIMENSION', 'Key': 'REGION'},
            ],
            Filter={
                'Dimensions': {
                    'Key': 'PURCHASE_TYPE',
                    'Values': ['On Demand']
                }
            }
        )
        
        ri_opportunities = []
        
        for result in response['ResultsByTime']:
            for group in result['Groups']:
                instance_type = group['Keys'][0]
                region = group['Keys'][1]
                usage_quantity = float(group['Metrics']['UsageQuantity']['Amount'])
                cost = float(group['Metrics']['UnblendedCost']['Amount'])
                
                # Check if this is consistent usage (good candidate for RI)
                if usage_quantity > 730:  # > 1 instance-month equivalent
                    ri_pricing = self._get_ri_pricing(instance_type, region)
                    
                    if ri_pricing:
                        monthly_savings = cost - ri_pricing
                        annual_savings = monthly_savings * 12
                        
                        ri_opportunities.append({
                            'instance_type': instance_type,
                            'region': region,
                            'current_monthly_cost': cost,
                            'ri_monthly_cost': ri_pricing,
                            'monthly_savings': monthly_savings,
                            'annual_savings': annual_savings,
                            'payback_months': 12,  # Most RIs are 1-year
                            'usage_quantity': usage_quantity,
                        })
        
        return sorted(ri_opportunities, key=lambda x: x['annual_savings'], reverse=True)
    
    def _get_ri_pricing(self, instance_type, region):
        """Get 1-year Reserved Instance pricing"""
        # Simplified - in production, query pricing API
        ri_prices = {
            't3.medium': 0.025,
            't3.large': 0.050,
            'm5.large': 0.070,
            'm5.xlarge': 0.140,
        }
        return ri_prices.get(instance_type, None)
    
    def get_existing_ri_utilization(self):
        """Get current RI utilization metrics"""
        # Query AWS Cost Explorer for RI coverage and utilization
        response = self.ce_client.get_reservation_utilization(
            TimePeriod={
                'Start': datetime.now().strftime('%Y-%m-01'),
                'End': datetime.now().strftime('%Y-%m-%d')
            },
            Granularity='MONTHLY',
            GroupBy=[
                {'Type': 'DIMENSION', 'Key': 'SERVICE'},
            ]
        )
        
        utilization_data = []
        for group in response['UtilizationsByTime']:
            for item in group['Groups']:
                utilization_data.append({
                    'service': item['Keys'][0],
                    'total_commitment': float(item['Metrics']['ReservedUnitHours']['Total']),
                    'used_commitment': float(item['Metrics']['ReservedUnitHours']['Used']),
                    'unused_commitment': float(item['Metrics']['ReservedUnitHours']['Unused']),
                    'utilization_percentage': float(item['Metrics']['UtilizationPercentage']['Value']),
                })
        
        return utilization_data
```

## Instance Right-Sizing

### Automatic Right-Sizing Analysis

```yaml
# Ansible: Right-sizing based on CloudWatch metrics
---
- name: Analyze instances for right-sizing opportunities
  hosts: localhost
  gather_facts: no
  vars:
    cpu_threshold: 20  # If avg CPU < 20%, downsize candidate
    memory_threshold: 30

  tasks:
    - name: Get CloudWatch metrics for all instances
      cloudwatch_metric_statistics:
        namespace: AWS/EC2
        metric_name: CPUUtilization
        dimensions: { InstanceId: "{{ item }}" }
        start_time: "{{ (now - timedelta(days=30)).strftime('%Y-%m-%dT%H:%M:%S') }}"
        end_time: "{{ now.strftime('%Y-%m-%dT%H:%M:%S') }}"
        period: 3600
        statistics:
          - Average
      loop: "{{ instance_ids }}"
      register: cpu_metrics

    - name: Identify undersized instances
      set_fact:
        rightsizing_candidates: []

    - name: Analyze for right-sizing
      set_fact:
        rightsizing_candidates: "{{ rightsizing_candidates + [item.item] }}"
      when: |
        item.cpu_utilization_avg | float < cpu_threshold
      loop: "{{ cpu_metrics.results }}"

    - name: Generate right-sizing recommendations
      debug:
        msg: |
          Right-Sizing Recommendations
          ============================
          
          Instances with low CPU utilization (< {{ cpu_threshold }}%):
          {% for instance in rightsizing_candidates %}
          - {{ instance }}: Consider downsize to smaller instance type
          {% endfor %}
          
          Estimated Savings:
          - Current: t3.xlarge ($0.1664/hour)
          - Recommended: t3.large ($0.0832/hour)
          - Monthly Savings: ~$320/month per instance
```

## Storage Optimization

### S3 Lifecycle Management

```hcl
# Terraform: S3 lifecycle policies for cost optimization
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id
  
  rule {
    id     = "intelligent-tiering"
    status = "Enabled"
    
    # Move to Intelligent-Tiering after 0 days
    transition {
      storage_class = "INTELLIGENT_TIERING"
      days          = 0
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id
  
  rule {
    id     = "log-archival"
    status = "Enabled"
    
    # Move to Standard-IA after 30 days (saves ~50%)
    transition {
      storage_class = "STANDARD_IA"
      days          = 30
    }
    
    # Move to Glacier after 90 days (saves ~80%)
    transition {
      storage_class = "GLACIER"
      days          = 90
    }
    
    # Delete after 365 days
    expiration {
      days = 365
    }
  }
}

# Cost comparison
output "cost_savings" {
  value = <<-EOT
    Storage Cost Optimization:
    
    Without Lifecycle Policies:
    - 1TB stored in Standard: $23/month
    - 1TB stored in Standard-IA: $12.50/month
    - 1TB stored in Glacier: $4/month
    
    With Lifecycle (from example):
    - Days 0-30: $23 (Standard)
    - Days 31-90: $6.25 (Standard-IA - 30 days)
    - Days 91-365: $0.88 (Glacier - 275 days)
    - Total annual cost: $88 instead of $276
    
    Annual Savings: $188 per TB (68% reduction)
  EOT
}
```

## Monitoring & Alerting

### Cost Anomaly Detection

```yaml
# Prometheus alert rules for cost anomalies
groups:
- name: cost_anomalies
  interval: 1h
  rules:
    - alert: DailyCostAnomalyDetected
      expr: |
        (daily_cost - avg_over_time(daily_cost[30d])) > (stddev_over_time(daily_cost[30d]) * 2)
      for: 1h
      labels:
        severity: warning
        team: platform
      annotations:
        summary: "Cost spike detected: {{ $value | humanize }}% above average"
        
    - alert: ServiceCostSpikeDetected
      expr: |
        (service_cost - avg_over_time(service_cost[7d])) / avg_over_time(service_cost[7d]) > 0.5
      for: 2h
      labels:
        severity: critical
      annotations:
        summary: "{{ $labels.service }} cost increased by {{ $value | humanizePercentage }}"
        
    - alert: UnusedResourcesDetected
      expr: |
        unused_resources_count > 0
      for: 3d
      labels:
        severity: info
      annotations:
        summary: "{{ $value }} unused resources detected, potential savings: {{ $labels.potential_savings }}"
```

## Cost Governance

### Budget and Policy Enforcement

```hcl
# Terraform: Budget alerts and guardrails
resource "aws_budgets_budget" "monthly_limit" {
  name              = "monthly-cost-budget"
  budget_type       = "COST"
  limit_amount      = "50000"
  limit_unit        = "USD"
  time_period_start = "2025-01-01_00:00:00Z"
  time_period_end   = "2087-12-31_23:59:59Z"
  time_unit         = "MONTHLY"

  cost_filters = {
    TagKeyValue = ["Environment\$production"]
  }
}

resource "aws_budgets_budget_action" "cost_control" {
  account_id              = data.aws_caller_identity.current.account_id
  action_id               = aws_budgets_budget.monthly_limit.id
  budget_name             = aws_budgets_budget.monthly_limit.name
  notification_type       = "FORECASTED"
  action_type             = "APPLY_IAM_POLICY"
  execution_role_arn      = aws_iam_role.budget_action.arn
  action_threshold        = "150"
  action_threshold_type   = "PERCENTAGE"
}

# Cost control policy
resource "aws_iam_policy" "cost_control" {
  name        = "cost-control-policy"
  description = "Prevent costly operations during budget overspend"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Deny"
        Action = [
          "ec2:RunInstances",
          "rds:CreateDBInstance",
          "rds:ModifyDBInstance"
        ]
        Resource = "*"
        Condition = {
          StringLike = {
            "aws:RequestedRegion" = [
              "us-east-2",
              "ap-southeast-1"  # High-cost regions
            ]
          }
        }
      }
    ]
  })
}
```

---

## Best Practices Summary

✅ **Do:**
- Tag all resources consistently for cost allocation
- Use Spot instances for non-critical workloads (70% savings)
- Implement automated cleanup for orphaned resources
- Schedule non-production environments shutdown
- Use Reserved Instances for predictable baseline capacity
- Monitor costs daily, not just monthly
- Implement cost governance policies
- Archive old backups to Glacier (80% savings)
- Use S3 Intelligent-Tiering for variable access patterns
- Regular right-sizing analysis based on metrics
- Track cost metrics in monitoring dashboards
- Include cost in architecture decisions

❌ **Don't:**
- Leave resources running without cost allocation tags
- Assume on-demand is always required
- Skip backup lifecycle management
- Deploy in expensive regions without justification
- Leave unused resources (orphaned volumes, snapshots)
- Create load balancers without targets
- Run development environments 24/7
- Skip RI utilization monitoring
- Ignore cost anomalies
- Mix cloud resources with on-premises without optimization
- Store all data in expensive storage classes
- Skip data transfer optimization

---

**Note**: This guide is current as of December 2025 and supports:
- AWS Cost Explorer & Budgets API
- Terraform 1.14+
- Ansible 2.20+
- Python 3.8+
- Boto3 for AWS automation
- Typical cost reductions: 40-60% compute, 30-50% storage

For the latest updates and community contributions, refer to the [Enterprise Automation Handbook](https://github.com/diceone/Enterprise-Automation-Handbook).
