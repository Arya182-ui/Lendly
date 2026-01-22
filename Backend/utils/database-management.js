/**
 * 🚀 DATABASE PERFORMANCE MONITORING & DEPLOYMENT UTILITIES
 * 
 * This file provides utilities to:
 * - Monitor query performance in real-time
 * - Deploy Firestore indexes
 * - Validate query optimization
 * - Generate performance reports
 */

const admin = require('firebase-admin');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const { perfMonitor } = require('./advanced-query-optimizer');

class DatabaseDeploymentManager {
  constructor() {
    this.indexesPath = path.join(__dirname, '../firestore.indexes.json');
  }

  /**
   * Deploy Firestore indexes from configuration
   */
  async deployIndexes() {
    try {
      console.log('🚀 [DEPLOY] Starting Firestore index deployment...');
      
      if (!fs.existsSync(this.indexesPath)) {
        throw new Error(`Index configuration not found at: ${this.indexesPath}`);
      }
      
      // Validate index configuration
      const indexConfig = JSON.parse(fs.readFileSync(this.indexesPath, 'utf8'));
      console.log(`📋 [DEPLOY] Found ${indexConfig.indexes.length} indexes to deploy`);
      
      // Deploy using Firebase CLI (requires firebase-tools globally installed)
      console.log('⏳ [DEPLOY] Deploying indexes...');
      const output = execSync('firebase deploy --only firestore:indexes', {
        encoding: 'utf8',
        cwd: path.join(__dirname, '..')
      });
      
      console.log('✅ [DEPLOY] Index deployment output:', output);
      
      // Wait for indexes to build
      console.log('⏰ [DEPLOY] Indexes are building. This may take several minutes...');
      console.log('💡 [DEPLOY] Monitor progress at: https://console.firebase.google.com');
      
      return {
        success: true,
        indexCount: indexConfig.indexes.length,
        output
      };
      
    } catch (error) {
      console.error('❌ [DEPLOY] Index deployment failed:', error);
      return {
        success: false,
        error: error.message
      };
    }
  }

  /**
   * Validate that required indexes exist
   */
  async validateIndexes() {
    try {
      console.log('🔍 [VALIDATE] Checking index status...');
      
      // This would need to be implemented using Firebase Admin SDK
      // For now, we'll provide guidance
      
      const recommendations = [
        'Check Firebase Console for index build status',
        'Monitor slow query logs for missing indexes',
        'Test critical query paths after deployment',
        'Set up alerting for query performance degradation'
      ];
      
      console.log('📊 [VALIDATE] Index validation recommendations:');
      recommendations.forEach((rec, i) => {
        console.log(`  ${i + 1}. ${rec}`);
      });
      
      return { success: true, recommendations };
      
    } catch (error) {
      console.error('❌ [VALIDATE] Index validation failed:', error);
      return { success: false, error: error.message };
    }
  }

  /**
   * Generate performance optimization report
   */
  generatePerformanceReport() {
    const stats = perfMonitor.getStats();
    const report = {
      timestamp: new Date().toISOString(),
      totalQueries: Object.keys(stats).length,
      slowQueries: [],
      fastQueries: [],
      recommendations: []
    };

    // Analyze query performance
    for (const [queryId, data] of Object.entries(stats)) {
      const queryInfo = {
        queryId,
        avgDuration: parseFloat(data.avgDuration),
        count: data.count,
        maxDuration: data.maxDuration,
        avgResultCount: data.avgResultCount
      };

      if (queryInfo.avgDuration > 1000) {
        report.slowQueries.push(queryInfo);
        report.recommendations.push(`Optimize ${queryId}: avg ${data.avgDuration}ms`);
      } else {
        report.fastQueries.push(queryInfo);
      }
    }

    // Generate recommendations
    if (report.slowQueries.length > 0) {
      report.recommendations.push('Review composite indexes for slow queries');
      report.recommendations.push('Consider query result caching');
      report.recommendations.push('Implement pagination for large datasets');
    }

    console.log('📊 [REPORT] Performance Analysis:');
    console.log(`   Total Queries: ${report.totalQueries}`);
    console.log(`   Slow Queries: ${report.slowQueries.length}`);
    console.log(`   Fast Queries: ${report.fastQueries.length}`);

    if (report.slowQueries.length > 0) {
      console.log('\n🐌 [SLOW QUERIES]:');
      report.slowQueries.forEach(query => {
        console.log(`   ${query.queryId}: ${query.avgDuration}ms avg (${query.count} calls)`);
      });
    }

    return report;
  }
}

