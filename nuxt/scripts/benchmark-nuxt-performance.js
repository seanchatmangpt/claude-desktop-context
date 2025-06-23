#!/usr/bin/env node
/**
 * benchmark-nuxt-performance.js - Comprehensive Nuxt.js performance benchmarking
 * Measures build time, bundle size, lighthouse scores, and SPR efficiency
 */

import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { exec } from 'child_process'
import { promisify } from 'util'
import { readFile, writeFile, stat } from 'fs/promises'
import { existsSync } from 'fs'

const execAsync = promisify(exec)
const __dirname = dirname(fileURLToPath(import.meta.url))
const projectRoot = join(__dirname, '..')

// Colors for console output
const colors = {
  blue: '\x1b[34m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  red: '\x1b[31m',
  reset: '\x1b[0m'
}

console.log(`${colors.blue}=== Nuxt Performance Benchmarking ===${colors.reset}`)

async function measureBuildTime() {
  console.log(`${colors.green}Measuring build performance...${colors.reset}`)
  
  try {
    const startTime = Date.now()
    
    // Clean previous build
    await execAsync('rm -rf .nuxt .output', { cwd: projectRoot }).catch(() => {})
    
    // Run build
    const { stdout, stderr } = await execAsync('npm run build', { 
      cwd: projectRoot,
      maxBuffer: 1024 * 1024 * 10 // 10MB buffer
    })
    
    const buildTime = Date.now() - startTime
    
    return {
      buildTime: buildTime,
      buildTimeSeconds: (buildTime / 1000).toFixed(2),
      success: true,
      output: stdout
    }
  } catch (error) {
    return {
      buildTime: null,
      success: false,
      error: error.message
    }
  }
}

async function analyzeBundleSize() {
  console.log(`${colors.green}Analyzing bundle size...${colors.reset}`)
  
  try {
    const outputDir = join(projectRoot, '.output')
    
    if (!existsSync(outputDir)) {
      return { error: 'Build output not found. Run build first.' }
    }
    
    // Get total size of .output directory
    const { stdout } = await execAsync(`du -sh ${outputDir}`)
    const totalSize = stdout.trim().split('\t')[0]
    
    // Analyze specific bundle files
    const publicDir = join(outputDir, 'public')
    const serverDir = join(outputDir, 'server')
    
    let clientSize = 'N/A'
    let serverSize = 'N/A'
    
    if (existsSync(publicDir)) {
      const { stdout: clientOut } = await execAsync(`du -sh ${publicDir}`)
      clientSize = clientOut.trim().split('\t')[0]
    }
    
    if (existsSync(serverDir)) {
      const { stdout: serverOut } = await execAsync(`du -sh ${serverDir}`)
      serverSize = serverOut.trim().split('\t')[0]
    }
    
    return {
      totalSize,
      clientSize,
      serverSize,
      success: true
    }
  } catch (error) {
    return {
      error: error.message,
      success: false
    }
  }
}

async function measureSPREfficiency() {
  console.log(`${colors.green}Measuring SPR efficiency...${colors.reset}`)
  
  try {
    const sprDir = join(projectRoot, 'spr_kernels')
    
    if (!existsSync(sprDir)) {
      return { error: 'SPR kernels not found' }
    }
    
    // Calculate SPR kernel sizes
    const kernelFiles = ['nuxt_component_architecture.spr', 'nuxt_api_patterns.spr', 'nuxt_performance_optimization.spr']
    let totalSprSize = 0
    let totalConcepts = 0
    
    for (const kernelFile of kernelFiles) {
      const kernelPath = join(sprDir, kernelFile)
      if (existsSync(kernelPath)) {
        const stats = await stat(kernelPath)
        const content = await readFile(kernelPath, 'utf-8')
        const concepts = (content.match(/^-/gm) || []).length
        
        totalSprSize += stats.size
        totalConcepts += concepts
      }
    }
    
    // Estimate equivalent file reading (typical Nuxt project analysis)
    const estimatedFileSize = 150 * 1024 // ~150KB of files typically read
    const compressionRatio = (totalSprSize / estimatedFileSize).toFixed(3)
    const efficiency = ((1 - compressionRatio) * 100).toFixed(1)
    
    // Estimate token counts (rough approximation: 1 token ≈ 4 chars)
    const sprTokens = Math.ceil(totalSprSize / 4)
    const fileTokens = Math.ceil(estimatedFileSize / 4)
    const tokenReduction = ((1 - sprTokens / fileTokens) * 100).toFixed(1)
    
    return {
      totalSprSize: (totalSprSize / 1024).toFixed(1) + 'KB',
      totalConcepts,
      compressionRatio,
      efficiency: efficiency + '%',
      sprTokens,
      fileTokens,
      tokenReduction: tokenReduction + '%',
      success: true
    }
  } catch (error) {
    return {
      error: error.message,
      success: false
    }
  }
}

async function runLighthouseAudit() {
  console.log(`${colors.green}Running Lighthouse audit...${colors.reset}`)
  
  try {
    // Check if lighthouse is available
    await execAsync('which lighthouse')
    
    // Start dev server in background
    const devServer = exec('npm run dev', { cwd: projectRoot })
    
    // Wait for server to start
    await new Promise(resolve => setTimeout(resolve, 10000))
    
    // Run lighthouse
    const { stdout } = await execAsync(
      'lighthouse http://localhost:3000 --output=json --quiet --chrome-flags="--headless --no-sandbox"',
      { maxBuffer: 1024 * 1024 * 5 }
    )
    
    // Kill dev server
    devServer.kill()
    
    const report = JSON.parse(stdout)
    
    return {
      performance: Math.round(report.lhr.categories.performance.score * 100),
      accessibility: Math.round(report.lhr.categories.accessibility.score * 100),
      bestPractices: Math.round(report.lhr.categories['best-practices'].score * 100),
      seo: Math.round(report.lhr.categories.seo.score * 100),
      success: true
    }
  } catch (error) {
    return {
      error: 'Lighthouse not available or server failed to start',
      success: false
    }
  }
}

export async function analyzeApiPerformance(testRoot = projectRoot) {
  const apiDir = join(testRoot, 'server/api')
  
  if (!existsSync(apiDir)) {
    return { message: 'No API routes found', success: false }
  }
  
  try {
    // Count API routes
    const { stdout } = await execAsync(`find ${apiDir} -name "*.ts" -o -name "*.js" | wc -l`)
    const apiCount = parseInt(stdout.trim())
    
    // Basic analysis
    return {
      apiRouteCount: apiCount,
      status: apiCount > 0 ? 'API routes detected' : 'No API routes',
      recommendation: apiCount > 5 ? 'Consider middleware optimization' : 'Good API structure',
      success: true
    }
  } catch (error) {
    return {
      error: error.message,
      success: false
    }
  }
}

export function calculatePerformanceRating(metrics) {
  let score = 100
  let rating = '★★★★★'
  
  // Build time scoring
  if (metrics.buildTime && metrics.buildTime.success) {
    const buildSeconds = parseFloat(metrics.buildTime.buildTimeSeconds)
    if (buildSeconds > 60) score -= 20
    else if (buildSeconds > 30) score -= 10
  }
  
  // Lighthouse scoring
  if (metrics.lighthouse && metrics.lighthouse.success) {
    const avgScore = (metrics.lighthouse.performance + metrics.lighthouse.accessibility + 
                     metrics.lighthouse.bestPractices + metrics.lighthouse.seo) / 4
    if (avgScore < 70) score -= 30
    else if (avgScore < 85) score -= 15
  }
  
  // SPR efficiency scoring
  if (metrics.sprEfficiency && metrics.sprEfficiency.success) {
    const efficiency = parseFloat(metrics.sprEfficiency.efficiency)
    if (efficiency < 70) score -= 20
    else if (efficiency < 80) score -= 10
  }
  
  // Determine rating
  if (score >= 95) rating = '★★★★★ Excellent'
  else if (score >= 80) rating = '★★★★☆ Good'
  else if (score >= 65) rating = '★★★☆☆ Fair'
  else if (score >= 50) rating = '★★☆☆☆ Poor'
  else rating = '★☆☆☆☆ Needs Work'
  
  return { score, rating }
}

async function saveBenchmarkResults(metrics, rating) {
  const results = {
    timestamp: new Date().toISOString(),
    metrics,
    rating,
    recommendations: [],
    nextSteps: []
  }
  
  // Generate recommendations
  if (metrics.buildTime && metrics.buildTime.success && parseFloat(metrics.buildTime.buildTimeSeconds) > 30) {
    results.recommendations.push('Optimize build time with better caching or fewer dependencies')
  }
  
  if (metrics.sprEfficiency && metrics.sprEfficiency.success && parseFloat(metrics.sprEfficiency.efficiency) > 90) {
    results.recommendations.push('Excellent SPR efficiency - continue using SPR-first approach')
  }
  
  if (metrics.lighthouse && metrics.lighthouse.success && metrics.lighthouse.performance < 90) {
    results.recommendations.push('Improve performance score with lazy loading and optimization')
  }
  
  // Next steps
  results.nextSteps = [
    'Run npm run auto:optimize to apply performance improvements',
    'Use npm run spr:evolve to enhance SPR kernels',
    'Monitor metrics with npm run loop:continuous'
  ]
  
  const outputPath = join(projectRoot, '.cdcs/benchmark_results.json')
  await writeFile(outputPath, JSON.stringify(results, null, 2))
  
  return outputPath
}

async function main() {
  try {
    const metrics = {}
    
    // Run all benchmarks
    metrics.buildTime = await measureBuildTime()
    metrics.bundleSize = await analyzeBundleSize()
    metrics.sprEfficiency = await measureSPREfficiency()
    metrics.apiPerformance = await analyzeApiPerformance()
    
    // Run lighthouse if available
    console.log(`${colors.yellow}Note: Lighthouse audit may take a while...${colors.reset}`)
    metrics.lighthouse = await runLighthouseAudit()
    
    // Calculate overall rating
    const rating = calculatePerformanceRating(metrics)
    
    // Display results
    console.log(`${colors.cyan}=== Benchmark Results ===${colors.reset}`)
    
    if (metrics.buildTime.success) {
      console.log(`Build Time: ${metrics.buildTime.buildTimeSeconds}s`)
    }
    
    if (metrics.bundleSize.success) {
      console.log(`Bundle Size: ${metrics.bundleSize.totalSize} (Client: ${metrics.bundleSize.clientSize}, Server: ${metrics.bundleSize.serverSize})`)
    }
    
    if (metrics.sprEfficiency.success) {
      console.log(`SPR Efficiency: ${metrics.sprEfficiency.efficiency} (${metrics.sprEfficiency.tokenReduction} token reduction)`)
      console.log(`SPR Kernels: ${metrics.sprEfficiency.totalSprSize} with ${metrics.sprEfficiency.totalConcepts} concepts`)
    }
    
    if (metrics.lighthouse.success) {
      console.log(`Lighthouse Scores: Performance: ${metrics.lighthouse.performance}, Accessibility: ${metrics.lighthouse.accessibility}, Best Practices: ${metrics.lighthouse.bestPractices}, SEO: ${metrics.lighthouse.seo}`)
    }
    
    if (metrics.apiPerformance.success) {
      console.log(`API Routes: ${metrics.apiPerformance.apiRouteCount} (${metrics.apiPerformance.recommendation})`)
    }
    
    console.log(`${colors.green}Overall Rating: ${rating.rating} (${rating.score}/100)${colors.reset}`)
    
    // Save results
    const savedPath = await saveBenchmarkResults(metrics, rating)
    console.log(`${colors.green}Benchmark results saved to: ${savedPath}${colors.reset}`)
    
  } catch (error) {
    console.error(`${colors.red}Error during benchmarking:`, error.message, colors.reset)
    process.exit(1)
  }
}

main().catch(console.error)