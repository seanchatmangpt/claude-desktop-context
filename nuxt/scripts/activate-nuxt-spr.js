#!/usr/bin/env node
/**
 * activate-nuxt-spr.js - Activate specific Nuxt SPR kernels for instant context
 * Nuxt equivalent of the CDCS SPR activation system
 */

import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { readFile, writeFile } from 'fs/promises'
import { existsSync } from 'fs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const projectRoot = join(__dirname, '..')
const sprDir = join(projectRoot, 'spr_kernels')

// Colors for console output
const colors = {
  blue: '\x1b[34m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  red: '\x1b[31m',
  reset: '\x1b[0m'
}

// Get kernel name from command line argument
const kernelName = process.argv[2]

if (!kernelName) {
  console.error(`${colors.red}Error: No kernel specified${colors.reset}`)
  console.log('Usage: npm run spr:activate <kernel_name>')
  console.log('Available kernels:')
  console.log('  - component_architecture')
  console.log('  - api_patterns')
  console.log('  - performance_optimization')
  process.exit(1)
}

console.log(`${colors.blue}=== Nuxt SPR Kernel Activation ===${colors.reset}`)
console.log(`Target kernel: ${kernelName}`)

async function loadKernel(kernelName) {
  const kernelFile = join(sprDir, `nuxt_${kernelName}.spr`)
  
  if (!existsSync(kernelFile)) {
    throw new Error(`Kernel not found: ${kernelFile}`)
  }
  
  const content = await readFile(kernelFile, 'utf-8')
  return { content, file: kernelFile }
}

function analyzeKernel(content) {
  const lines = content.split('\n')
  const concepts = lines.filter(line => line.trim().startsWith('-')).length
  const sections = lines.filter(line => line.trim().startsWith('##')).length
  const size = Buffer.byteLength(content, 'utf-8')
  
  return { concepts, sections, size }
}

function extractKeyPatterns(content) {
  const patterns = []
  const lines = content.split('\n')
  
  lines.forEach(line => {
    const trimmed = line.trim()
    if (trimmed.startsWith('-') && trimmed.includes(':')) {
      const pattern = trimmed.substring(1).trim()
      patterns.push(pattern)
    }
  })
  
  return patterns.slice(0, 8) // Top 8 patterns
}

function extractGraphConnections(content) {
  const connections = []
  const lines = content.split('\n')
  
  lines.forEach(line => {
    if (line.includes('→') || line.includes('->')) {
      connections.push(line.trim())
    }
  })
  
  return connections
}

async function logActivation(kernelName, stats) {
  const logEntry = {
    timestamp: new Date().toISOString(),
    kernel: kernelName,
    stats,
    activated: true
  }
  
  const logFile = join(projectRoot, '.cdcs/activation_log.json')
  let log = []
  
  try {
    if (existsSync(logFile)) {
      const existingLog = await readFile(logFile, 'utf-8')
      log = JSON.parse(existingLog)
    }
  } catch (error) {
    // Start fresh if log is corrupted
    log = []
  }
  
  log.push(logEntry)
  
  // Keep only last 50 entries
  if (log.length > 50) {
    log = log.slice(-50)
  }
  
  await writeFile(logFile, JSON.stringify(log, null, 2))
}

async function createActivationMarker(kernelName) {
  const markerFile = join(projectRoot, '.cdcs/active_kernel.txt')
  await writeFile(markerFile, kernelName)
}

function getKernelDescription(kernelName) {
  const descriptions = {
    component_architecture: 'Component composition, routing, SSR patterns, and auto-imports',
    api_patterns: 'Server-side API development, middleware, authentication, and database integration',
    performance_optimization: 'Bundle optimization, image handling, SSR performance, and monitoring'
  }
  
  return descriptions[kernelName] || 'Nuxt.js development patterns'
}

function calculateTokenSavings(stats) {
  // Approximate token calculation (1 token ≈ 4 characters)
  const sprTokens = Math.ceil(stats.size / 4)
  
  // Estimate equivalent file reading (50+ files × 2KB average = ~100KB)
  const equivalentFileTokens = Math.ceil(100 * 1024 / 4) // ~25,600 tokens
  
  const tokenSavings = equivalentFileTokens - sprTokens
  const efficiencyGain = ((tokenSavings / equivalentFileTokens) * 100).toFixed(1)
  
  return { sprTokens, equivalentFileTokens, tokenSavings, efficiencyGain }
}

async function main() {
  try {
    // Load the SPR kernel
    console.log(`${colors.green}Loading kernel contents...${colors.reset}`)
    const kernel = await loadKernel(kernelName)
    
    // Analyze kernel structure
    const stats = analyzeKernel(kernel.content)
    console.log('Kernel stats:')
    console.log(`  Size: ${(stats.size / 1024).toFixed(1)}KB`)
    console.log(`  Sections: ${stats.sections}`)
    console.log(`  Concepts: ${stats.concepts}`)
    
    // Extract and display key patterns
    console.log(`${colors.green}Activating concepts:${colors.reset}`)
    const patterns = extractKeyPatterns(kernel.content)
    patterns.forEach(pattern => {
      console.log(`  ✓ ${pattern}`)
    })
    
    // Check for graph connections
    const connections = extractGraphConnections(kernel.content)
    if (connections.length > 0) {
      console.log(`${colors.green}Pattern graph connections:${colors.reset}`)
      connections.slice(0, 3).forEach(connection => {
        console.log(`  ${connection}`)
      })
    }
    
    // Calculate efficiency gains
    const tokenInfo = calculateTokenSavings(stats)
    
    // Log activation
    await logActivation(kernelName, stats)
    await createActivationMarker(kernelName)
    
    // Display activation summary
    console.log(`${colors.blue}=== Activation Summary ===${colors.reset}`)
    console.log(`Kernel: nuxt_${kernelName}`)
    console.log(`Status: ACTIVE`)
    console.log(`Description: ${getKernelDescription(kernelName)}`)
    console.log(`Concepts loaded: ${stats.concepts}`)
    console.log(`Token efficiency: ${tokenInfo.efficiencyGain}% (${tokenInfo.sprTokens} vs ${tokenInfo.equivalentFileTokens})`)
    console.log(`Ready for: Nuxt.js development with ${kernelName} context`)
    
    // Provide usage recommendations
    console.log(`${colors.yellow}Recommended next steps:${colors.reset}`)
    switch (kernelName) {
      case 'component_architecture':
        console.log('  • Review component structure and extract shared composables')
        console.log('  • Optimize SSR/SPA rendering strategies')
        console.log('  • Implement proper layout hierarchy')
        break
      case 'api_patterns':
        console.log('  • Implement API middleware for authentication/validation')
        console.log('  • Optimize database queries and caching')
        console.log('  • Add proper error handling and logging')
        break
      case 'performance_optimization':
        console.log('  • Run lighthouse audit: npm run benchmark:lighthouse')
        console.log('  • Analyze bundle size: npm run benchmark:bundle')
        console.log('  • Optimize images and lazy loading')
        break
    }
    
    console.log(`${colors.green}Kernel ${kernelName} successfully activated${colors.reset}`)
    
  } catch (error) {
    console.error(`${colors.red}Error activating kernel:`, error.message, colors.reset)
    process.exit(1)
  }
}

main().catch(console.error)