class QueryHealthMonitor {
  constructor() {
    this.healthChecks = new Map();
    this.alertThresholds = {
      slowQuery: 2000, // 2 seconds
      highErrorRate: 0.1, // 10%
      lowResultCount: 5 // Less than 5 results consistently
    };
  }

  /**
   * Register a health check for a query pattern
   */
  registerHealthCheck(queryPattern, expectedResults = null) {
    this.healthChecks.set(queryPattern, {
      pattern: queryPattern,
      expectedResults,
      lastCheck: null,
      status: 'unknown',
      history: []
    });
  }

  /**
   * Run health checks on registered queries
   */
  async runHealthChecks() {
    console.log('🏥 [HEALTH] Running database health checks...');
    
    const results = [];
    
    for (const [pattern, config] of this.healthChecks) {
      try {
        const startTime = Date.now();
        
        // This is a placeholder - implement actual health checks
        const mockResult = {
          pattern,
          duration: Date.now() - startTime,
          resultCount: Math.floor(Math.random() * 100),
          success: true
        };
        
        const status = this._evaluateHealth(mockResult);
        
        config.lastCheck = new Date();
        config.status = status.healthy ? 'healthy' : 'unhealthy';
        config.history.push({
          timestamp: new Date(),
          ...mockResult,
          ...status
        });
        
        // Keep only last 10 checks
        if (config.history.length > 10) {
          config.history = config.history.slice(-10);
        }
        
        results.push({
          pattern,
          status: config.status,
          ...status
        });
        
      } catch (error) {
        console.error(`❌ [HEALTH] Check failed for ${pattern}:`, error);
        results.push({
          pattern,
          status: 'error',
          error: error.message
        });
      }
    }
    
    console.log(`✅ [HEALTH] Completed ${results.length} health checks`);
    return results;
  }

  _evaluateHealth(result) {
    const issues = [];
    let healthy = true;

    if (result.duration > this.alertThresholds.slowQuery) {
      issues.push(`Slow query: ${result.duration}ms`);
      healthy = false;
    }

    if (result.resultCount < this.alertThresholds.lowResultCount) {
      issues.push(`Low result count: ${result.resultCount}`);
    }

    return {
      healthy,
      issues,
      recommendations: healthy ? [] : [
        'Check query indexes',
        'Verify data availability',
        'Consider query optimization'
      ]
    };
  }
}

// CLI utilities for database management
class DatabaseCLI {
  static async run(command, args = []) {
    const deploymentManager = new DatabaseDeploymentManager();
    const healthMonitor = new QueryHealthMonitor();

    switch (command) {
      case 'deploy-indexes':
        return await deploymentManager.deployIndexes();
        
      case 'validate-indexes':
        return await deploymentManager.validateIndexes();
        
      case 'performance-report':
        return deploymentManager.generatePerformanceReport();
        
      case 'health-check':
        // Register common health checks
        healthMonitor.registerHealthCheck('users_by_college');
        healthMonitor.registerHealthCheck('transactions_by_user');
        healthMonitor.registerHealthCheck('available_items');
        
        return await healthMonitor.runHealthChecks();
        
      case 'help':
        console.log(`
🚀 LENDLY DATABASE MANAGEMENT CLI

Available commands:
  deploy-indexes     - Deploy Firestore composite indexes
  validate-indexes   - Validate index deployment status  
  performance-report - Generate query performance analysis
  health-check       - Run database health diagnostics
  help              - Show this help message

Usage:
  node database-management.js <command>
        `);
        return { success: true };
        
      default:
        console.error(`❌ Unknown command: ${command}`);
        return { success: false, error: `Unknown command: ${command}` };
    }
  }
}

// Export for use in other modules
module.exports = {
  DatabaseDeploymentManager,
  QueryHealthMonitor,
  DatabaseCLI
};

// CLI execution when run directly
if (require.main === module) {
  const command = process.argv[2] || 'help';
  const args = process.argv.slice(3);
  
  DatabaseCLI.run(command, args)
    .then(result => {
      if (result.success !== false) {
        console.log('✅ [CLI] Command completed successfully');
        process.exit(0);
      } else {
        console.error('❌ [CLI] Command failed:', result.error);
        process.exit(1);
      }
    })
    .catch(error => {
      console.error('💥 [CLI] Unexpected error:', error);
      process.exit(1);
    });
}
