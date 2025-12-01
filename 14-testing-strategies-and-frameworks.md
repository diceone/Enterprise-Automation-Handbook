# Testing Strategies & Frameworks

A comprehensive guide for implementing effective testing strategies across infrastructure automation, covering unit tests, integration tests, end-to-end tests, performance testing, and chaos engineering for enterprise DevOps environments.

## Table of Contents

1. [Testing Pyramid and Strategy](#testing-pyramid-and-strategy)
2. [Unit Testing](#unit-testing)
3. [Integration Testing](#integration-testing)
4. [End-to-End Testing](#end-to-end-testing)
5. [Performance Testing](#performance-testing)
6. [Security Testing](#security-testing)
7. [Infrastructure Testing](#infrastructure-testing)
8. [Chaos Engineering](#chaos-engineering)
9. [Test Automation and CI/CD](#test-automation-and-cicd)
10. [Testing Best Practices](#testing-best-practices)

---

## Testing Pyramid and Strategy

### The Testing Pyramid

```
                         ▲
                        /E2E\
                       / 10% \
                      /________\
                     /  Integration\
                    /     Tests    \
                   /      40%       \
                  /__________________\
                 /   Unit Tests      \
                /        50%          \
               /______________________ \

Characteristics:
├─ Base (Unit): Many tests, fast, cheap
├─ Middle (Integration): Fewer tests, moderate speed
└─ Top (E2E): Fewest tests, slow, expensive

Benefits:
├─ Fast feedback: Unit tests run in seconds
├─ Cost-effective: Many cheap tests vs few expensive tests
├─ Comprehensive: All levels covered
└─ Maintainable: Easier to debug failures at unit level
```

### Test Types and Coverage

```yaml
Unit Tests (50%):
  Definition: Test single function/method in isolation
  Scope: < 100 lines of code
  Speed: < 100ms per test
  Examples:
    - Function returns correct output for input
    - Error handling works correctly
    - Edge cases handled
  Tools: pytest, unittest, jasmine
  Coverage Target: > 80%

Integration Tests (40%):
  Definition: Test multiple components working together
  Scope: Service, module, or component
  Speed: 100ms - 1 second per test
  Examples:
    - API endpoint with database
    - Microservice communication
    - Cache integration
  Tools: pytest, testcontainers, docker-compose
  Coverage Target: > 60%

End-to-End Tests (10%):
  Definition: Test complete user workflow
  Scope: Full system
  Speed: 1 second - 5 minutes per test
  Examples:
    - User login → Purchase → Confirmation
    - Deployment → Health check → Rollback
    - CI/CD pipeline execution
  Tools: Selenium, Cypress, kubectl
  Coverage Target: > 30% (critical paths only)

Contract Tests (Bonus):
  Definition: Test service API contracts
  Scope: Service boundaries
  Speed: 100ms - 500ms per test
  Examples:
    - API returns expected JSON schema
    - Message format correct
    - Error responses documented
  Tools: PACT, Spring Cloud Contract
  Coverage Target: All service interactions
```

### Test Strategy Decision Matrix

```yaml
Component Type | Unit | Integration | E2E | Performance | Security
─────────────────────────────────────────────────────────────────────
Business Logic | ✅✅✅ | ✅         | ✅   | -          | -
API Endpoints  | ✅✅  | ✅✅       | ✅   | ✅         | ✅
Database Ops   | ✅   | ✅✅✅      | -    | ✅         | ✅
Infrastructure | ✅   | ✅✅       | ✅✅✅| ✅         | ✅✅✅
Authentication | ✅✅  | ✅✅       | ✅   | -          | ✅✅✅
Payments       | ✅   | ✅✅       | ✅✅✅| -          | ✅✅✅
```

---

## Unit Testing

### Unit Testing Principles

```yaml
Characteristics of Good Unit Tests:

1. Isolated:
   ✅ No external dependencies (database, API, filesystem)
   ✅ Mock all external calls
   ❌ DON'T test the whole system
   ❌ DON'T rely on execution order

2. Fast:
   ✅ Target: < 100ms per test
   ✅ Run all tests in < 10 seconds
   ❌ DON'T make network calls
   ❌ DON'T write to disk

3. Deterministic:
   ✅ Same result every run (no randomness)
   ✅ No timing issues
   ❌ DON'T depend on current time
   ❌ DON'T use random data in assertions

4. Focused:
   ✅ Test one behavior per test
   ✅ Clear assertion
   ❌ DON'T test multiple features
   ❌ DON'T have multiple assertions per test

5. Readable:
   ✅ Clear test name
   ✅ Arrange-Act-Assert pattern
   ❌ DON'T use cryptic variable names
   ❌ DON'T hide logic in test helpers
```

### Unit Testing with Pytest

```python
# Python Unit Testing with pytest

import pytest
from unittest.mock import Mock, patch
from app.services import UserService
from app.models import User

class TestUserService:
    """Test cases for UserService"""
    
    @pytest.fixture
    def user_service(self):
        """Setup: Create service with mocked dependencies"""
        self.db = Mock()
        self.cache = Mock()
        return UserService(db=self.db, cache=self.cache)
    
    def test_get_user_success(self, user_service):
        """Arrange-Act-Assert pattern"""
        # Arrange: Setup test data
        user_id = "user_123"
        expected_user = User(id=user_id, name="John Doe", email="john@example.com")
        self.db.get_user.return_value = expected_user
        
        # Act: Execute the code under test
        result = user_service.get_user(user_id)
        
        # Assert: Verify the result
        assert result.id == user_id
        assert result.name == "John Doe"
        self.db.get_user.assert_called_once_with(user_id)
    
    def test_get_user_not_found(self, user_service):
        """Test error handling"""
        # Arrange
        user_id = "nonexistent"
        self.db.get_user.return_value = None
        
        # Act & Assert
        with pytest.raises(ValueError, match="User not found"):
            user_service.get_user(user_id)
    
    def test_get_user_from_cache(self, user_service):
        """Test caching behavior"""
        # Arrange
        user_id = "user_123"
        cached_user = User(id=user_id, name="John Doe", email="john@example.com")
        self.cache.get.return_value = cached_user
        self.db.get_user.return_value = None  # Verify cache is used
        
        # Act
        result = user_service.get_user(user_id)
        
        # Assert
        assert result == cached_user
        self.db.get_user.assert_not_called()  # DB should not be called
    
    @pytest.mark.parametrize("email,expected_valid", [
        ("user@example.com", True),
        ("invalid-email", False),
        ("@example.com", False),
        ("user@", False),
    ])
    def test_validate_email(self, email, expected_valid):
        """Parametrized tests for multiple inputs"""
        result = UserService.validate_email(email)
        assert result == expected_valid
    
    def test_create_user_with_duplicate_email(self, user_service):
        """Test business logic validation"""
        # Arrange
        self.db.user_exists.return_value = True
        
        # Act & Assert
        with pytest.raises(ValueError, match="Email already exists"):
            user_service.create_user(
                name="Jane Doe",
                email="existing@example.com"
            )

# Test configuration (conftest.py)

@pytest.fixture(scope="session")
def test_config():
    """Load test configuration"""
    return {
        "database_url": "sqlite:///:memory:",
        "cache_ttl": 60,
        "environment": "test"
    }

# Run tests:
# pytest tests/ -v --cov=app --cov-report=html
# Results: tests/coverage/index.html
```

### Unit Testing Best Practices

```yaml
Test Naming Convention:
  Format: test_<function>_<scenario>_<expected_result>
  
  Examples:
    ✅ test_get_user_with_valid_id_returns_user
    ✅ test_calculate_price_with_discount_applies_discount
    ✅ test_login_with_wrong_password_raises_error
    
    ❌ test_user (too vague)
    ❌ test_1 (meaningless)
    ❌ test_function (describes code, not behavior)

AAA Pattern:
  Arrange: Setup test data and mocks
  Act: Call the function under test
  Assert: Verify the result
  
  Example:
    def test_discount_calculation():
        # Arrange
        price = 100
        discount_rate = 0.1
        
        # Act
        result = calculate_discount(price, discount_rate)
        
        # Assert
        assert result == 90

Mocking:
  - Mock external services (databases, APIs, filesystems)
  - Use real logic for core business logic
  - Avoid mocking what's not necessary
  
  ✅ Mock: Database calls, HTTP requests, time
  ❌ Don't mock: Your business logic, validation logic
```

---

## Integration Testing

### Integration Testing Strategy

```yaml
What to Test:
  ✅ Service with real database
  ✅ Multiple services communicating
  ✅ API endpoint with dependencies
  ✅ Configuration loading
  ✅ Error handling across layers
  
  ❌ Don't test: External APIs directly
  ❌ Don't test: Third-party libraries
  ❌ Don't test: Infrastructure (networks, VMs)

Test Environment:
  Database: Testcontainers (Docker)
  Cache: In-memory or containerized
  Message Queue: Testcontainers
  Time: Controlled/mocked
  External APIs: Mocked

Benefits:
  - Detect configuration errors
  - Verify component interaction
  - Catch environment-specific issues
  - Test error propagation
```

### Integration Testing Example

```python
# Integration Test with testcontainers

import pytest
from testcontainers.postgres import PostgresContainer
from testcontainers.redis import RedisContainer
from app.services import UserService
from app.repository import UserRepository

@pytest.fixture(scope="session")
def postgres_container():
    """Setup PostgreSQL container for tests"""
    container = PostgresContainer(
        image="postgres:14",
        driver=None  # Use default Docker driver
    )
    container.start()
    yield container
    container.stop()

@pytest.fixture(scope="session")
def redis_container():
    """Setup Redis container for tests"""
    container = RedisContainer(image="redis:7")
    container.start()
    yield container
    container.stop()

@pytest.fixture
def db_connection(postgres_container):
    """Create database connection to test database"""
    connection_url = postgres_container.get_connection_url()
    # Setup tables, run migrations
    return connection_url

@pytest.fixture
def cache_connection(redis_container):
    """Create cache connection to test Redis"""
    return redis_container.get_connection_url()

class TestUserServiceIntegration:
    """Integration tests with real dependencies"""
    
    def test_create_and_retrieve_user(self, db_connection, cache_connection):
        """Test full user creation flow"""
        # Setup
        repository = UserRepository(db_connection)
        cache = RedisCache(cache_connection)
        service = UserService(repository=repository, cache=cache)
        
        # Act: Create user
        created_user = service.create_user(
            name="John Doe",
            email="john@example.com"
        )
        
        # Assert: Retrieve and verify
        retrieved_user = service.get_user(created_user.id)
        assert retrieved_user.name == "John Doe"
        assert retrieved_user.email == "john@example.com"
        
        # Verify cache hit on second retrieval
        retrieved_again = service.get_user(created_user.id)
        assert retrieved_again == retrieved_user
    
    def test_user_repository_with_database(self, db_connection):
        """Test database operations"""
        repo = UserRepository(db_connection)
        
        # Create
        user = repo.create(name="Jane Doe", email="jane@example.com")
        assert user.id is not None
        
        # Read
        retrieved = repo.get_by_id(user.id)
        assert retrieved.name == "Jane Doe"
        
        # Update
        retrieved.name = "Jane Smith"
        repo.update(retrieved)
        
        # Verify update
        updated = repo.get_by_id(user.id)
        assert updated.name == "Jane Smith"
        
        # Delete
        repo.delete(user.id)
        assert repo.get_by_id(user.id) is None
    
    def test_service_handles_database_error(self, db_connection):
        """Test error handling with real database"""
        repo = UserRepository(db_connection)
        service = UserService(repository=repo)
        
        # Simulate database error by using invalid connection
        bad_repo = UserRepository("invalid://connection")
        bad_service = UserService(repository=bad_repo)
        
        with pytest.raises(Exception) as exc_info:
            bad_service.get_user("any_id")
        
        assert "database" in str(exc_info.value).lower()
```

### Integration Testing with Docker Compose

```yaml
# docker-compose.test.yml

version: '3.8'

services:
  postgres:
    image: postgres:14
    environment:
      POSTGRES_DB: test_db
      POSTGRES_USER: test_user
      POSTGRES_PASSWORD: test_password
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test_user"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  api:
    build: .
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    environment:
      DATABASE_URL: postgresql://test_user:test_password@postgres:5432/test_db
      REDIS_URL: redis://redis:6379
      ENVIRONMENT: test
    ports:
      - "8000:8000"
    command: pytest tests/integration/ -v --cov=app

# Run integration tests:
# docker-compose -f docker-compose.test.yml up --abort-on-container-exit
```

---

## End-to-End Testing

### E2E Testing Strategy

```yaml
E2E Test Focus:
  ✅ Critical user workflows
  ✅ Order processing (purchase to confirmation)
  ✅ Authentication flows (signup, login, logout)
  ✅ Complex multi-step processes
  ✅ Cross-browser compatibility (if applicable)
  
  ❌ All features (too slow and expensive)
  ❌ Every error message
  ❌ Performance optimization details

E2E Test Characteristics:
  Speed: Slow (seconds to minutes per test)
  Cost: High (requires full environment)
  Maintenance: Difficult (fragile to changes)
  Value: High (tests real user paths)
  
  Rule: Test 10-20% of scenarios, covering 80% of usage

Tools:
  - Selenium (legacy)
  - Cypress (modern, JavaScript)
  - Playwright (cross-browser)
  - Robot Framework (keyword-driven)
  - Cypress: Recommended for web applications
```

### E2E Testing with Cypress

```javascript
// E2E tests with Cypress

describe('User Authentication and Purchase Flow', () => {
  
  beforeEach(() => {
    // Visit application before each test
    cy.visit('https://app.example.com')
    // Clear cookies/localStorage
    cy.clearCookies()
    cy.localStorage('clear')
  })
  
  it('should register new user and complete purchase', () => {
    // Step 1: Navigate to signup
    cy.get('[data-testid="nav-signup"]').click()
    cy.url().should('include', '/signup')
    
    // Step 2: Fill registration form
    cy.get('[name="email"]').type('newuser@example.com')
    cy.get('[name="password"]').type('SecurePassword123!')
    cy.get('[name="confirm_password"]').type('SecurePassword123!')
    cy.get('[name="accept_terms"]').check()
    
    // Step 3: Submit form
    cy.get('[data-testid="submit-signup"]').click()
    
    // Step 4: Wait for redirect to dashboard
    cy.url().should('include', '/dashboard')
    cy.get('[data-testid="welcome-message"]')
      .should('contain', 'Welcome, newuser')
    
    // Step 5: Browse products
    cy.get('[data-testid="nav-products"]').click()
    cy.get('[data-testid="product-card"]').should('have.length.greaterThan', 0)
    
    // Step 6: Select product
    cy.get('[data-testid="product-card"]').first().click()
    cy.get('[data-testid="product-details"]').should('be.visible')
    
    // Step 7: Add to cart
    cy.get('[data-testid="add-to-cart"]').click()
    cy.get('[data-testid="cart-count"]').should('contain', '1')
    
    // Step 8: Proceed to checkout
    cy.get('[data-testid="nav-cart"]').click()
    cy.get('[data-testid="checkout-button"]').click()
    
    // Step 9: Enter payment details
    cy.get('[name="card_number"]').type('4111111111111111')
    cy.get('[name="expiry"]').type('12/25')
    cy.get('[name="cvc"]').type('123')
    
    // Step 10: Complete purchase
    cy.get('[data-testid="pay-button"]').click()
    
    // Step 11: Verify order confirmation
    cy.url().should('include', '/order-confirmation')
    cy.get('[data-testid="order-number"]').should('be.visible')
    cy.get('[data-testid="confirmation-message"]')
      .should('contain', 'Thank you for your order')
  })
  
  it('should handle login for existing user', () => {
    // Step 1: Click login
    cy.get('[data-testid="nav-login"]').click()
    
    // Step 2: Enter credentials
    cy.get('[name="email"]').type('user@example.com')
    cy.get('[name="password"]').type('CorrectPassword123!')
    
    // Step 3: Submit login
    cy.get('[data-testid="submit-login"]').click()
    
    // Step 4: Verify logged in state
    cy.url().should('include', '/dashboard')
    cy.get('[data-testid="user-menu"]').click()
    cy.get('[data-testid="user-profile-link"]').should('be.visible')
  })
  
  it('should show error for invalid credentials', () => {
    cy.get('[data-testid="nav-login"]').click()
    cy.get('[name="email"]').type('user@example.com')
    cy.get('[name="password"]').type('WrongPassword!')
    cy.get('[data-testid="submit-login"]').click()
    
    // Verify error message and still on login page
    cy.get('[data-testid="error-message"]')
      .should('contain', 'Invalid email or password')
    cy.url().should('include', '/login')
  })
})

// Cypress configuration (cypress.config.js)
module.exports = {
  e2e: {
    baseUrl: 'https://app.example.com',
    viewportWidth: 1280,
    viewportHeight: 720,
    video: false,
    screenshotOnRunFailure: true,
    retries: {
      runMode: 2,      // Retry failed tests 2 times in CI
      openMode: 0      // Don't retry in interactive mode
    },
    setupNodeEvents(on, config) {
      // Custom event handlers
    }
  }
}

// Run tests:
// npx cypress run --spec "cypress/e2e/user-flow.cy.js"
// npx cypress open (interactive mode)
```

---

## Performance Testing

### Performance Testing Types

```yaml
Load Testing:
  Definition: How system behaves under normal load
  Scenario: 100 concurrent users over 10 minutes
  Metric: Response time, throughput
  Tools: JMeter, Gatling, k6
  
Stress Testing:
  Definition: How system behaves under extreme load
  Scenario: Gradually increase load until failure
  Metric: Breaking point, resource exhaustion
  Tools: JMeter, Gatling, k6
  
Spike Testing:
  Definition: How system handles sudden traffic increase
  Scenario: 10 users → 1000 users suddenly
  Metric: Recovery time, error rate
  Tools: JMeter, k6
  
Soak Testing:
  Definition: How system behaves over extended time
  Scenario: Sustained moderate load for 24 hours
  Metric: Memory leaks, connection leaks
  Tools: JMeter, k6
  
Endurance Testing:
  Definition: How system behaves over business cycle
  Scenario: Daily patterns over 1 week
  Metric: Performance degradation, issues
  Tools: JMeter, k6
```

### Performance Testing with k6

```javascript
// Load testing with k6

import http from 'k6/http'
import { check, sleep } from 'k6'
import { Rate, Trend } from 'k6/metrics'

// Custom metrics
const errorRate = new Rate('errors')
const duration = new Trend('duration')

export const options = {
  stages: [
    { duration: '2m', target: 100 },   // Ramp up to 100 users
    { duration: '5m', target: 100 },   // Stay at 100 users
    { duration: '2m', target: 200 },   // Ramp up to 200 users
    { duration: '5m', target: 200 },   // Stay at 200 users
    { duration: '2m', target: 0 },     // Ramp down to 0 users
  ],
  thresholds: {
    // Fail test if error rate > 1%
    'errors': ['rate<0.01'],
    // Fail test if p95 response time > 500ms
    'duration': ['p(95)<500'],
    // Fail test if p99 response time > 2 seconds
    http_req_duration: ['p(99)<2000'],
  },
}

export default function () {
  // Test API endpoint
  const response = http.get('https://api.example.com/users')
  
  // Check response
  const success = check(response, {
    'status is 200': (r) => r.status === 200,
    'response time < 500ms': (r) => r.timings.duration < 500,
    'has user id': (r) => r.body.includes('id'),
  })
  
  // Track errors
  errorRate.add(!success)
  duration.add(response.timings.duration)
  
  // Think time
  sleep(1)
}

// Run: k6 run load-test.js
// Output: Summary with pass/fail results
```

---

## Security Testing

### Security Testing Categories

```yaml
SAST (Static Application Security Testing):
  Definition: Analyze source code for vulnerabilities
  When: During development, in CI/CD
  Tools: SonarQube, Checkmarx, Semgrep
  Examples:
    - SQL injection patterns
    - Hardcoded secrets
    - Insecure dependencies

DAST (Dynamic Application Security Testing):
  Definition: Test running application for vulnerabilities
  When: After deployment, in staging
  Tools: OWASP ZAP, Burp Suite, Fortify WebInspect
  Examples:
    - XSS vulnerabilities
    - CSRF protection
    - Authentication bypass

Dependency Scanning:
  Definition: Check dependencies for known vulnerabilities
  When: During build, in CI/CD
  Tools: Snyk, Dependabot, Safety
  Examples:
    - Outdated libraries
    - CVEs in dependencies
    - License compliance

Secret Scanning:
  Definition: Find hardcoded secrets
  When: On commit, in CI/CD
  Tools: git-secrets, TruffleHog, GitGuardian
  Examples:
    - API keys
    - Database passwords
    - AWS credentials

Infrastructure Security:
  Definition: Scan infrastructure for misconfigurations
  When: During deployment, in CI/CD
  Tools: Checkov, TFSec, kube-bench
  Examples:
    - Open security groups
    - Unencrypted databases
    - Missing network policies
```

### Security Testing Implementation

```yaml
# SAST with SonarQube

sonarqube:
  image: sonarqube:latest
  ports:
    - "9000:9000"
  environment:
    SONAR_ES_BOOTSTRAP_CHECKS_DISABLED: "true"

# In CI/CD pipeline (GitLab CI)
stages:
  - security
  
code_quality:
  stage: security
  image: sonarqube-scanner:latest
  script:
    - sonar-scanner
      -Dsonar.projectKey=my-app
      -Dsonar.sources=src
      -Dsonar.host.url=http://sonarqube:9000
      -Dsonar.login=$SONARQUBE_TOKEN
  allow_failure: false

# DAST with OWASP ZAP
dast:
  stage: security
  image: owasp/zap2docker-stable:latest
  script:
    - zap-baseline.py -t https://staging.example.com -r zap-report.html
  artifacts:
    reports:
      sast: zap-report.html

# Dependency scanning
dependency_check:
  stage: security
  image: owasp/dependency-check:latest
  script:
    - /usr/share/dependency-check/bin/dependency-check.sh
      --project my-app
      --scan ./
      --format HTML
      --out dependency-report
  artifacts:
    paths:
      - dependency-report

# Secret scanning
secret_scan:
  stage: security
  image: trufflesecurity/trufflehog:latest
  script:
    - trufflehog git file:// --json
  allow_failure: true
```

---

## Infrastructure Testing

### Infrastructure as Code Testing

```yaml
Infrastructure Test Types:

Syntax Validation:
  Tool: terraform validate, ansible-lint
  Purpose: Catch syntax errors
  Speed: Seconds
  
Static Analysis:
  Tool: Checkov, TFSec, CloudFormation Lint
  Purpose: Detect security issues
  Speed: Seconds
  Examples:
    - Open security groups
    - Missing encryption
    - Insecure permissions

Unit Tests for IaC:
  Tool: Terratest, Pester, Serverspec
  Purpose: Test infrastructure behavior
  Speed: Minutes
  Examples:
    - VM has required packages
    - Security group has correct rules
    - Database backups enabled

Integration Tests:
  Tool: Terratest, CloudFormation
  Purpose: Deploy and verify full infrastructure
  Speed: 5-30 minutes
  Examples:
    - Deploy VPC and verify networking
    - Create database and verify connection
    - Deploy application and verify health
```

### Terraform Testing with Terratest

```go
// Terratest - Testing Terraform code

package test

import (
	"testing"
	"fmt"
	"github.com/gruntwork-io/terratest/modules/terraform"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/stretchr/testify/assert"
)

func TestTerraformEC2Instance(t *testing.T) {
	// Define Terraform options
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/ec2",
		Vars: map[string]interface{}{
			"instance_type": "t3.micro",
			"ami": "ami-0c55b159cbfafe1f0",
		},
	}

	// Cleanup resources after test
	defer terraform.Destroy(t, terraformOptions)

	// Initialize and apply Terraform
	terraform.InitAndApply(t, terraformOptions)

	// Get outputs
	instanceID := terraform.Output(t, terraformOptions, "instance_id")
	publicIP := terraform.Output(t, terraformOptions, "public_ip")

	// Verify instance exists in AWS
	instance := aws.GetEc2Instance(t, instanceID, "us-east-1")
	assert.Equal(t, "t3.micro", *instance.InstanceType)
	assert.NotEmpty(t, publicIP)

	// Verify security group allows SSH
	securityGroupID := terraform.Output(t, terraformOptions, "security_group_id")
	sg := aws.GetSecurityGroup(t, securityGroupID, "us-east-1")
	
	sshRule := aws.FindSecurityGroupRuleWithCIDR(t, sg, "22", "0.0.0.0/0")
	assert.NotNil(t, sshRule)
}

func TestTerraformVPC(t *testing.T) {
	terraformOptions := &terraform.Options{
		TerraformDir: "../examples/vpc",
		Vars: map[string]interface{}{
			"cidr_block": "10.0.0.0/16",
		},
	}

	defer terraform.Destroy(t, terraformOptions)
	terraform.InitAndApply(t, terraformOptions)

	// Verify VPC created with correct CIDR
	vpcID := terraform.Output(t, terraformOptions, "vpc_id")
	vpc := aws.GetVpc(t, vpcID, "us-east-1")
	assert.Equal(t, "10.0.0.0/16", *vpc.CidrBlock)

	// Verify subnets created
	subnetIDs := terraform.OutputList(t, terraformOptions, "subnet_ids")
	assert.Equal(t, 3, len(subnetIDs)) // 3 subnets

	for _, subnetID := range subnetIDs {
		subnet := aws.GetSubnet(t, subnetID, "us-east-1")
		assert.NotNil(t, subnet.CidrBlock)
	}
}

// Run tests:
// go test -v -timeout 30m
```

### Ansible Testing

```yaml
# Testing Ansible playbooks and roles

# 1. Syntax check
ansible-playbook playbooks/site.yml --syntax-check

# 2. Dry-run
ansible-playbook playbooks/site.yml --check

# 3. Linting
ansible-lint playbooks/

# 4. Unit testing with Molecule

# molecule/default/molecule.yml
driver:
  name: docker

platforms:
  - name: ubuntu-20.04
    image: ubuntu:20.04
    volumes:
      - /sys/fs/cgroup:/sys/fs/cgroup:ro
    privileged: true

provisioner:
  name: ansible

verifier:
  name: ansible

lint:
  name: ansible-lint

# molecule/default/verify.yml
- name: Verify role
  hosts: all
  gather_facts: yes
  tasks:
    - name: Check if nginx is installed
      package_facts:
        manager: auto

    - name: Assert nginx is installed
      assert:
        that:
          - "'nginx' in ansible_facts.packages"

    - name: Check if nginx service is running
      systemd:
        name: nginx
        state: started
        enabled: yes
      register: nginx_status

    - name: Assert nginx is running
      assert:
        that:
          - nginx_status.status.ActiveState == 'active'

# Run tests:
# molecule test
```

---

## Chaos Engineering

### Chaos Engineering Principles

```yaml
Why Chaos Engineering?
  Traditional Testing:
    ├─ Assumes components work correctly
    ├─ Tests individual components
    ├─ Misses interaction failures
    └─ Doesn't simulate real failures

Chaos Engineering:
  ├─ Intentionally breaks things in controlled way
  ├─ Tests resilience and recovery
  ├─ Finds weaknesses before production
  ├─ Builds confidence in system

Hypothesis-Driven Approach:
  1. Establish baseline (normal performance)
  2. Form hypothesis (what should happen when X fails)
  3. Introduce chaos (cause failure)
  4. Observe results
  5. Restore system
  6. Analyze and improve

Types of Chaos Experiments:
  Resource Failures:
    - Kill processes
    - Fill disk space
    - Use up memory
    - Fill CPU
  
  Network Failures:
    - Increase latency
    - Cause packet loss
    - Partition network
    - DNS resolution failures
  
  Time Failures:
    - Clock skew
    - Time jumps
  
  Storage Failures:
    - Database unavailability
    - Filesystem errors
  
  Infrastructure Failures:
    - Kill nodes
    - Restart services
    - Disk I/O errors
```

### Chaos Engineering with Chaos Mesh

```yaml
# Kubernetes Chaos Engineering with Chaos Mesh

# Install Chaos Mesh
helm install chaos-mesh chaos-mesh/chaos-mesh -n chaos-testing --create-namespace

# Example: Kill pod randomly
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: kill-pod-chaos
spec:
  action: kill
  mode: one
  selector:
    namespaces:
      - default
    labelSelectors:
      app: api-server
  scheduler:
    cron: "0 0 * * *"  # Run daily at midnight

---
# Example: Introduce network latency
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-latency-chaos
spec:
  action: delay
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: database
  delay:
    latency: "100ms"
    jitter: "50ms"

---
# Example: Simulate network partition
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-partition-chaos
spec:
  action: partition
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: cache-service
  direction: to
  target:
    selector:
      namespaces:
        - default
      labelSelectors:
        app: api-server

---
# Example: Stress test CPU
apiVersion: chaos-mesh.org/v1alpha1
kind: StressChaos
metadata:
  name: cpu-stress-chaos
spec:
  action: stress
  mode: all
  selector:
    namespaces:
      - default
    labelSelectors:
      app: worker
  stressors:
    cpu:
      workers: 2
      load: 80

# Monitor chaos experiment:
# kubectl get podchaos -n default
# kubectl logs -n chaos-testing chaos-mesh-controller-manager-0
```

---

## Test Automation and CI/CD

### Test Execution Pipeline

```yaml
# GitLab CI/CD Pipeline with Test Stages

stages:
  - build
  - test
  - security
  - deploy
  - e2e

variables:
  DOCKER_DRIVER: overlay2
  COVERAGE_THRESHOLD: 80

build:
  stage: build
  script:
    - docker build -t app:$CI_COMMIT_SHA .
    - docker push registry.example.com/app:$CI_COMMIT_SHA

unit_tests:
  stage: test
  script:
    - pytest tests/unit/ -v --cov=app --cov-report=xml
  coverage: '/TOTAL.*\s+(\d+%)$/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml
  allow_failure: false

integration_tests:
  stage: test
  services:
    - postgres:14
    - redis:7
  variables:
    POSTGRES_DB: test_db
    POSTGRES_USER: test_user
    POSTGRES_PASSWORD: test_password
  script:
    - pytest tests/integration/ -v
  timeout: 30m

security_scan:
  stage: security
  script:
    - sonar-scanner -Dsonar.projectKey=my-app
    - snyk test --severity-threshold=high
  allow_failure: true

performance_test:
  stage: test
  script:
    - k6 run load-test.js --out json=results.json
  artifacts:
    paths:
      - results.json
  retry:
    max: 1
    when: script_failure

deploy_staging:
  stage: deploy
  script:
    - kubectl apply -f k8s/staging/ --record
  environment:
    name: staging
  only:
    - main

e2e_tests:
  stage: e2e
  script:
    - npx cypress run --spec cypress/e2e/**/*.cy.js
  artifacts:
    paths:
      - cypress/videos/
      - cypress/screenshots/
    when: on_failure
  environment:
    name: staging
  dependencies:
    - deploy_staging
```

---

## Testing Best Practices

### Testing Strategy Checklist

```yaml
Planning Phase:
  - [ ] Define test strategy for project
  - [ ] Identify critical paths to test
  - [ ] Determine test-to-code ratio (target: 1:3)
  - [ ] Choose testing tools and frameworks
  - [ ] Create test data strategy
  - [ ] Plan for test environment

Implementation:
  - [ ] Write tests as code (version controlled)
  - [ ] Use clear naming conventions
  - [ ] Keep tests independent
  - [ ] Use fixtures and factories
  - [ ] Mock external dependencies
  - [ ] Implement AAA pattern (Arrange-Act-Assert)

Execution:
  - [ ] Run tests locally before commit
  - [ ] Run full test suite in CI/CD
  - [ ] Track code coverage (target: > 80%)
  - [ ] Monitor test execution time (target: < 10min)
  - [ ] Maintain test results history
  - [ ] Fail build on test failures

Maintenance:
  - [ ] Review and update tests with code changes
  - [ ] Remove duplicate tests
  - [ ] Fix flaky tests immediately
  - [ ] Refactor test code like production code
  - [ ] Document testing procedures
  - [ ] Conduct test review in code reviews

Continuous Improvement:
  - [ ] Track test metrics (execution time, coverage)
  - [ ] Identify slow tests and optimize
  - [ ] Share test knowledge across team
  - [ ] Conduct quarterly testing strategy review
  - [ ] Learn from production incidents
  - [ ] Update tests based on lessons learned
```

### Anti-Patterns to Avoid

```yaml
❌ Anti-Pattern: Test Lottery
  Problem: Tests pass/fail randomly
  Cause: Timing issues, shared state, randomness
  Solution: Deterministic tests, proper isolation

❌ Anti-Pattern: Testing Implementation Details
  Problem: Tests break when refactoring
  Cause: Testing private methods, internal state
  Solution: Test behavior, not implementation

❌ Anti-Pattern: Slow Tests
  Problem: Test suite takes hours to run
  Cause: Too many E2E tests, I/O operations
  Solution: Use testing pyramid (50/40/10 rule)

❌ Anti-Pattern: Brittle Tests
  Problem: Tests fail for minor UI changes
  Cause: Tight coupling to HTML/CSS
  Solution: Use stable selectors, test behavior

❌ Anti-Pattern: No Test Maintenance
  Problem: Test code becomes unreadable
  Cause: Copy-paste, accumulation of helpers
  Solution: Refactor tests like production code

❌ Anti-Pattern: Skipped Tests
  Problem: `@skip` or `@ignore` accumulates
  Cause: Broken tests left unfixed
  Solution: Fix or remove tests immediately

✅ Best Practice: Clear Test Pyramid
✅ Best Practice: Fast Feedback
✅ Best Practice: Test Critical Paths
✅ Best Practice: Maintainable Test Code
✅ Best Practice: Deterministic Tests
✅ Best Practice: Independent Tests
```

---

## References

- [Testing Pyramid - Martin Fowler](https://martinfowler.com/bliki/TestPyramid.html)
- [Google Testing Blog](https://testing.googleblog.com/)
- [Chaos Engineering - principlesofchaos.org](https://principlesofchaos.org/)
- [Pytest Documentation](https://docs.pytest.org/)
- [Cypress Documentation](https://docs.cypress.io/)
- [k6 Documentation](https://k6.io/docs/)

---

**Author**: Michael Vogeler  
**Last Updated**: December 2025  
**Maintained By**: Quality Assurance & Testing Team
