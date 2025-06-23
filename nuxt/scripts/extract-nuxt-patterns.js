#!/usr/bin/env node
/**
 * extract-nuxt-patterns.js - Extract and catalog Nuxt.js development patterns
 * Analyzes codebase to identify recurring patterns for SPR optimization
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
  cyan: '\x1b[36m',
  reset: '\x1b[0m'
}

console.log(`${colors.blue}=== Nuxt Pattern Extraction ===${colors.reset}`)

// Pattern detection rules
const patternRules = {
  componentPatterns: {
    sharedProps: /defineProps<.*>/g,
    sharedEmits: /defineEmits<.*>/g,
    composableUsage: /use[A-Z][a-zA-Z]*/g,
    computedProperties: /computed\(/g,
    watchEffects: /watch(Effect)?\(/g
  },
  
  apiPatterns: {
    routeHandlers: /export\s+default\s+defineEventHandler/g,
    middleware: /export\s+default\s+defineNuxtRouteMiddleware/g,
    validation: /z\.(string|number|object|array)/g,
    authChecks: /(jwt|auth|token|session)/gi,
    dbQueries: /(prisma|db|query|select|findMany)/gi
  },
  
  pagePatterns: {
    layoutUsage: /definePageMeta.*layout/g,
    seoMeta: /useSeoMeta|useHead/g,
    dataFetching: /useFetch|useLazyFetch|\$fetch/g,
    navigation: /navigateTo|useRouter/g,
    stateManagement: /useState|usePinia/g
  },
  
  performancePatterns: {
    lazyLoading: /defineAsyncComponent|Suspense/g,
    dynamicImports: /import\(/g,
    imageOptimization: /<NuxtImg|<NuxtPicture/g,
    caching: /cachedFunction|cached/g,
    compression: /compress|gzip|br/g
  }
}

async function scanDirectory(dirPath, fileExtensions = ['.vue', '.ts', '.js']) {
  const files = []
  
  if (!existsSync(dirPath)) {
    return files
  }
  
  try {
    const entries = await readdir(dirPath, { withFileTypes: true })
    
    for (const entry of entries) {
      const fullPath = join(dirPath, entry.name)
      
      if (entry.isDirectory() && !entry.name.startsWith('.')) {
        // Recursively scan subdirectories
        const subFiles = await scanDirectory(fullPath, fileExtensions)
        files.push(...subFiles)
      } else if (entry.isFile()) {
        const hasValidExtension = fileExtensions.some(ext => entry.name.endsWith(ext))
        if (hasValidExtension) {
          files.push(fullPath)
        }
      }
    }
  } catch (error) {
    console.log(`${colors.yellow}Warning: Could not scan ${dirPath}${colors.reset}`)
  }
  
  return files
}

async function analyzeFile(filePath) {
  try {
    const content = await readFile(filePath, 'utf-8')
    const analysis = {
      path: filePath.replace(projectRoot + '/', ''),
      patterns: {},
      size: content.length,
      lines: content.split('\n').length
    }
    
    // Apply pattern rules
    for (const [category, rules] of Object.entries(patternRules)) {
      analysis.patterns[category] = {}
      
      for (const [patternName, regex] of Object.entries(rules)) {
        const matches = content.match(regex) || []
        if (matches.length > 0) {
          analysis.patterns[category][patternName] = {
            count: matches.length,
            examples: matches.slice(0, 3) // Keep first 3 examples
          }
        }
      }
    }
    
    return analysis
  } catch (error) {
    console.log(`${colors.yellow}Warning: Could not analyze ${filePath}${colors.reset}`)
    return null
  }
}

function categorizePatterns(analyses) {
  const categories = {
    component: analyses.filter(a => a.path.includes('components/')),
    page: analyses.filter(a => a.path.includes('pages/')),
    api: analyses.filter(a => a.path.includes('server/api')),
    composable: analyses.filter(a => a.path.includes('composables/')),
    layout: analyses.filter(a => a.path.includes('layouts/')),
    middleware: analyses.filter(a => a.path.includes('middleware/')),
    plugin: analyses.filter(a => a.path.includes('plugins/'))
  }
  
  return categories
}

function detectRecurringPatterns(categorizedAnalyses) {
  const recurringPatterns = {}
  
  for (const [category, analyses] of Object.entries(categorizedAnalyses)) {
    if (analyses.length === 0) continue
    
    recurringPatterns[category] = {}
    
    // Count pattern frequencies across files in this category
    const patternFrequency = {}
    
    analyses.forEach(analysis => {
      for (const [patternCategory, patterns] of Object.entries(analysis.patterns)) {
        for (const [patternName, data] of Object.entries(patterns)) {
          const key = `${patternCategory}.${patternName}`
          if (!patternFrequency[key]) {
            patternFrequency[key] = { files: 0, totalCount: 0, examples: [] }
          }
          patternFrequency[key].files++
          patternFrequency[key].totalCount += data.count
          patternFrequency[key].examples.push(...data.examples)
        }
      }
    })
    
    // Filter for patterns appearing in 3+ files or with high frequency
    for (const [pattern, data] of Object.entries(patternFrequency)) {
      if (data.files >= 3 || data.totalCount >= 5) {
        recurringPatterns[category][pattern] = {
          frequency: data.files,
          totalOccurrences: data.totalCount,
          significance: data.files * data.totalCount,
          examples: [...new Set(data.examples)].slice(0, 5)
        }
      }
    }
  }
  
  return recurringPatterns
}

function generateOptimizationSuggestions(recurringPatterns, categorizedAnalyses) {
  const suggestions = []
  
  // Component optimization suggestions
  if (recurringPatterns.component) {
    const propPatterns = recurringPatterns.component['componentPatterns.sharedProps']
    if (propPatterns && propPatterns.frequency >= 3) {
      suggestions.push({
        type: 'composable_extraction',
        priority: 'high',
        description: `Extract shared props into composable (found in ${propPatterns.frequency} components)`,
        impact: 'Reduce code duplication and improve type safety',
        action: 'Create shared composable for common prop definitions'
      })
    }
    
    const composableUsage = recurringPatterns.component['componentPatterns.composableUsage']
    if (composableUsage && composableUsage.totalOccurrences >= 10) {
      suggestions.push({
        type: 'composable_optimization',
        priority: 'medium',
        description: 'Heavy composable usage detected - consider performance optimization',
        impact: 'Improve component rendering performance',
        action: 'Review composable memoization and reactivity patterns'
      })
    }
  }
  
  // API optimization suggestions
  if (recurringPatterns.api) {
    const authPatterns = recurringPatterns.api['apiPatterns.authChecks']
    if (authPatterns && authPatterns.frequency >= 2) {
      suggestions.push({
        type: 'middleware_extraction',
        priority: 'high',
        description: `Authentication logic found in ${authPatterns.frequency} API routes`,
        impact: 'Centralize auth logic and improve security',
        action: 'Create shared authentication middleware'
      })
    }
    
    const dbPatterns = recurringPatterns.api['apiPatterns.dbQueries']
    if (dbPatterns && dbPatterns.totalOccurrences >= 5) {
      suggestions.push({
        type: 'database_optimization',
        priority: 'medium',
        description: 'Multiple database queries detected',
        impact: 'Optimize query performance and connection pooling',
        action: 'Review database query patterns and implement caching'
      })
    }
  }
  
  // Performance optimization suggestions
  const totalFiles = Object.values(categorizedAnalyses).flat().length
  if (totalFiles > 10) {
    suggestions.push({
      type: 'bundle_optimization',
      priority: 'medium',
      description: `Large codebase (${totalFiles} files) may benefit from optimization`,
      impact: 'Reduce bundle size and improve load times',
      action: 'Implement lazy loading and dynamic imports'
    })
  }
  
  return suggestions
}

async function savePatternAnalysis(recurringPatterns, suggestions, stats) {
  const analysis = {
    timestamp: new Date().toISOString(),
    stats,
    recurringPatterns,
    optimizationSuggestions: suggestions,
    nextSteps: [
      'Review high-priority optimization suggestions',
      'Run npm run auto:optimize to apply improvements',
      'Use npm run spr:generate to update SPR kernels with new patterns'
    ]
  }
  
  const outputPath = join(projectRoot, '.cdcs/pattern_analysis.json')
  await writeFile(outputPath, JSON.stringify(analysis, null, 2))
  
  return outputPath
}

async function main() {
  try {
    console.log(`${colors.green}1. Scanning Nuxt project structure...${colors.reset}`)
    
    // Scan key directories
    const directories = ['components', 'pages', 'server/api', 'composables', 'layouts', 'middleware', 'plugins']
    const allFiles = []
    
    for (const dir of directories) {
      const dirPath = join(projectRoot, dir)
      const files = await scanDirectory(dirPath)
      allFiles.push(...files)
    }
    
    console.log(`Found ${allFiles.length} files to analyze`)
    
    console.log(`${colors.green}2. Analyzing files for patterns...${colors.reset}`)
    const analyses = []
    
    for (const file of allFiles) {
      const analysis = await analyzeFile(file)
      if (analysis) {
        analyses.push(analysis)
      }
    }
    
    console.log(`${colors.green}3. Categorizing and detecting recurring patterns...${colors.reset}`)
    const categorizedAnalyses = categorizePatterns(analyses)
    const recurringPatterns = detectRecurringPatterns(categorizedAnalyses)
    
    console.log(`${colors.green}4. Generating optimization suggestions...${colors.reset}`)
    const suggestions = generateOptimizationSuggestions(recurringPatterns, categorizedAnalyses)
    
    // Display results
    console.log(`${colors.blue}=== Pattern Analysis Results ===${colors.reset}`)
    
    const stats = {
      totalFiles: analyses.length,
      totalPatterns: Object.values(recurringPatterns).reduce((sum, category) => 
        sum + Object.keys(category).length, 0),
      categories: Object.keys(categorizedAnalyses).filter(cat => 
        categorizedAnalyses[cat].length > 0)
    }
    
    console.log(`Files analyzed: ${stats.totalFiles}`)
    console.log(`Recurring patterns found: ${stats.totalPatterns}`)
    console.log(`Active categories: ${stats.categories.join(', ')}`)
    
    if (suggestions.length > 0) {
      console.log(`${colors.cyan}Optimization Opportunities:${colors.reset}`)
      suggestions.forEach((suggestion, i) => {
        console.log(`  ${i + 1}. [${suggestion.priority.toUpperCase()}] ${suggestion.description}`)
        console.log(`     Impact: ${suggestion.impact}`)
        console.log(`     Action: ${suggestion.action}`)
      })
    } else {
      console.log(`${colors.green}No major optimization opportunities detected${colors.reset}`)
    }
    
    // Save analysis
    const savedPath = await savePatternAnalysis(recurringPatterns, suggestions, stats)
    console.log(`${colors.green}Analysis saved to: ${savedPath}${colors.reset}`)
    
  } catch (error) {
    console.error(`${colors.yellow}Error during pattern extraction:`, error.message, colors.reset)
    process.exit(1)
  }
}

main().catch(console.error)