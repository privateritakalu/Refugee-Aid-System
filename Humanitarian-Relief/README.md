# Automated Refugee Support System Smart Contract

## Overview

The Automated Refugee Support System is a blockchain-based smart contract built on the Stacks network using Clarity. This system provides transparent and efficient management of resources for refugees, including registration, verification, donation tracking, and resource allocation.

## Features

- **Refugee Registration**: Secure registration system with unique ID assignment
- **Verification System**: Multi-level verification by authorized personnel
- **Resource Management**: Comprehensive tracking of different resource types (food, shelter, medical, education, clothing)
- **Donation Tracking**: Transparent donation system with full audit trail
- **Priority-Based Allocation**: Smart allocation based on priority level and family size
- **Authorization Controls**: Role-based access control for different operations
- **Emergency Controls**: Contract pause functionality for emergency situations

## Contract Architecture

### Core Data Structures

#### Refugees Map
Stores comprehensive refugee profiles including:
- Personal information (name, age, family size, location)
- Registration and verification status
- Priority level (1-5 scale)
- Total resources received

#### Resource Pool Map
Tracks available resources by type:
- Available and allocated amounts
- Unit costs in microSTX
- Resource type validation

#### Resource Allocations Map
Records individual allocations:
- Allocation amounts and dates
- Status tracking (pending, approved, distributed)
- Approver information

#### Donations Map
Maintains donation transparency:
- Donor information
- Amounts and resource types
- Optional messages
- Donation timestamps

## Installation and Deployment

### Prerequisites
- Stacks blockchain testnet/mainnet access
- Clarity CLI tools
- STX tokens for deployment

### Deployment Steps

1. Clone the repository
2. Install dependencies:
   ```bash
   npm install @stacks/cli
   ```

3. Deploy to testnet:
   ```bash
   stx deploy_contract refugee-support-system contract.clar --testnet
   ```

4. Deploy to mainnet:
   ```bash
   stx deploy_contract refugee-support-system contract.clar --mainnet
   ```

## Usage Guide

### Contract Owner Functions

#### Initialize Resource Pool
```clarity
(contract-call? .refugee-support-system initialize-resource-pool 
  "food" 
  u1000 
  u100000)
```

#### Add Authorized Personnel
```clarity
(contract-call? .refugee-support-system add-authorized-personnel 
  'SP1HTBVD3JG9C05J7HBJTHGR0GGW7KX6G8YNP1JS
  "field-coordinator")
```

### Refugee Functions

#### Register as Refugee
```clarity
(contract-call? .refugee-support-system register-refugee 
  "John Doe" 
  u35 
  u4 
  "Refugee Camp A, Location X" 
  u4)
```

### Authorized Personnel Functions

#### Verify Refugee
```clarity
(contract-call? .refugee-support-system verify-refugee u1)
```

#### Allocate Resources
```clarity
(contract-call? .refugee-support-system allocate-resources 
  u1 
  "food" 
  u10)
```

#### Mark as Distributed
```clarity
(contract-call? .refugee-support-system mark-resource-distributed 
  u1 
  "food")
```

### Public Functions

#### Donate Resources
```clarity
(contract-call? .refugee-support-system donate-resources 
  "medical" 
  u5 
  (some "Emergency medical supplies donation"))
```

## Resource Types

The system supports five resource types:
- **food**: Basic nutrition and food supplies
- **shelter**: Housing and temporary accommodation
- **medical**: Healthcare supplies and services
- **education**: Educational materials and services
- **clothing**: Basic clothing and personal items

## Priority System

Refugees are assigned priority levels from 1-5:
- **Level 1**: Standard priority
- **Level 2**: Moderate priority
- **Level 3**: Elevated priority
- **Level 4**: High priority (2x allocation multiplier)
- **Level 5**: Critical priority (2x allocation multiplier)

Additional multiplier applied for families with more than 3 members.

## Constants and Limits

- **Minimum Donation**: 1 STX (1,000,000 microSTX)
- **Maximum Resource Allocation**: 10 STX worth (10,000,000 microSTX)
- **Priority Levels**: 1-5 scale
- **Supported Resource Types**: 5 categories

## Error Codes

| Code | Error | Description |
|------|-------|-------------|
| 1001 | ERR-UNAUTHORIZED-ACCESS | Caller lacks required permissions |
| 1002 | ERR-REFUGEE-NOT-FOUND | Refugee ID does not exist |
| 1003 | ERR-REFUGEE-ALREADY-REGISTERED | Duplicate registration attempt |
| 1004 | ERR-INVALID-RESOURCE-TYPE | Unsupported resource type |
| 1005 | ERR-INSUFFICIENT-RESOURCES | Not enough resources in pool |
| 1006 | ERR-INVALID-AMOUNT | Amount must be greater than zero |
| 1007 | ERR-DONATION-FAILED | STX transfer failed |
| 1008 | ERR-ALREADY-VERIFIED | Refugee already verified |
| 1009 | ERR-NOT-VERIFIED | Refugee verification required |
| 1010 | ERR-INVALID-PRIORITY-LEVEL | Priority must be 1-5 |
| 1011 | ERR-RESOURCE-LIMIT-EXCEEDED | Allocation exceeds maximum limit |

## Read-Only Functions

### Get Refugee Information
```clarity
(contract-call? .refugee-support-system get-refugee-info u1)
```

### Get Resource Pool Status
```clarity
(contract-call? .refugee-support-system get-resource-pool-status "food")
```

### Get Allocation Details
```clarity
(contract-call? .refugee-support-system get-allocation-details u1 "food")
```

### Get Contract Statistics
```clarity
(contract-call? .refugee-support-system get-contract-stats)
```

## Security Features

- **Access Control**: Role-based permissions for different operations
- **Verification Requirements**: Refugees must be verified before resource allocation
- **Amount Validation**: Input validation for all monetary values
- **Emergency Pause**: Contract owner can pause operations if needed
- **Audit Trail**: Complete transaction history for transparency

## Testing

### Unit Tests
Run comprehensive tests covering all functions:

```bash
npm test
```

### Integration Tests
Test full workflow scenarios:

1. Contract deployment
2. Resource pool initialization
3. Refugee registration and verification
4. Donation and allocation cycles
5. Distribution tracking

## Contributing

1. Fork the repository
2. Create feature branch
3. Implement changes with tests
4. Submit pull request with detailed description