#!/usr/bin/env node
/**
 * predict-nuxt-needs.js - Anticipate Nuxt developer needs using pattern analysis
 * Equivalent to CDCS auto-predict for Nuxt-specific development
 */

import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { readdir, readFile, writeFile, stat } from 'fs/promises'
import { existsSync } from 'fs'

const __dirname = dirname(fileURLToPath(import.meta.url))
const projectRoot = join(__dirname, '..')

// Colors for console output
const colors = {
  blue: '\x1b[34m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  reset: '\x1b[0m'
}

console.log(`${colors.blue}=== Nuxt Development Needs Prediction ===${colors.reset}`)

async function analyzeProjectStructure() {
  const analysis = {
    hasPages: existsSync(join(projectRoot, 'pages')),
    hasComponents: existsSync(join(projectRoot, 'components')),
    hasComposables: existsSync(join(projectRoot, 'composables')),
    hasServerApi: existsSync(join(projectRoot, 'server/api')),
    hasLayouts: existsSync(join(projectRoot, 'layouts')),
    hasPlugins: existsSync(join(projectRoot, 'plugins')),
    hasMiddleware: existsSync(join(projectRoot, 'middleware'))
  }

  // Count files in each directory
  if (analysis.hasPages) {
    const pageFiles = await readdir(join(projectRoot, 'pages')).catch(() => [])
    analysis.pageCount = pageFiles.length
  }

  if (analysis.hasComponents) {
    const componentFiles = await readdir(join(projectRoot, 'components')).catch(() => [])
    analysis.componentCount = componentFiles.length
  }

  if (analysis.hasServerApi) {
    const apiFiles = await readdir(join(projectRoot, 'server/api')).catch(() => [])
    analysis.apiCount = apiFiles.length
  }

  return analysis
}

async function analyzeRecentActivity() {
  const activity = {
    recentFiles: [],
    modificationPattern: 'unknown'
  }

  try {
    // Check recent file modifications
    const checkDirs = ['pages', 'components', 'composables', 'server/api']
    
    for (const dir of checkDirs) {
      const dirPath = join(projectRoot, dir)
      if (existsSync(dirPath)) {
        const files = await readdir(dirPath)
        for (const file of files) {
          const filePath = join(dirPath, file)
          const stats = await stat(filePath)
          const isRecent = Date.now() - stats.mtime.getTime() < 24 * 60 * 60 * 1000 // 24 hours
          
          if (isRecent) {
            activity.recentFiles.push({
              path: `${dir}/${file}`,
              modified: stats.mtime,
              type: dir
            })
          }
        }
      }
    }

    // Determine modification pattern
    const typeCount = activity.recentFiles.reduce((acc, file) => {
      acc[file.type] = (acc[file.type] || 0) + 1
      return acc
    }, {})

    if (typeCount.components > typeCount.pages) {
      activity.modificationPattern = 'component-focused'
    } else if (typeCount['server/api'] > 0) {
      activity.modificationPattern = 'api-development'
    } else if (typeCount.pages > 0) {
      activity.modificationPattern = 'page-development'
    }

  } catch (error) {
    console.log(`${colors.yellow}Note: Could not analyze recent activity${colors.reset}`)
  }

  return activity
}

function generatePredictions(structure, activity) {
  const predictions = {
    highProbability: [],
    mediumProbability: [],
    lowProbability: []
  }

  // High probability predictions (>80%)
  if (structure.componentCount > 3 && !structure.hasComposables) {
    predictions.highProbability.push({
      need: 'Composable extraction',
      reason: `${structure.componentCount} components likely share logic`,
      action: 'Create composables/ directory and extract shared functionality',
      sprKernel: 'nuxt_component_architecture'
    })
  }

  if (structure.hasServerApi && structure.apiCount > 2) {
    predictions.highProbability.push({
      need: 'API middleware optimization',
      reason: `${structure.apiCount} API routes could benefit from shared middleware`,
      action: 'Implement authentication/validation middleware',
      sprKernel: 'nuxt_api_patterns'
    })
  }

  if (structure.pageCount > 5 && !structure.hasLayouts) {
    predictions.highProbability.push({
      need: 'Layout system implementation',
      reason: `${structure.pageCount} pages would benefit from shared layouts`,
      action: 'Create layouts/default.vue and page-specific layouts',
      sprKernel: 'nuxt_component_architecture'
    })
  }

  // Medium probability predictions (50-80%)
  if (activity.modificationPattern === 'component-focused') {
    predictions.mediumProbability.push({
      need: 'Component performance optimization',
      reason: 'Heavy component development suggests optimization needs',
      action: 'Implement lazy loading and dynamic imports',
      sprKernel: 'nuxt_performance_optimization'
    })
  }

  if (structure.hasPages && structure.hasServerApi) {
    predictions.mediumProbability.push({
      need: 'State management setup',
      reason: 'Full-stack app likely needs centralized state',
      action: 'Setup Pinia stores for application state',
      sprKernel: 'nuxt_component_architecture'
    })
  }

  // Low probability predictions (20-50%)
  if (!structure.hasMiddleware && structure.hasServerApi) {
    predictions.lowProbability.push({
      need: 'Authentication middleware',
      reason: 'API routes often need authentication',
      action: 'Implement route protection middleware',
      sprKernel: 'nuxt_api_patterns'
    })
  }

  return predictions
}

async function generateSPRRecommendations(predictions) {
  const recommendations = []

  // Determine which SPR kernels to activate
  const kernelNeeds = new Set()
  
  predictions.highProbability.forEach(pred => kernelNeeds.add(pred.sprKernel))
  predictions.mediumProbability.forEach(pred => kernelNeeds.add(pred.sprKernel))

  if (kernelNeeds.has('nuxt_component_architecture')) {
    recommendations.push({
      action: 'Activate nuxt_component_architecture.spr',
      reason: 'Component/layout development patterns detected',
      command: 'npm run spr:activate component_architecture'
    })
  }

  if (kernelNeeds.has('nuxt_api_patterns')) {
    recommendations.push({
      action: 'Activate nuxt_api_patterns.spr',
      reason: 'API development patterns detected',
      command: 'npm run spr:activate api_patterns'
    })
  }

  if (kernelNeeds.has('nuxt_performance_optimization')) {
    recommendations.push({
      action: 'Activate nuxt_performance_optimization.spr',
      reason: 'Performance optimization opportunities identified',
      command: 'npm run spr:activate performance_optimization'
    })
  }

  return recommendations
}

async function savePredictions(predictions, sprRecommendations) {
  const output = {
    timestamp: new Date().toISOString(),
    predictions,
    sprRecommendations,
    nextActions: [
      'Run npm run auto:focus to activate relevant SPR kernels',
      'Consider implementing highest probability predictions first',
      'Use npm run patterns:extract after implementing changes'
    ]
  }

  const outputPath = join(__dirname, '../.cdcs/predictions.json')
  await writeFile(outputPath, JSON.stringify(output, null, 2))
  
  return outputPath
}

async function main() {
  try {
    console.log(`${colors.green}1. Analyzing project structure...${colors.reset}`)
    const structure = await analyzeProjectStructure()
    
    console.log(`${colors.green}2. Analyzing recent development activity...${colors.reset}`)
    const activity = await analyzeRecentActivity()
    
    console.log(`${colors.green}3. Generating predictions...${colors.reset}`)
    const predictions = generatePredictions(structure, activity)
    
    console.log(`${colors.green}4. Creating SPR recommendations...${colors.reset}`)
    const sprRecommendations = await generateSPRRecommendations(predictions)
    
    console.log(`${colors.blue}=== Prediction Results ===${colors.reset}`)
    
    if (predictions.highProbability.length > 0) {
      console.log(`${colors.green}High Probability Needs:${colors.reset}`)
      predictions.highProbability.forEach((pred, i) => {
        console.log(`  ${i + 1}. ${pred.need}`)
        console.log(`     Reason: ${pred.reason}`)
        console.log(`     Action: ${pred.action}`)
      })
    }
    
    if (predictions.mediumProbability.length > 0) {
      console.log(`${colors.yellow}Medium Probability Needs:${colors.reset}`)
      predictions.mediumProbability.forEach((pred, i) => {
        console.log(`  ${i + 1}. ${pred.need}`)
        console.log(`     Action: ${pred.action}`)
      })
    }
    
    if (sprRecommendations.length > 0) {
      console.log(`${colors.blue}SPR Recommendations:${colors.reset}`)
      sprRecommendations.forEach((rec, i) => {
        console.log(`  ${i + 1}. ${rec.action}`)
        console.log(`     Command: ${rec.command}`)
      })
    }
    
    const savedPath = await savePredictions(predictions, sprRecommendations)
    console.log(`${colors.green}Predictions saved to: ${savedPath}${colors.reset}`)
    
  } catch (error) {
    console.error(`${colors.yellow}Error during prediction:`, error.message, colors.reset)
    process.exit(1)
  }
}

// Ensure .cdcs directory exists
import { mkdir } from 'fs/promises'
await mkdir(join(__dirname, '../.cdcs'), { recursive: true })

main().catch(console.error)