# Infrastructure Patterns & Architecture

Comprehensive guide for modern infrastructure architecture patterns, covering microservices, serverless, event-driven systems, service mesh, and architectural decision-making for enterprise applications.

## Table of Contents

1. [Architectural Patterns](#architectural-patterns)
2. [Microservices Architecture](#microservices-architecture)
3. [Monolithic Architecture](#monolithic-architecture)
4. [Serverless Architecture](#serverless-architecture)
5. [Event-Driven Architecture](#event-driven-architecture)
6. [Service Mesh](#service-mesh)
7. [CQRS and Event Sourcing](#cqrs-and-event-sourcing)
8. [API-First Architecture](#api-first-architecture)
9. [Architecture Decision Records](#architecture-decision-records)
10. [Architectural Tradeoffs](#architectural-tradeoffs)

---

## Architectural Patterns

### Pattern Selection Decision Matrix

```
                        Monolith    Microservices    Serverless    Event-Driven
┌─────────────────────────────────────────────────────────────────────────────┐
│ Complexity              Low         High            Medium         High       │
│ Scalability            Limited    Excellent        Excellent      Excellent  │
│ Operational Overhead    Low         High            Low            Medium     │
│ Time to Market         Fast        Slower          Fast           Medium     │
│ Team Size Req.         Small       Large           Small          Medium     │
│ Cost at Scale          High        Medium          Low            Medium     │
│ Learning Curve         Low         High            Medium         High       │
│ Deployment Frequency   Weekly      Multiple/day    On-demand      Continuous │
└─────────────────────────────────────────────────────────────────────────────┘

Best for:
  Monolith:        Simple apps, startups, <10 developers, CRUD operations
  Microservices:   Complex apps, large teams, independent scaling needs
  Serverless:      Event-driven workloads, variable load, cost-sensitive
  Event-Driven:    Real-time systems, temporal requirements, audit trails
```

---

## Microservices Architecture

### Microservices Principles

**❌ BAD - Monolithic to "Microservices":**
```
Copied monolith into containers, called it microservices

Problems:
- Tight coupling between services
- No independent deployment
- Shared database
- Synchronous RPC everywhere
- Still a monolith, just distributed
```

**✅ GOOD - True Microservices:**
```
Each service:
  ✓ Has single business responsibility
  ✓ Has own database
  ✓ Can be deployed independently
  ✓ Communicates via events/APIs
  ✓ Can be developed by separate teams
  ✓ Can use different tech stacks
```

### Microservices Architecture Pattern

```
┌─────────────────────────────────────────────────────────────────┐
│                        API Gateway                              │
│              (Routing, Auth, Rate Limiting)                     │
└───────────┬─────────────────────┬──────────────────┬────────────┘
            │                     │                  │
    ┌───────▼────────┐  ┌────────▼─────┐  ┌────────▼──────┐
    │  Order Service │  │ User Service  │  │ Payment       │
    │                │  │               │  │ Service       │
    │ Database: SQL  │  │ Database: SQL │  │ Database: SQL │
    └────┬───────────┘  └───────┬──────┘  └────┬──────────┘
         │                      │               │
         └──────────────────────┼───────────────┘
                      ┌─────────▼────────┐
                      │  Message Queue   │
                      │  (RabbitMQ/Kafka)│
                      └──────────────────┘
                      Events: OrderCreated
                              PaymentProcessed
                              UserRegistered
```

### Service Communication Patterns

**Synchronous Communication (REST/gRPC):**
```yaml
# Order Service calling User Service
- name: Create Order
  tasks:
    - name: Get user details
      uri:
        url: "http://user-service:8080/api/users/{{ user_id }}"
        method: GET
      register: user_response
      
    - name: Validate user
      assert:
        that:
          - user_response.json.status == 'active'
    
    - name: Create order
      uri:
        url: "http://order-service:8080/api/orders"
        method: POST
        body_format: json
        body:
          user_id: "{{ user_id }}"
          items: "{{ items }}"
      when: user_response.json.status == 'active'
```

**Asynchronous Communication (Events):**
```yaml
# Order Service publishes event
- name: Order Created Event
  tasks:
    - name: Create order
      database:
        query: "INSERT INTO orders VALUES (...)"
      register: order
    
    - name: Publish OrderCreated event
      rabbitmq:
        host: rabbitmq
        exchange: events
        routing_key: order.created
        body: |
          {
            "event_type": "OrderCreated",
            "order_id": "{{ order.id }}",
            "user_id": "{{ user_id }}",
            "timestamp": "{{ now(utc=True) }}"
          }

# Payment Service subscribes to event
- name: Payment Service Consumer
  tasks:
    - name: Listen for OrderCreated events
      rabbitmq_consumer:
        host: rabbitmq
        queue: payment_service_queue
        exchange: events
        routing_key: order.created
        callback: process_order_created
```

### Database per Service Pattern

```yaml
# Each service has own database (no shared database)
services:
  order_service:
    image: order-service:latest
    environment:
      DATABASE_URL: "postgresql://user:pass@order-db:5432/orders"
    depends_on:
      - order_db
  
  order_db:
    image: postgres:15
    environment:
      POSTGRES_DB: orders
      POSTGRES_USER: user
      POSTGRES_PASSWORD: secure_password
    volumes:
      - order_data:/var/lib/postgresql/data

  user_service:
    image: user-service:latest
    environment:
      DATABASE_URL: "postgresql://user:pass@user-db:5432/users"
    depends_on:
      - user_db
  
  user_db:
    image: postgres:15
    environment:
      POSTGRES_DB: users
      POSTGRES_USER: user
      POSTGRES_PASSWORD: secure_password
    volumes:
      - user_data:/var/lib/postgresql/data

  # Message broker for inter-service communication
  rabbitmq:
    image: rabbitmq:3.12-management

volumes:
  order_data:
  user_data:
```

### Service Discovery Pattern

```yaml
# Kubernetes Service Discovery (automatic)
apiVersion: v1
kind: Service
metadata:
  name: order-service
  namespace: default
spec:
  selector:
    app: order-service
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP

---
# Other services discover via DNS: order-service.default.svc.cluster.local
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-urls
data:
  ORDER_SERVICE_URL: "http://order-service.default.svc.cluster.local/api"
  USER_SERVICE_URL: "http://user-service.default.svc.cluster.local/api"
  PAYMENT_SERVICE_URL: "http://payment-service.default.svc.cluster.local/api"
```

---

## Monolithic Architecture

### When Monolithic Makes Sense

**✅ Good for:**
- Early-stage startups (MVP validation)
- Simple CRUD applications
- Small teams (< 10 people)
- Stable, predictable requirements
- Built by single team
- Low scaling needs

**❌ Problems at scale:**
```
Monolith Growth Issues:
- Deployment: 1 hour (entire app builds)
- Scaling: Scale everything (inefficient)
- Coupling: Change in one module affects all
- Testing: Full test suite runs on every change
- Team Velocity: Large teams step on each other
```

### Well-Structured Monolith

```
monolith/
├── api/                    # API layer
│   ├── middleware.py
│   ├── controllers.py
│   └── routes.py
├── business/               # Business logic
│   ├── order_service.py
│   ├── user_service.py
│   └── payment_service.py
├── persistence/            # Data access
│   ├── models.py
│   ├── repositories.py
│   └── migrations/
├── shared/                 # Shared utilities
│   ├── logging.py
│   ├── config.py
│   └── exceptions.py
└── tests/

Key principle: Even in monolith, maintain clear boundaries
              and could extract to microservices later
```

### Deployment

```yaml
# Docker: Single image for entire app
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000
CMD ["gunicorn", "--workers=4", "app:app"]

# Result: Single deployment artifact
# Pro: Simple to deploy, test, monitor
# Con: Can't scale individual components
```

---

## Serverless Architecture

### Serverless Principles

No infrastructure management:
- No servers to provision
- Auto-scaling built-in
- Pay-per-execution
- Event-driven execution
- Cold starts possible

### Serverless Architecture Pattern

```
┌──────────────────────────────────────────────────────────┐
│                    AWS Lambda                            │
│          (or Azure Functions, Google Cloud)              │
└─────────┬─────────────────────────────────────────┬──────┘
          │                                         │
    ┌─────▼──────┐                          ┌──────▼─────┐
    │   S3 Event │ → Process Image          │  API Call  │
    │   Trigger  │   (Resize, Thumbnails)  │  Trigger   │
    └────────────┘                          └────────────┘
          │                                       │
    ┌─────▼──────────────┐                ┌──────▼────────┐
    │   DynamoDB Table   │                │  Return JSON   │
    │   (Store metadata) │                │  (REST API)    │
    └────────────────────┘                └────────────────┘

Triggers:
  - S3 Events
  - API Gateway
  - DynamoDB Streams
  - SNS/SQS Messages
  - CloudWatch Events
  - Direct Invocation
```

### AWS Lambda Example

```python
# lambda_function.py
import json
import boto3
import logging
from datetime import datetime

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    """
    Process S3 image uploads
    Triggered by: S3:ObjectCreated:Put
    """
    
    try:
        # Parse S3 event
        bucket = event['Records'][0]['s3']['bucket']['name']
        key = event['Records'][0]['s3']['object']['key']
        
        logger.info(f"Processing {bucket}/{key}")
        
        # Get object metadata
        response = s3_client.head_object(Bucket=bucket, Key=key)
        size = response['ContentLength']
        
        # Store metadata in DynamoDB
        table = dynamodb.Table('image_metadata')
        table.put_item(
            Item={
                'image_id': key,
                'bucket': bucket,
                'size_bytes': size,
                'uploaded_at': datetime.now().isoformat(),
                'status': 'processed'
            }
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps('Image processed successfully')
        }
        
    except Exception as e:
        logger.error(f"Error processing image: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }
```

### Serverless Trade-offs

**✅ Advantages:**
- Zero infrastructure management
- Auto-scaling
- Pay only for execution
- High availability built-in
- Easy to scale spiky workloads

**❌ Disadvantages:**
- Cold start latency (100-1000ms)
- Limited execution time (usually 15 minutes)
- Stateless (can't maintain connections)
- Vendor lock-in
- Harder to test locally
- Not good for long-running tasks

---

## Event-Driven Architecture

### Event-Driven Patterns

**Event Notification:**
```
Service A does something → Publishes event → Service B reacts

Example:
Order Service creates order → Publishes "OrderCreated" event
                           ↓
Payment Service (subscribes) → Processes payment
Inventory Service (subscribes) → Reduces stock
Email Service (subscribes) → Sends confirmation
```

**Event Sourcing:**
```
Instead of storing current state, store all state changes

Traditional:
├── User table: { id: 1, email: "john@example.com", status: "active" }
└── Update: Change email in-place (lose history)

Event Sourcing:
├── User Created: { user_id: 1, email: "john@example.com" }
├── Email Changed: { user_id: 1, new_email: "jane@example.com" }
├── Activated: { user_id: 1 }
├── Deactivated: { user_id: 1 }
└── Can replay events to get state at any point in time
```

### Implementation Example

```yaml
# Event Store (append-only log)
- event_id: 1
  event_type: UserCreated
  user_id: 123
  data: { email: "john@example.com" }
  timestamp: 2025-01-01T10:00:00Z

- event_id: 2
  event_type: UserEmailChanged
  user_id: 123
  data: { new_email: "jane@example.com" }
  timestamp: 2025-01-01T11:00:00Z

- event_id: 3
  event_type: UserActivated
  user_id: 123
  timestamp: 2025-01-01T11:30:00Z

# Kafka configuration for event streaming
kafka_topics:
  user_events:
    partitions: 3
    replication_factor: 3
    retention_ms: 604800000  # 7 days
    
  order_events:
    partitions: 3
    replication_factor: 3
    retention_ms: 604800000
    
  payment_events:
    partitions: 3
    replication_factor: 3
    retention_ms: 604800000
```

### Kafka-based Event System

```yaml
# docker-compose.yml
version: '3.9'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181

  kafka:
    image: confluentinc/cp-kafka:7.5.0
    depends_on:
      - zookeeper
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
    ports:
      - "9092:9092"

  # Event producer
  order_producer:
    image: order-service:latest
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      KAFKA_TOPIC: order_events
    depends_on:
      - kafka

  # Event consumer
  payment_consumer:
    image: payment-service:latest
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      KAFKA_CONSUMER_GROUP: payment-service
      KAFKA_TOPIC: order_events
    depends_on:
      - kafka

  # Event consumer
  inventory_consumer:
    image: inventory-service:latest
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:9092
      KAFKA_CONSUMER_GROUP: inventory-service
      KAFKA_TOPIC: order_events
    depends_on:
      - kafka
```

---

## Service Mesh

### Service Mesh Purpose

Service mesh provides cross-cutting concerns without modifying application code:
- Traffic management
- Security (mTLS)
- Observability
- Resilience patterns

### Service Mesh Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   Control Plane (Istio)                 │
│              (Pilot, Citadel, Mixer, Galley)            │
└─────────────────────────────────────────────────────────┘
         │              │              │
    ┌────▼───┐  ┌───────▼──┐  ┌──────▼────┐
    │ Envoy  │  │  Envoy   │  │  Envoy    │
    │ Proxy  │  │  Proxy   │  │  Proxy    │
    └────┬───┘  └────┬─────┘  └──────┬────┘
         │           │               │
    ┌────▼─┐   ┌─────▼────┐   ┌──────▼──┐
    │ App1 │   │  App2    │   │  App3   │
    └──────┘   └──────────┘   └─────────┘

Envoy sidecars intercept all traffic
Control plane provides policies and configuration
```

### Istio Virtual Service Example

```yaml
# VirtualService: Route requests based on rules
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: order-service
spec:
  hosts:
  - order-service
  http:
  # Route 90% to v1, 10% to v2 (canary)
  - match:
    - uri:
        prefix: /api
    route:
    - destination:
        host: order-service
        subset: v1
      weight: 90
    - destination:
        host: order-service
        subset: v2
      weight: 10
    timeout: 30s
    retries:
      attempts: 3
      perTryTimeout: 10s

---
# DestinationRule: Define subsets and connection policies
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: order-service
spec:
  host: order-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 100
        maxRequestsPerConnection: 2
    loadBalancer:
      simple: ROUND_ROBIN
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2

---
# PeerAuthentication: Enable mTLS
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
spec:
  mtls:
    mode: STRICT  # Require mTLS for all traffic
```

---

## CQRS and Event Sourcing

### CQRS Pattern

Command Query Responsibility Segregation - separate read and write models

```
Write Model (Commands):        Read Model (Queries):
CreateOrder                    GetOrderById
UpdateOrderStatus              ListUserOrders
CancelOrder                    GetOrdersForShipping

                ↓ Events ↓
           (OrderCreated, OrderUpdated,
            OrderShipped, OrderCancelled)

Write to Event Store            Read from Optimized Views
Process Commands                Query Denormalized Data
Update Write Model              Fast reads, optimized for queries
```

### CQRS Implementation

```python
# commands.py - Write side
class CreateOrderCommand:
    def __init__(self, user_id: str, items: list):
        self.user_id = user_id
        self.items = items
        self.order_id = str(uuid.uuid4())
        self.timestamp = datetime.now()

class OrderCommandHandler:
    def __init__(self, event_store, event_bus):
        self.event_store = event_store
        self.event_bus = event_bus
    
    def handle_create_order(self, command: CreateOrderCommand):
        # Validate
        if not command.items:
            raise ValueError("Order must have items")
        
        # Create event
        event = OrderCreatedEvent(
            order_id=command.order_id,
            user_id=command.user_id,
            items=command.items,
            created_at=command.timestamp
        )
        
        # Store event
        self.event_store.append(event)
        
        # Publish event
        self.event_bus.publish(event)
        
        return command.order_id

# queries.py - Read side
class OrderQueryHandler:
    def __init__(self, read_db):
        self.read_db = read_db
    
    def get_order_by_id(self, order_id: str):
        # Query optimized read model
        return self.read_db.query(
            "SELECT * FROM orders_read_model WHERE order_id = ?",
            (order_id,)
        )
    
    def list_user_orders(self, user_id: str):
        # Query optimized read model
        return self.read_db.query(
            "SELECT * FROM user_orders_read_model WHERE user_id = ?",
            (user_id,)
        )

# event_handler.py - Maintains read model
class OrderEventHandler:
    def __init__(self, read_db):
        self.read_db = read_db
    
    def on_order_created(self, event: OrderCreatedEvent):
        # Update read model
        self.read_db.insert('orders_read_model', {
            'order_id': event.order_id,
            'user_id': event.user_id,
            'status': 'created',
            'created_at': event.created_at,
            'items': event.items
        })
```

---

## API-First Architecture

### API-First Principles

Design APIs first, implement services second.

**Benefits:**
- Frontend and backend can develop in parallel
- Clear contracts between services
- API documentation as single source of truth
- Version control for APIs
- Mock servers for testing

### OpenAPI Specification

```yaml
# openapi.yaml
openapi: 3.0.0
info:
  title: Order Service API
  version: 1.0.0

servers:
  - url: https://api.example.com/orders

paths:
  /orders:
    post:
      summary: Create new order
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateOrderRequest'
      responses:
        '201':
          description: Order created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Order'
        '400':
          description: Invalid request
        '401':
          description: Unauthorized

    get:
      summary: List user orders
      parameters:
        - name: user_id
          in: query
          required: true
          schema:
            type: string
      responses:
        '200':
          description: List of orders
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: '#/components/schemas/Order'

components:
  schemas:
    CreateOrderRequest:
      type: object
      required:
        - user_id
        - items
      properties:
        user_id:
          type: string
        items:
          type: array
          items:
            type: object
            properties:
              product_id:
                type: string
              quantity:
                type: integer

    Order:
      type: object
      properties:
        order_id:
          type: string
        user_id:
          type: string
        status:
          type: string
          enum: [created, pending, shipped, delivered]
        created_at:
          type: string
          format: date-time
        items:
          type: array
```

### Generated Code from OpenAPI

```bash
# Generate Python client from OpenAPI spec
openapi-generator generate \
  -i openapi.yaml \
  -g python \
  -o generated-client

# Generated client can be used immediately
from openapi_client import OrderServiceApi

api = OrderServiceApi()
order = api.create_order(user_id="123", items=[...])
```

---

## Architecture Decision Records

### ADR Format

```markdown
# ADR-001: Microservices vs Monolith

## Status
Accepted

## Context
Our application is growing rapidly with features like orders, payments, inventory.
Different teams need to work independently.

## Decision
We will adopt microservices architecture with the following services:
- OrderService
- PaymentService
- InventoryService
- UserService

## Consequences
Positive:
- Independent scaling
- Team autonomy
- Technology flexibility
- Deployment frequency increases

Negative:
- Operational complexity
- Network latency
- Distributed tracing required
- Need for service mesh

## Alternatives Considered
1. Modular monolith (rejected: team coupling issues)
2. Serverless (rejected: long-running payment processing)
3. Hybrid approach (rejected: too complex for current scale)
```

---

## Architectural Tradeoffs

### Decision Matrix

```
                Monolith    Microservices    Serverless    Event-Driven
Complexity          ●●         ●●●●●           ●●●         ●●●●
Scalability         ●●         ●●●●●           ●●●●●       ●●●●
Operability         ●●●●●      ●●●             ●●●●        ●●
Time to Market      ●●●●●      ●●              ●●●●        ●●●
Cost at Scale       ●●●        ●●●             ●●●●●       ●●●
Team Size           ●●●        ●●              ●●●●        ●●

Key: ● = Favorable, ●●●●● = Least favorable
```

### Evolution Path

```
Startup Phase:
  Monolith (Simple, fast to build)
         ↓
  Too slow? Too complex?
         ↓
Growth Phase:
  Modular Monolith
         ↓
  Team friction? Different scaling needs?
         ↓
Enterprise Phase:
  Microservices (with Service Mesh)
         ↓
  Real-time requirements? Cost concerns?
         ↓
  Hybrid: Microservices + Serverless + Event-Driven
```

---

## Architecture Best Practices Checklist

### Planning Phase
- [ ] Architecture decision documented (ADR)
- [ ] Scalability requirements defined
- [ ] Team structure planned
- [ ] Technology choices justified

### Design Phase
- [ ] Service boundaries clearly defined
- [ ] Communication patterns documented
- [ ] Data consistency strategy defined
- [ ] Disaster recovery planned

### Development Phase
- [ ] API contracts defined (OpenAPI)
- [ ] Service can be developed independently
- [ ] Local development environment works
- [ ] Integration tests automated

### Operations Phase
- [ ] Monitoring strategy in place
- [ ] Logging aggregation working
- [ ] Deployment automation tested
- [ ] Rollback procedures documented

### Review Phase
- [ ] Architecture reviewed after 6 months
- [ ] Lessons learned documented
- [ ] Performance metrics analyzed
- [ ] Team feedback incorporated

---

## References

- [Sam Newman - Building Microservices](https://samnewman.io/books/building_microservices/)
- [Chris Richardson - Microservices Patterns](https://microservices.io/)
- [Istio Documentation](https://istio.io/latest/docs/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [Google Cloud Architecture Center](https://cloud.google.com/architecture)
- [The Twelve-Factor App](https://12factor.net/)

---

**Author**: Michael Vogeler  
**Last Updated**: December 2025  
**Maintained By**: Architecture & DevOps Team
