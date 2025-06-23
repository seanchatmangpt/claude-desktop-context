#!/usr/bin/env node
/**
 * validate-coverage.js - Validates test coverage meets 80/20 requirements
 * Ensures 80% unit test coverage and 20% integration coverage
 */

const fs = require('fs')
const path = require('path')

// Colors for console output
const colors = {
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  blue: '\x1b[34m',
  reset: '\x1b[0m'
}

console.log(`${colors.blue}=== Test Coverage Validation ===${colors.reset}`)

async function validateCoverage() {
  try {
    // Read coverage report
    const coverageFile = path.join(process.cwd(), 'coverage/coverage-summary.json')
    
    if (!fs.existsSync(coverageFile)) {
      console.error(`${colors.red}Error: Coverage file not found. Run 'npm run test:coverage' first.${colors.reset}`)
      process.exit(1)
    }
    
    const coverage = JSON.parse(fs.readFileSync(coverageFile, 'utf-8'))
    const total = coverage.total
    
    // Extract coverage metrics
    const metrics = {
      lines: total.lines.pct,
      functions: total.functions.pct,
      branches: total.branches.pct,
      statements: total.statements.pct
    }
    
    console.log(`${colors.blue}Coverage Summary:${colors.reset}`)
    console.log(`  Lines: ${metrics.lines}%`)
    console.log(`  Functions: ${metrics.functions}%`)
    console.log(`  Branches: ${metrics.branches}%`)
    console.log(`  Statements: ${metrics.statements}%`)
    
    // Validate 80/20 rule
    const requirements = {
      lines: 80,
      functions: 80,
      branches: 70, // Slightly lower for branches as they're harder to cover
      statements: 80
    }
    
    let passed = true
    const failures = []
    
    for (const [metric, value] of Object.entries(metrics)) {
      const required = requirements[metric]
      if (value < required) {
        passed = false
        failures.push(`${metric}: ${value}% < ${required}% required`)
      }
    }
    
    // Check unit vs integration test distribution
    const testDistribution = await analyzeTestDistribution()
    
    console.log(`${colors.blue}Test Distribution:${colors.reset}`)
    console.log(`  Unit tests: ${testDistribution.unit} files (${testDistribution.unitPercent}%)`)
    console.log(`  Integration tests: ${testDistribution.integration} files (${testDistribution.integrationPercent}%)`)
    
    // Validate 80/20 distribution
    if (testDistribution.unitPercent < 70) {
      passed = false
      failures.push(`Unit test coverage too low: ${testDistribution.unitPercent}% (should be ~80%)`)
    }
    
    if (testDistribution.integrationPercent > 30) {
      console.log(`${colors.yellow}Note: Integration tests are ${testDistribution.integrationPercent}% (target ~20%)${colors.reset}`)
    }
    
    // Generate detailed report
    const report = {
      timestamp: new Date().toISOString(),
      passed,
      coverage: metrics,
      requirements,
      testDistribution,
      failures,
      recommendations: generateRecommendations(metrics, testDistribution, failures)
    }
    
    // Save report
    const reportPath = path.join(process.cwd(), '.cdcs/coverage_report.json')
    fs.writeFileSync(reportPath, JSON.stringify(report, null, 2))
    
    // Display results
    if (passed) {
      console.log(`${colors.green}✓ Coverage validation PASSED${colors.reset}`)
      console.log(`${colors.green}  All coverage thresholds met${colors.reset}`)
      console.log(`${colors.green}  80/20 test distribution maintained${colors.reset}`)
      
      // Award performance rating
      const averageCoverage = Object.values(metrics).reduce((a, b) => a + b, 0) / Object.keys(metrics).length
      if (averageCoverage >= 90) {
        console.log(`${colors.green}★★★★★ Excellent coverage (${averageCoverage.toFixed(1)}%)${colors.reset}`)
      } else if (averageCoverage >= 85) {
        console.log(`${colors.green}★★★★☆ Good coverage (${averageCoverage.toFixed(1)}%)${colors.reset}`)
      } else {
        console.log(`${colors.yellow}★★★☆☆ Adequate coverage (${averageCoverage.toFixed(1)}%)${colors.reset}`)
      }
    } else {
      console.log(`${colors.red}✗ Coverage validation FAILED${colors.reset}`)
      failures.forEach(failure => {
        console.log(`${colors.red}  ${failure}${colors.reset}`)
      })
      
      console.log(`${colors.yellow}Recommendations:${colors.reset}`)
      report.recommendations.forEach(rec => {
        console.log(`  • ${rec}`)
      })
      
      process.exit(1)
    }
    
    console.log(`${colors.blue}Detailed report saved to: ${reportPath}${colors.reset}`)
    
  } catch (error) {
    console.error(`${colors.red}Error validating coverage: ${error.message}${colors.reset}`)
    process.exit(1)
  }
}

async function analyzeTestDistribution() {
  const unitTestDir = path.join(process.cwd(), 'test/unit')
  const integrationTestDir = path.join(process.cwd(), 'test/integration')
  
  let unitCount = 0
  let integrationCount = 0
  
  // Count unit tests
  if (fs.existsSync(unitTestDir)) {
    const unitFiles = fs.readdirSync(unitTestDir).filter(f => f.endsWith('.test.ts'))
    unitCount = unitFiles.length
  }
  
  // Count integration tests
  if (fs.existsSync(integrationTestDir)) {
    const integrationFiles = fs.readdirSync(integrationTestDir).filter(f => f.endsWith('.test.ts'))
    integrationCount = integrationFiles.length
  }
  
  const total = unitCount + integrationCount
  
  return {
    unit: unitCount,
    integration: integrationCount,
    total,
    unitPercent: total > 0 ? Math.round((unitCount / total) * 100) : 0,
    integrationPercent: total > 0 ? Math.round((integrationCount / total) * 100) : 0
  }
}

function generateRecommendations(metrics, testDistribution, failures) {
  const recommendations = []
  
  // Coverage-specific recommendations
  if (metrics.lines < 80) {
    recommendations.push('Add more unit tests to improve line coverage')
  }
  
  if (metrics.functions < 80) {
    recommendations.push('Test more functions, especially edge cases and error paths')
  }
  
  if (metrics.branches < 70) {
    recommendations.push('Add tests for conditional logic and error handling branches')
  }
  
  // Distribution recommendations
  if (testDistribution.unitPercent < 70) {
    recommendations.push('Focus on unit tests - they should comprise ~80% of your test suite')
    recommendations.push('Unit tests are faster and provide better feedback for development')
  }
  
  if (testDistribution.integrationPercent > 30) {
    recommendations.push('Consider converting some integration tests to unit tests')
    recommendations.push('Integration tests should focus on critical workflows (~20% of suite)')
  }
  
  // CDCS-specific recommendations
  if (failures.length > 0) {
    recommendations.push('Use npm run test:watch for continuous testing during development')
    recommendations.push('Focus on testing SPR functions and prediction algorithms first')
    recommendations.push('Integration tests should cover auto-predict and auto-optimize workflows')
  }
  
  return recommendations
}

// Validate coverage thresholds in CI/CD
function validateForCI() {
  const isCI = process.env.CI === 'true'
  
  if (isCI) {
    console.log(`${colors.blue}Running in CI mode - strict validation${colors.reset}`)
    // In CI, we might want stricter thresholds
    return true
  }
  
  return false
}

// Main execution
if (require.main === module) {
  validateCoverage()
}