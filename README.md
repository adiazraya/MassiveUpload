# Massive Data Loading from Salesforce Data Cloud to Core

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Salesforce](https://img.shields.io/badge/Salesforce-Data%20Cloud-00A1E0.svg)](https://www.salesforce.com/products/data-cloud/)
[![Success Rate](https://img.shields.io/badge/Success%20Rate-99.93%25-success)](https://github.com/adiazraya/MassiveUpload)

**Production-ready solution for loading millions of records from Salesforce Data Cloud to Salesforce Core with exceptional reliability.**

---

## 🎯 Quick Overview

This solution enables reliable, large-scale data loading from Salesforce Data Cloud to Salesforce Core, achieving **99.93% success rate** for 2+ million records through:

- **Intelligent Partitioning**: Data divided into manageable segments
- **Staggered Execution**: Reduces concurrent processing conflicts  
- **Exponential Backoff Retry**: Smart retry logic for transient failures
- **Bulk API 2.0**: Modern, efficient API with parallel processing
- **Real-time Monitoring**: Track progress and identify issues instantly

**Use Case**: While developed for Opportunity records, this architecture applies to any Salesforce object requiring bulk data loading.

---

## 📚 Documentation

| Document | Description | Read Time |
|----------|-------------|-----------|
| **[PRODUCTION_TECHNICAL_GUIDE.md](./PRODUCTION_TECHNICAL_GUIDE.md)** | Complete technical guide with architecture, implementation, and best practices | 2-3 hours |
| **[COMPONENT_DOCUMENTATION.md](./COMPONENT_DOCUMENTATION.md)** | Code reference with line-by-line explanations and examples | 1-2 hours |
| **[README_OpportunityBulkUploader.md](./README_OpportunityBulkUploader.md)** | Quick start guide for Opportunity loading | 15 minutes |

---

## 🚀 Quick Start

### Prerequisites

- Salesforce org with Data Cloud enabled
- Bulk API 2.0 access
- External ID field on target object
- API limits: ~4000 calls for 2M records

### Installation

```bash
# Clone repository
git clone https://github.com/adiazraya/MassiveUpload.git
cd MassiveUpload

# Deploy custom objects
sfdx force:source:deploy -p force-app/main/default/objects -u YourOrgAlias

# Deploy Apex classes
sfdx force:source:deploy -p force-app/main/default/classes -u YourOrgAlias
```

### Quick Test (1000 records)

```apex
// Test with small dataset first
DynamicPartitionProcessorV2 test = new DynamicPartitionProcessorV2(
    0, 'TestPartition', 'externalId0001', 'externalId1000'
);
Database.executeBatch(test, 1);
```

Monitor progress:
```apex
DataCloudPartition__c progress = [SELECT TotalProcessed__c, Status__c 
                                   FROM DataCloudPartition__c 
                                   WHERE Name = 'TestPartition'];
System.debug('Processed: ' + progress.TotalProcessed__c);
```

### Production Deployment

See **[PRODUCTION_TECHNICAL_GUIDE.md](./PRODUCTION_TECHNICAL_GUIDE.md)** for complete 10-step deployment guide.

---

## 🏗️ Architecture

```
Data Cloud (2M records) → Partitioned Processing → Bulk API 2.0 → Salesforce Core
         ↓                        ↓                      ↓
   Partition 0-4         Staggered Starts      Exponential Backoff
   (400K each)           (1.5h intervals)      (2s, 5s, 10s retry)
```

**Key Components**:

| Component | Purpose |
|-----------|---------|
| `DynamicPartitionProcessorV2` | Core batch processor with retry logic |
| `DelayedBatchStarterV2` | Adds deliberate delays between batches |
| `PartitionScheduler` | Schedules staggered partition starts |
| `DataCloudPartition__c` | Tracks progress and status |

---

## 📊 Performance

**Configuration** (Production-Ready):
- Batch Size: 500 records
- Partitions: 5 (400K each)
- Partition Stagger: 1.5 hours
- Batch Delay: 20-30 seconds
- Retry Strategy: Exponential backoff (2s, 5s, 10s)
- Max Retries: 3 attempts

**Results** (2M records):
- ✅ Success Rate: 99.93%
- ⏱️ Processing Time: ~7 hours
- 🚀 Throughput: ~4,700 records/minute
- ❌ Failed Records: <1,400 (0.07%)

---

## 🛠️ Key Features

### 1. Intelligent Partitioning
Data divided into logical segments for isolated processing and easy restart.

### 2. Staggered Execution
Partitions start 1.5 hours apart, dramatically reducing lock contention on shared parent records.

### 3. Exponential Backoff Retry
Progressive retry delays (2s → 5s → 10s) give locks time to release, improving success rates significantly.

### 4. ExternalId-Based Pagination
Reliable pagination that avoids duplicates and handles millions of records consistently.

### 5. Real-Time Monitoring
Track progress via custom object, debug logs with emoji indicators, and comprehensive metrics.

### 6. Production-Ready
Battle-tested code with comprehensive error handling, recovery procedures, and documentation.

---

## 🎯 Use Cases

**Primary**: Opportunity loading (2M records from Data Cloud)

**Applicable To**:
- Accounts, Contacts, Cases
- Any object with External ID
- Parent-child relationships
- Data Cloud materialization
- System migrations
- Periodic data synchronization

---

## 📖 Technical Highlights

### Challenge: Record Locking
**Problem**: Multiple opportunities per account cause parent record locks  
**Solution**: Small batches (500), staggered execution, exponential backoff

### Challenge: API Limits
**Problem**: 2M records = 4000 API calls  
**Solution**: Efficient batching, monitoring, throttling logic

### Challenge: Data Consistency
**Problem**: OFFSET pagination unreliable at scale  
**Solution**: ExternalId-based WHERE clauses with cursor tracking

### Challenge: Error Recovery
**Problem**: Transient failures inevitable with long-running processes  
**Solution**: Stateful batch processing with intelligent retry and restart capability

---

## 🔧 Configuration Tuning

Adjust parameters based on your scenario:

| Scenario | Batch Size | Delay | Stagger | Retries |
|----------|-----------|-------|---------|---------|
| Low lock risk | 750-1000 | 15-20s | 1h | 2-3 |
| Medium lock risk | 500-750 | 20-30s | 1.5h | 3 |
| High lock risk | 250-500 | 30-45s | 2h | 3-4 |

---

## 📚 Related Documentation

**Salesforce Official**:
- [Bulk API 2.0 Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/)
- [Data Cloud Query API](https://developer.salesforce.com/docs/atlas.en-us.c360a_api.meta/c360a_api/)
- [Batch Apex Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch.htm)

**Trailhead**:
- [Asynchronous Apex](https://trailhead.salesforce.com/content/learn/modules/asynchronous_apex)
- [Large Data Volumes](https://trailhead.salesforce.com/content/learn/modules/large-data-volumes)

---

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/improvement`)
3. Test thoroughly with sample data
4. Update documentation
5. Submit a pull request

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

---

## 👤 Author

**Alberto Díaz Raya**
- GitHub: [@adiazraya](https://github.com/adiazraya)

---

## 🙏 Acknowledgments

- Salesforce community for best practices
- Data Cloud team for query API
- Contributors and testers

---

## 📞 Support

- **Documentation**: See [PRODUCTION_TECHNICAL_GUIDE.md](./PRODUCTION_TECHNICAL_GUIDE.md)
- **Issues**: [GitHub Issues](https://github.com/adiazraya/MassiveUpload/issues)
- **Questions**: [Salesforce Stack Exchange](https://salesforce.stackexchange.com/)

---

**Status**: ✅ Production-Ready | **Version**: 1.0 | **Updated**: January 2026

⭐ Star this repo if you find it useful!
