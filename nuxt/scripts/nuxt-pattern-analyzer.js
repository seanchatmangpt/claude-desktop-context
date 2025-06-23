#!/usr/bin/env node
/**
 * nuxt-pattern-analyzer.js - Advanced Nuxt-specific pattern analysis
 * Detects 80% use case patterns that real Nuxt developers encounter
 */

import { fileURLToPath } from 'url'
import { dirname, join } from 'path'
import { readFile, readdir, writeFile } from 'fs/promises'
import { existsSync } from 'fs'

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

console.log(`${colors.blue}=== Nuxt Core Team Pattern Analysis ===${colors.reset}`)

// Enhanced pattern rules for real Nuxt development patterns
const nuxtCorePatterns = {
  // 80% Module Usage Patterns
  modulePatterns: {
    tailwindcss: /@nuxtjs\/tailwindcss|@tailwindcss/g,
    pinia: /@pinia\/nuxt|usePiniaStore|defineStore/g,
    content: /@nuxt\/content|queryContent|parseContent/g,
    image: /@nuxt\/image|<NuxtImg|<NuxtPicture/g,
    seo: /@nuxtjs\/seo|useSeoMeta|useHead/g,
    auth: /@sidebase\/nuxt-auth|@nuxtjs\/supabase|useAuth/g,
    ui: /@nuxt\/ui|@headlessui\/vue|@heroicons/g,
    analytics: /@nuxtjs\/google-analytics|@nuxtjs\/plausible/g
  },

  // SSR/Hydration Critical Patterns
  ssrPatterns: {
    clientOnly: /<ClientOnly|clientOnly|process\.client/g,
    hydrationMismatch: /window\.|document\.|localStorage|sessionStorage/g,
    ssrDataFetch: /useFetch|useLazyFetch|$fetch/g,
    stateHydration: /useState|refreshCookie|navigateTo/g,
    asyncComponents: /defineAsyncComponent|lazy:\s*true/g
  },

  // Auto-import Optimization Patterns
  autoImportPatterns: {
    composableUsage: /use[A-Z][a-zA-Z]+/g,
    componentImports: /import.*from.*components/g,
    utilsImports: /import.*from.*utils/g,
    explicitImports: /import\s*{[^}]+}\s*from\s*['"][^'"]+['"]/g,
    autoImportConflicts: /#imports|\/\*\s*@vite-ignore\s*\*\//g
  },

  // SEO and Meta Patterns (80% of production apps)
  seoPatterns: {
    metaManagement: /useSeoMeta|useHead|definePageMeta/g,
    openGraph: /og:|twitter:|property=["']og:/g,
    structuredData: /application\/ld\+json|schema\.org/g,
    canonicalUrls: /rel=["']canonical|canonical:/g,
    dynamicMeta: /title:|description:|keywords:/g
  },

  // Performance Critical Patterns
  performancePatterns: {
    lazyLoading: /lazy|defineAsyncComponent|v-lazy/g,
    imageOptimization: /<NuxtImg|loading=["']lazy|sizes=/g,
    bundleOptimization: /dynamic.*import|import\(/g,
    caching: /cachedFunction|cached|stale-while-revalidate/g,
    criticalCSS: /critical|inline.*css|preload/g
  },

  // Error Handling Patterns
  errorPatterns: {
    errorBoundaries: /onErrorCaptured|errorCaptured/g,
    errorPages: /error\.vue|\/error\//g,
    tryHydrationFix: /\$el\.|clientOnly.*fallback/g,
    apiErrorHandling: /createError|throw.*Error|\.catch/g,
    validationErrors: /zod|yup|vee-validate|@vueuse\/schema/g
  },

  // State Management Decision Patterns
  statePatterns: {
    useState: /useState\(/g,
    piniaStores: /defineStore|usePiniaStore|storeToRefs/g,
    globalState: /provide|inject|createGlobalState/g,
    sessionState: /sessionStorage|refreshCookie/g,
    temporaryState: /ref\(|reactive\(|computed\(/g
  }
}

async function analyzeNuxtProject() {
  console.log(`${colors.green}1. Analyzing Nuxt project structure...${colors.reset}`)
  
  const analysis = {
    nuxtConfig: await analyzeNuxtConfig(),
    modules: await analyzeModuleUsage(),
    ssrPatterns: await analyzeSSRPatterns(),
    autoImports: await analyzeAutoImportPatterns(),
    seoImplementation: await analyzeSEOImplementation(),
    performanceOptimizations: await analyzePerformanceOptimizations(),
    errorHandling: await analyzeErrorHandling(),
    stateManagement: await analyzeStateManagement()
  }

  return analysis
}

async function analyzeNuxtConfig() {
  const configFiles = ['nuxt.config.ts', 'nuxt.config.js', 'nuxt.config.mjs']
  
  for (const configFile of configFiles) {
    const configPath = join(projectRoot, configFile)
    if (existsSync(configPath)) {
      const content = await readFile(configPath, 'utf-8')
      
      return {
        hasConfig: true,
        ssr: content.includes('ssr:') ? !content.includes('ssr: false') : true,
        modules: extractModulesFromConfig(content),
        devtools: content.includes('devtools') && !content.includes('devtools: false'),
        typescript: content.includes('typescript:') || configFile.endsWith('.ts'),
        nitro: content.includes('nitro:'),
        runtimeConfig: content.includes('runtimeConfig:'),
        css: content.includes('css:')
      }
    }
  }
  
  return { hasConfig: false }
}

function extractModulesFromConfig(content) {
  const moduleMatches = content.match(/modules:\s*\[([\s\S]*?)\]/)?.[1] || ''
  const modules = []
  
  // Extract quoted module names
  const quotedModules = moduleMatches.match(/['"`]([^'"`]+)['"`]/g) || []
  quotedModules.forEach(quoted => {
    const moduleName = quoted.replace(/['"`]/g, '')
    modules.push(moduleName)
  })
  
  return modules
}

async function analyzeModuleUsage() {
  const moduleAnalysis = {
    configured: [],
    packageJson: [],
    usage: {},
    recommendations: []
  }
  
  // Check package.json for module dependencies
  const packageJsonPath = join(projectRoot, 'package.json')
  if (existsSync(packageJsonPath)) {
    const packageContent = await readFile(packageJsonPath, 'utf-8')
    const packageData = JSON.parse(packageContent)
    
    const allDeps = {
      ...packageData.dependencies,
      ...packageData.devDependencies
    }
    
    Object.keys(allDeps).forEach(dep => {
      if (dep.startsWith('@nuxtjs/') || dep.startsWith('@nuxt/') || dep.includes('nuxt-')) {
        moduleAnalysis.packageJson.push(dep)
      }
    })
  }
  
  // Analyze module usage patterns in code
  const files = await scanProjectFiles()
  for (const file of files) {
    try {
      const content = await readFile(file, 'utf-8')
      
      for (const [category, patterns] of Object.entries(nuxtCorePatterns.modulePatterns)) {
        const matches = content.match(patterns) || []
        if (matches.length > 0) {
          if (!moduleAnalysis.usage[category]) {
            moduleAnalysis.usage[category] = 0
          }
          moduleAnalysis.usage[category] += matches.length
        }
      }
    } catch (error) {
      // Skip files that can't be read
    }
  }
  
  return moduleAnalysis
}

async function analyzeSSRPatterns() {
  const ssrAnalysis = {
    hydrationRisks: [],
    clientOnlyUsage: 0,
    dataFetchingPatterns: {},
    recommendations: []
  }
  
  const files = await scanProjectFiles(['.vue', '.ts', '.js'])
  
  for (const file of files) {
    try {
      const content = await readFile(file, 'utf-8')
      
      // Check for hydration mismatch risks
      const hydrationRisks = content.match(nuxtCorePatterns.ssrPatterns.hydrationMismatch) || []
      if (hydrationRisks.length > 0) {
        ssrAnalysis.hydrationRisks.push({
          file: file.replace(projectRoot, ''),
          risks: hydrationRisks.length
        })
      }
      
      // Count ClientOnly usage
      const clientOnly = content.match(nuxtCorePatterns.ssrPatterns.clientOnly) || []
      ssrAnalysis.clientOnlyUsage += clientOnly.length
      
      // Analyze data fetching patterns
      const dataFetching = content.match(nuxtCorePatterns.ssrPatterns.ssrDataFetch) || []
      dataFetching.forEach(pattern => {
        if (!ssrAnalysis.dataFetchingPatterns[pattern]) {
          ssrAnalysis.dataFetchingPatterns[pattern] = 0
        }
        ssrAnalysis.dataFetchingPatterns[pattern]++
      })
      
    } catch (error) {
      // Skip files that can't be read
    }
  }
  
  // Generate recommendations
  if (ssrAnalysis.hydrationRisks.length > 0) {
    ssrAnalysis.recommendations.push('High hydration mismatch risk detected - consider using <ClientOnly> for browser-specific code')
  }
  
  if (ssrAnalysis.clientOnlyUsage === 0 && ssrAnalysis.hydrationRisks.length > 3) {
    ssrAnalysis.recommendations.push('Consider using <ClientOnly> component to prevent hydration issues')
  }
  
  return ssrAnalysis
}

async function analyzeAutoImportPatterns() {
  const autoImportAnalysis = {
    composableUsage: {},
    explicitImports: 0,
    potentialConflicts: [],
    recommendations: []
  }
  
  const files = await scanProjectFiles(['.vue', '.ts', '.js'])
  
  for (const file of files) {
    try {
      const content = await readFile(file, 'utf-8')
      
      // Count composable usage
      const composables = content.match(nuxtCorePatterns.autoImportPatterns.composableUsage) || []
      composables.forEach(composable => {
        if (!autoImportAnalysis.composableUsage[composable]) {
          autoImportAnalysis.composableUsage[composable] = 0
        }
        autoImportAnalysis.composableUsage[composable]++
      })
      
      // Count explicit imports
      const explicitImports = content.match(nuxtCorePatterns.autoImportPatterns.explicitImports) || []
      autoImportAnalysis.explicitImports += explicitImports.length
      
    } catch (error) {
      // Skip files that can't be read
    }
  }
  
  return autoImportAnalysis
}

async function analyzeSEOImplementation() {
  const seoAnalysis = {
    metaUsage: {},
    openGraphImplemented: false,
    structuredDataFound: false,
    recommendations: []
  }
  
  const files = await scanProjectFiles(['.vue', '.ts', '.js'])
  
  for (const file of files) {
    try {
      const content = await readFile(file, 'utf-8')
      
      // Analyze meta management patterns
      for (const [pattern, regex] of Object.entries(nuxtCorePatterns.seoPatterns)) {
        const matches = content.match(regex) || []
        if (matches.length > 0) {
          if (!seoAnalysis.metaUsage[pattern]) {
            seoAnalysis.metaUsage[pattern] = 0
          }
          seoAnalysis.metaUsage[pattern] += matches.length
        }
      }
      
      // Check for Open Graph
      if (content.includes('og:') || content.includes('twitter:')) {
        seoAnalysis.openGraphImplemented = true
      }
      
      // Check for structured data
      if (content.includes('application/ld+json') || content.includes('schema.org')) {
        seoAnalysis.structuredDataFound = true
      }
      
    } catch (error) {
      // Skip files that can't be read
    }
  }
  
  // Generate SEO recommendations
  if (!seoAnalysis.openGraphImplemented) {
    seoAnalysis.recommendations.push('Implement Open Graph meta tags for better social media sharing')
  }
  
  if (!seoAnalysis.structuredDataFound) {
    seoAnalysis.recommendations.push('Add structured data (JSON-LD) for better search engine understanding')
  }
  
  if (seoAnalysis.metaUsage.metaManagement === 0) {
    seoAnalysis.recommendations.push('Use useSeoMeta() for better SEO meta tag management')
  }
  
  return seoAnalysis
}

async function analyzePerformanceOptimizations() {
  const performanceAnalysis = {
    optimizations: {},
    bundleOptimizations: 0,
    imageOptimizations: 0,
    recommendations: []
  }
  
  const files = await scanProjectFiles()
  
  for (const file of files) {
    try {
      const content = await readFile(file, 'utf-8')
      
      for (const [optimization, regex] of Object.entries(nuxtCorePatterns.performancePatterns)) {
        const matches = content.match(regex) || []
        if (matches.length > 0) {
          if (!performanceAnalysis.optimizations[optimization]) {
            performanceAnalysis.optimizations[optimization] = 0
          }
          performanceAnalysis.optimizations[optimization] += matches.length
        }
      }
      
    } catch (error) {
      // Skip files that can't be read
    }
  }
  
  return performanceAnalysis
}

async function analyzeErrorHandling() {
  const errorAnalysis = {
    errorBoundaries: 0,
    errorPages: 0,
    apiErrorHandling: 0,
    recommendations: []
  }
  
  const files = await scanProjectFiles()
  
  for (const file of files) {
    try {
      const content = await readFile(file, 'utf-8')
      
      for (const [errorType, regex] of Object.entries(nuxtCorePatterns.errorPatterns)) {
        const matches = content.match(regex) || []
        if (matches.length > 0) {
          errorAnalysis[errorType] = (errorAnalysis[errorType] || 0) + matches.length
        }
      }
      
    } catch (error) {
      // Skip files that can't be read
    }
  }
  
  return errorAnalysis
}

async function analyzeStateManagement() {
  const stateAnalysis = {
    useState: 0,
    piniaStores: 0,
    globalState: 0,
    recommendations: []
  }
  
  const files = await scanProjectFiles()
  
  for (const file of files) {
    try {
      const content = await readFile(file, 'utf-8')
      
      for (const [stateType, regex] of Object.entries(nuxtCorePatterns.statePatterns)) {
        const matches = content.match(regex) || []
        if (matches.length > 0) {
          stateAnalysis[stateType] = (stateAnalysis[stateType] || 0) + matches.length
        }
      }
      
    } catch (error) {
      // Skip files that can't be read
    }
  }
  
  // Generate state management recommendations
  if (stateAnalysis.piniaStores > 0 && stateAnalysis.useState > 5) {
    stateAnalysis.recommendations.push('Consider consolidating useState calls into Pinia stores for better state management')
  }
  
  if (stateAnalysis.piniaStores === 0 && stateAnalysis.useState > 10) {
    stateAnalysis.recommendations.push('Consider using Pinia for complex state management instead of multiple useState calls')
  }
  
  return stateAnalysis
}

async function scanProjectFiles(extensions = ['.vue', '.ts', '.js', '.mjs']) {
  const files = []
  const directories = ['components', 'pages', 'layouts', 'middleware', 'composables', 'utils', 'server', 'plugins']
  
  for (const dir of directories) {
    const dirPath = join(projectRoot, dir)
    if (existsSync(dirPath)) {
      const dirFiles = await scanDirectory(dirPath, extensions)
      files.push(...dirFiles)
    }
  }
  
  return files
}

async function scanDirectory(dirPath, extensions) {
  const files = []
  
  try {
    const entries = await readdir(dirPath, { withFileTypes: true })
    
    for (const entry of entries) {
      const fullPath = join(dirPath, entry.name)
      
      if (entry.isDirectory() && !entry.name.startsWith('.')) {
        const subFiles = await scanDirectory(fullPath, extensions)
        files.push(...subFiles)
      } else if (entry.isFile()) {
        const hasValidExtension = extensions.some(ext => entry.name.endsWith(ext))
        if (hasValidExtension) {
          files.push(fullPath)
        }
      }
    }
  } catch (error) {
    // Skip directories that can't be read
  }
  
  return files
}

async function generateNuxtRecommendations(analysis) {
  const recommendations = {
    critical: [],
    performance: [],
    seo: [],
    dx: [], // Developer Experience
    architecture: []
  }
  
  // Critical SSR/Hydration recommendations
  if (analysis.ssrPatterns.hydrationRisks.length > 3) {
    recommendations.critical.push({
      type: 'hydration_risk',
      priority: 'critical',
      description: `${analysis.ssrPatterns.hydrationRisks.length} files have hydration mismatch risks`,
      action: 'Use <ClientOnly> component for browser-specific code',
      sprKernel: 'nuxt_ssr_hydration'
    })
  }
  
  // Module optimization recommendations
  const moduleUsage = Object.keys(analysis.modules.usage).length
  if (moduleUsage > 8) {
    recommendations.performance.push({
      type: 'module_optimization',
      priority: 'medium',
      description: `${moduleUsage} modules detected - optimize bundle size`,
      action: 'Audit module necessity and enable tree-shaking',
      sprKernel: 'nuxt_modules_ecosystem'
    })
  }
  
  // SEO recommendations
  if (!analysis.seoImplementation.openGraphImplemented) {
    recommendations.seo.push({
      type: 'seo_optimization',
      priority: 'high',
      description: 'Open Graph meta tags not implemented',
      action: 'Add Open Graph tags for social media sharing',
      sprKernel: 'nuxt_seo_meta'
    })
  }
  
  // Auto-import optimization
  const composableCount = Object.keys(analysis.autoImports.composableUsage).length
  if (composableCount > 15) {
    recommendations.dx.push({
      type: 'autoimport_optimization',
      priority: 'medium',
      description: `${composableCount} composables detected - optimize auto-imports`,
      action: 'Review auto-import patterns and resolve conflicts',
      sprKernel: 'nuxt_autoimports_optimization'
    })
  }
  
  // State management architecture
  if (analysis.stateManagement.useState > 10 && analysis.stateManagement.piniaStores === 0) {
    recommendations.architecture.push({
      type: 'state_management',
      priority: 'medium',
      description: 'Complex state management detected without Pinia',
      action: 'Consider implementing Pinia for centralized state management',
      sprKernel: 'nuxt_component_architecture'
    })
  }
  
  return recommendations
}

async function main() {
  try {
    console.log(`${colors.green}Analyzing Nuxt project with core team insights...${colors.reset}`)
    
    const analysis = await analyzeNuxtProject()
    const recommendations = await generateNuxtRecommendations(analysis)
    
    // Generate comprehensive report
    const report = {
      timestamp: new Date().toISOString(),
      summary: {
        nuxtVersion: '3.x',
        ssrEnabled: analysis.nuxtConfig.ssr,
        modulesCount: analysis.modules.packageJson.length,
        hydrationRisks: analysis.ssrPatterns.hydrationRisks.length,
        seoImplemented: analysis.seoImplementation.openGraphImplemented,
        performanceOptimized: Object.keys(analysis.performanceOptimizations.optimizations).length > 3
      },
      analysis,
      recommendations,
      nextSteps: [
        'Activate relevant SPR kernels based on recommendations',
        'Address critical hydration risks first',
        'Implement missing SEO optimizations',
        'Optimize module usage and bundle size'
      ]
    }
    
    // Save analysis
    const reportPath = join(projectRoot, '.cdcs/nuxt_core_analysis.json')
    await writeFile(reportPath, JSON.stringify(report, null, 2))
    
    // Display results
    console.log(`${colors.blue}=== Nuxt Core Team Analysis Results ===${colors.reset}`)
    console.log(`Modules: ${report.summary.modulesCount}`)
    console.log(`Hydration risks: ${report.summary.hydrationRisks}`)
    console.log(`SEO implemented: ${report.summary.seoImplemented ? 'Yes' : 'No'}`)
    console.log(`Performance optimized: ${report.summary.performanceOptimized ? 'Yes' : 'No'}`)
    
    // Show critical recommendations
    const criticalRecs = recommendations.critical.concat(recommendations.performance, recommendations.seo)
    if (criticalRecs.length > 0) {
      console.log(`${colors.yellow}Critical Recommendations:${colors.reset}`)
      criticalRecs.forEach((rec, i) => {
        console.log(`  ${i + 1}. [${rec.priority.toUpperCase()}] ${rec.description}`)
        console.log(`     Action: ${rec.action}`)
        console.log(`     SPR: ${rec.sprKernel}`)
      })
    }
    
    console.log(`${colors.green}Analysis saved to: ${reportPath}${colors.reset}`)
    
  } catch (error) {
    console.error(`${colors.red}Error during Nuxt analysis:`, error.message, colors.reset)
    process.exit(1)
  }
}

main().catch(console.error)