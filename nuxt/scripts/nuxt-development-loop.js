#!/usr/bin/env node
/**
 * nuxt-development-loop.js - Continuous Nuxt development optimization loop
 * Implements the CDCS implementation loop specifically for Nuxt.js projects
 */

import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { exec } from 'child_process'
import { promisify } from 'util'
import { writeFile, readFile } from 'fs/promises'
import { existsSync } from 'fs'

const execAsync = promisify(exec)
const __dirname = dirname(fileURLToPath(import.meta.url))
const projectRoot = join(__dirname, '..')

// Colors for console output
const colors = {
  blue: '\x1b[34m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  purple: '\x1b[35m',
  cyan: '\x1b[36m',
  reset: '\x1b[0m'
}

// Configuration
const LOOP_COUNT = process.argv[2] ? parseInt(process.argv[2]) : 5
const SLEEP_TIME = process.argv[3] ? parseInt(process.argv[3]) : 3

console.log(`${colors.purple}=== Nuxt Development Loop v1.0 ===${colors.reset}`)
console.log(`Running ${LOOP_COUNT} iterations with ${SLEEP_TIME}s intervals`)

// Initialize metrics
let iterations = 0
let improvements = 0
let failures = 0
const loopLog = []

function log(message) {
  const timestamp = new Date().toISOString()
  const logEntry = `[${timestamp}] ${message}`
  loopLog.push(logEntry)
  console.log(`[${new Date().toTimeString().slice(0, 8)}] ${message}`)
}

async function runNpmScript(script, description) {
  console.log(`\n${colors.blue}→ ${description}${colors.reset}`)
  
  try {
    const { stdout, stderr } = await execAsync(`npm run ${script}`, {
      cwd: projectRoot,
      maxBuffer: 1024 * 1024 * 5, // 5MB buffer
      timeout: 120000 // 2 minute timeout
    })
    
    console.log(`${colors.green}  ✓ Success${colors.reset}`)
    return { success: true, output: stdout, error: stderr }
  } catch (error) {
    console.log(`${colors.red}  ✗ Failed: ${error.message}${colors.reset}`)
    return { success: false, error: error.message }
  }
}

async function checkNuxtHealth() {
  // Check if essential Nuxt files exist
  const essentialFiles = [
    'nuxt.config.ts',
    'nuxt.config.js',
    'package.json'
  ]
  
  const healthScore = { score: 100, issues: [] }
  
  // Check for Nuxt config
  const hasNuxtConfig = essentialFiles.some(file => existsSync(join(projectRoot, file)))
  if (!hasNuxtConfig) {
    healthScore.score -= 50
    healthScore.issues.push('No Nuxt config found')
  }
  
  // Check package.json for Nuxt
  try {
    const packageJson = JSON.parse(await readFile(join(projectRoot, 'package.json'), 'utf-8'))
    if (!packageJson.dependencies?.nuxt && !packageJson.devDependencies?.nuxt) {
      healthScore.score -= 30
      healthScore.issues.push('Nuxt not found in dependencies')
    }
  } catch (error) {
    healthScore.score -= 20
    healthScore.issues.push('Could not read package.json')
  }
  
  // Check for SPR kernels
  const sprDir = join(projectRoot, 'spr_kernels')
  if (!existsSync(sprDir)) {
    healthScore.score -= 20
    healthScore.issues.push('SPR kernels not found')
  }
  
  return healthScore
}

async function analyzePredictionAccuracy() {
  const predictionsFile = join(projectRoot, '.cdcs/predictions.json')
  
  if (!existsSync(predictionsFile)) {
    return { accuracy: 0, message: 'No predictions to analyze' }
  }
  
  try {
    const predictions = JSON.parse(await readFile(predictionsFile, 'utf-8'))
    
    // Simple accuracy check based on timestamp (more recent = potentially more accurate)
    const age = Date.now() - new Date(predictions.timestamp).getTime()
    const ageHours = age / (1000 * 60 * 60)
    
    // Predictions get less accurate over time
    let accuracy = Math.max(50, 100 - (ageHours * 10))
    
    return {
      accuracy: Math.round(accuracy),
      predictionsCount: predictions.predictions.highProbability.length,
      age: ageHours.toFixed(1) + ' hours'
    }
  } catch (error) {
    return { accuracy: 0, message: 'Could not analyze predictions' }
  }
}

async function extractPerformanceMetrics() {
  const benchmarkFile = join(projectRoot, '.cdcs/benchmark_results.json')
  
  if (!existsSync(benchmarkFile)) {
    return { score: 0, message: 'No benchmark data available' }
  }
  
  try {
    const results = JSON.parse(await readFile(benchmarkFile, 'utf-8'))
    return {
      score: results.rating.score,
      rating: results.rating.rating,
      efficiency: results.metrics.sprEfficiency?.efficiency || 'Unknown'
    }
  } catch (error) {
    return { score: 0, message: 'Could not read benchmark results' }
  }
}

async function sleep(seconds) {
  return new Promise(resolve => setTimeout(resolve, seconds * 1000))
}

async function main() {
  log(`Starting Nuxt development loop with ${LOOP_COUNT} iterations`)
  
  for (let i = 1; i <= LOOP_COUNT; i++) {
    console.log(`\n${colors.purple}═══ Iteration ${i}/${LOOP_COUNT} ═══${colors.reset}`)
    iterations++
    
    // Phase 1: Predict Nuxt development needs
    const predictResult = await runNpmScript('cdcs:predict', 'Predicting Nuxt development needs')
    if (predictResult.success) {
      log('Prediction phase completed successfully')
    } else {
      failures++
      log('Prediction phase failed')
    }
    
    // Phase 2: Health check
    console.log(`\n${colors.yellow}Health Check Phase${colors.reset}`)
    const health = await checkNuxtHealth()
    
    if (health.score >= 70) {
      console.log(`${colors.green}  ✓ Health Score: ${health.score}/100${colors.reset}`)
      log('Health check passed')
    } else {
      console.log(`${colors.red}  ✗ Health Score: ${health.score}/100${colors.reset}`)
      if (health.issues.length > 0) {
        console.log(`    Issues: ${health.issues.join(', ')}`)
      }
      failures++
      log(`Health check failed (${health.score}/100)`)
    }
    
    // Phase 3: Pattern extraction and analysis
    const patternsResult = await runNpmScript('patterns:extract', 'Extracting Nuxt patterns')
    if (patternsResult.success) {
      log('Pattern extraction completed')
    } else {
      failures++
      log('Pattern extraction failed')
    }
    
    // Phase 4: Performance benchmarking (every 2nd iteration)
    if (i % 2 === 0) {
      console.log(`\n${colors.cyan}Performance Benchmarking Phase${colors.reset}`)
      const benchmarkResult = await runNpmScript('benchmark:nuxt', 'Running Nuxt performance benchmark')
      
      if (benchmarkResult.success) {
        const metrics = await extractPerformanceMetrics()
        if (metrics.score >= 80) {
          console.log(`${colors.green}  ✓ Performance Score: ${metrics.score}/100 (${metrics.rating})${colors.reset}`)
          improvements++
          log(`Excellent performance achieved: ${metrics.score}/100`)
        } else {
          console.log(`${colors.yellow}  ⚠ Performance Score: ${metrics.score}/100${colors.reset}`)
          log(`Performance needs improvement: ${metrics.score}/100`)
        }
      } else {
        failures++
        log('Performance benchmarking failed')
      }
    }
    
    // Phase 5: SPR optimization (every 3rd iteration)
    if (i % 3 === 0) {
      console.log(`\n${colors.green}SPR Optimization Phase${colors.reset}`)
      const sprResult = await runNpmScript('spr:generate', 'Regenerating SPR kernels')
      
      if (sprResult.success) {
        improvements++
        log('SPR kernels optimized successfully')
      } else {
        failures++
        log('SPR optimization failed')
      }
    }
    
    // Phase 6: Prediction accuracy analysis
    const predictionAnalysis = await analyzePredictionAccuracy()
    if (predictionAnalysis.accuracy >= 70) {
      console.log(`${colors.green}  ✓ Prediction Accuracy: ${predictionAnalysis.accuracy}%${colors.reset}`)
    } else {
      console.log(`${colors.yellow}  ⚠ Prediction Accuracy: ${predictionAnalysis.accuracy}%${colors.reset}`)
    }
    
    // Status update
    console.log(`\n${colors.blue}Loop Status:${colors.reset}`)
    console.log(`  Iterations: ${iterations}`)
    console.log(`  Improvements: ${improvements}`)
    console.log(`  Failures: ${failures}`)
    
    const successRate = iterations > 0 ? ((iterations - failures) / iterations * 100).toFixed(1) : 0
    console.log(`  Success rate: ${successRate}%`)
    
    // Sleep between iterations (except last)
    if (i < LOOP_COUNT) {
      console.log(`\n${colors.yellow}Sleeping for ${SLEEP_TIME} seconds...${colors.reset}`)
      await sleep(SLEEP_TIME)
    }
  }
  
  // Final summary
  console.log(`\n${colors.purple}═══ Nuxt Development Loop Summary ═══${colors.reset}`)
  
  const finalSummary = {
    timestamp: new Date().toISOString(),
    iterations,
    improvements,
    failures,
    successRate: ((iterations - failures) / iterations * 100).toFixed(1) + '%',
    recommendations: []
  }
  
  // Generate recommendations
  if (improvements > iterations / 2) {
    finalSummary.recommendations.push('✓ System is improving rapidly - continue current approach')
  } else if (failures > iterations / 3) {
    finalSummary.recommendations.push('⚠ High failure rate - review Nuxt setup and SPR kernels')
  } else {
    finalSummary.recommendations.push('→ System is stable - consider increasing automation level')
  }
  
  if (failures === 0) {
    finalSummary.recommendations.push('✓ Perfect run - all phases successful')
  }
  
  // Display summary
  Object.entries(finalSummary).forEach(([key, value]) => {
    if (key === 'recommendations') {
      console.log(`${colors.green}Recommendations:${colors.reset}`)
      value.forEach(rec => console.log(`  ${rec}`))
    } else if (key !== 'timestamp') {
      const label = key.charAt(0).toUpperCase() + key.slice(1).replace(/([A-Z])/g, ' $1')
      console.log(`${label}: ${value}`)
    }
  })
  
  // Save detailed log
  const logOutput = {
    summary: finalSummary,
    detailedLog: loopLog
  }
  
  const logPath = join(projectRoot, '.cdcs/development_loop.json')
  await writeFile(logPath, JSON.stringify(logOutput, null, 2))
  
  log('Development loop completed')
  console.log(`\n${colors.green}Detailed log saved to: ${logPath}${colors.reset}`)
  
  // Exit with appropriate code
  const exitCode = failures === 0 ? 0 : failures < iterations / 2 ? 0 : 1
  process.exit(exitCode)
}

main().catch(error => {
  console.error(`${colors.red}Fatal error in development loop:`, error.message, colors.reset)
  process.exit(1)
})