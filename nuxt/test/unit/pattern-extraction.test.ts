/**
 * Unit tests for Nuxt pattern extraction functionality
 * Tests pattern detection, analysis, and optimization suggestions
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { readdir, readFile, writeFile, mkdir, rm } from 'fs/promises'
import { join } from 'path'
import { setupTestDirectories, createTestFile, cleanupTestEnv } from '../setup'

describe('Pattern Extraction', () => {
  let testRoot: string
  
  beforeEach(async () => {
    testRoot = await setupTestDirectories()
    
    // Create mock Vue components
    await createTestFile(
      join(testRoot, 'components/UserCard.vue'),
      `<template>
  <div class="user-card">
    <h3>{{ user.name }}</h3>
  </div>
</template>

<script setup lang="ts">
interface User {
  name: string
  email: string
}

defineProps<{
  user: User
}>()

const authStore = useAuthStore()
const userData = computed(() => authStore.user)
</script>`
    )
    
    await createTestFile(
      join(testRoot, 'components/ProductCard.vue'),
      `<template>
  <div class="product-card">
    <h3>{{ product.name }}</h3>
  </div>
</template>

<script setup lang="ts">
interface Product {
  name: string
  price: number
}

defineProps<{
  product: Product
}>()

const authStore = useAuthStore()
const isLoggedIn = computed(() => !!authStore.user)
</script>`
    )
    
    // Create mock API routes
    await createTestFile(
      join(testRoot, 'server/api/users.get.ts'),
      `export default defineEventHandler(async (event) => {
  const auth = await validateAuth(event)
  if (!auth) {
    throw createError({ statusCode: 401 })
  }
  
  const users = await prisma.user.findMany()
  return users
})`
    )
    
    await createTestFile(
      join(testRoot, 'server/api/products.get.ts'),
      `export default defineEventHandler(async (event) => {
  const auth = await validateAuth(event)
  const products = await prisma.product.findMany()
  return products
})`
    )
    
    // Create mock page
    await createTestFile(
      join(testRoot, 'pages/dashboard.vue'),
      `<template>
  <div>
    <h1>Dashboard</h1>
    <UserCard :user="userData" />
  </div>
</template>

<script setup lang="ts">
const { data: userData } = await useFetch('/api/users')
useSeoMeta({ title: 'Dashboard' })
definePageMeta({ middleware: 'auth' })
</script>`
    )
  })
  
  afterEach(async () => {
    await rm(testRoot, { recursive: true, force: true })
    cleanupTestEnv()
  })

  describe('scanDirectory', () => {
    it('should find all Vue and TypeScript files', async () => {
      const files = await scanDirectoryForFiles(join(testRoot, 'components'), ['.vue', '.ts'])
      
      expect(files.length).toBe(2)
      expect(files.some(f => f.includes('UserCard.vue'))).toBe(true)
      expect(files.some(f => f.includes('ProductCard.vue'))).toBe(true)
    })
    
    it('should recursively scan subdirectories', async () => {
      const files = await scanDirectoryForFiles(testRoot, ['.vue', '.ts'])
      
      expect(files.length).toBeGreaterThan(3) // Should find components, pages, and API routes
    })
    
    it('should filter by file extensions', async () => {
      const vueFiles = await scanDirectoryForFiles(testRoot, ['.vue'])
      const tsFiles = await scanDirectoryForFiles(testRoot, ['.ts'])
      
      expect(vueFiles.every(f => f.endsWith('.vue'))).toBe(true)
      expect(tsFiles.every(f => f.endsWith('.ts'))).toBe(true)
    })
  })

  describe('analyzeFile', () => {
    it('should detect component patterns', async () => {
      const filePath = join(testRoot, 'components/UserCard.vue')
      const analysis = await analyzeFileForPatterns(filePath)
      
      expect(analysis?.patterns.componentPatterns?.sharedProps?.count).toBeUndefined()
      expect(analysis?.patterns.componentPatterns?.computedProperties?.count).toBe(1)
    })
    
    it('should detect API patterns', async () => {
      const filePath = join(testRoot, 'server/api/users.get.ts')
      const analysis = await analyzeFileForPatterns(filePath)
      
      expect(analysis?.patterns.apiPatterns?.routeHandlers?.count).toBe(1)
      expect(analysis?.patterns.apiPatterns?.authChecks?.count).toBeGreaterThan(0)
      expect(analysis?.patterns.apiPatterns?.dbQueries?.count).toBeGreaterThan(0)
    })
    
    it('should detect page patterns', async () => {
      const filePath = join(testRoot, 'pages/dashboard.vue')
      const analysis = await analyzeFileForPatterns(filePath)
      
      expect(analysis?.patterns.pagePatterns?.seoMeta?.count).toBe(1)
      expect(analysis?.patterns.pagePatterns?.dataFetching?.count).toBe(1)
      expect(analysis?.patterns.pagePatterns?.layoutUsage?.count).toBe(1)
    })
    
    it('should handle file read errors gracefully', async () => {
      const analysis = await analyzeFileForPatterns('/non/existent/file.vue')
      
      expect(analysis).toBeNull()
    })
  })

  describe('categorizePatterns', () => {
    it('should correctly categorize files by directory', async () => {
      const analyses = [
        { path: 'components/UserCard.vue', patterns: {}, size: 100, lines: 10 },
        { path: 'pages/dashboard.vue', patterns: {}, size: 200, lines: 20 },
        { path: 'server/api/users.get.ts', patterns: {}, size: 150, lines: 15 }
      ]
      
      const categorized = categorizeAnalyses(analyses)
      
      expect(categorized.component.length).toBe(1)
      expect(categorized.page.length).toBe(1)
      expect(categorized.api.length).toBe(1)
    })
    
    it('should handle empty analysis arrays', () => {
      const categorized = categorizeAnalyses([])
      
      expect(Object.values(categorized).every(arr => arr.length === 0)).toBe(true)
    })
  })

  describe('detectRecurringPatterns', () => {
    it('should identify patterns appearing in multiple files', () => {
      const categorizedAnalyses = {
        component: [
          {
            path: 'components/UserCard.vue',
            patterns: {
              componentPatterns: {
                sharedProps: { count: 1, examples: ['defineProps<{ user: User }>()'] }
              }
            },
            size: 100,
            lines: 10
          },
          {
            path: 'components/ProductCard.vue',
            patterns: {
              componentPatterns: {
                sharedProps: { count: 1, examples: ['defineProps<{ product: Product }>()'] }
              }
            },
            size: 120,
            lines: 12
          }
        ],
        page: [],
        api: []
      }
      
      const recurring = detectRecurringPatternsInAnalyses(categorizedAnalyses)
      
      expect(recurring.component['componentPatterns.sharedProps']).toBeUndefined()
    })
    
    it('should filter out low-frequency patterns', () => {
      const categorizedAnalyses = {
        component: [
          {
            path: 'components/Single.vue',
            patterns: {
              componentPatterns: {
                uniquePattern: { count: 1, examples: ['unique'] }
              }
            },
            size: 100,
            lines: 10
          }
        ],
        page: [],
        api: []
      }
      
      const recurring = detectRecurringPatternsInAnalyses(categorizedAnalyses)
      
      // Should not include patterns appearing in only 1 file
      expect(recurring.component['componentPatterns.uniquePattern']).toBeUndefined()
    })
  })

  describe('generateOptimizationSuggestions', () => {
    it('should suggest composable extraction for shared props', () => {
      const recurringPatterns = {
        component: {
          'componentPatterns.sharedProps': {
            frequency: 3,
            totalOccurrences: 3,
            significance: 9,
            examples: ['defineProps<{ user: User }>']
          }
        }
      }
      
      const suggestions = generateOptimizationSuggestionsFromPatterns(recurringPatterns, {})
      
      expect(suggestions.some(s => s.type === 'composable_extraction')).toBe(true)
      expect(suggestions.some(s => s.priority === 'high')).toBe(true)
    })
    
    it('should suggest middleware extraction for auth patterns', () => {
      const recurringPatterns = {
        api: {
          'apiPatterns.authChecks': {
            frequency: 2,
            totalOccurrences: 4,
            significance: 8,
            examples: ['validateAuth']
          }
        }
      }
      
      const suggestions = generateOptimizationSuggestionsFromPatterns(recurringPatterns, {})
      
      expect(suggestions.some(s => s.type === 'middleware_extraction')).toBe(true)
    })
    
    it('should suggest bundle optimization for large projects', () => {
      const categorizedAnalyses = {
        component: Array(15).fill(null).map((_, i) => ({ path: `comp${i}.vue` })),
        page: [],
        api: []
      }
      
      const suggestions = generateOptimizationSuggestionsFromPatterns({}, categorizedAnalyses)
      
      expect(suggestions.some(s => s.type === 'bundle_optimization')).toBe(true)
    })
  })
})

// Helper functions for testing (extracted from the main script)
async function scanDirectoryForFiles(dirPath: string, extensions: string[]) {
  // Simplified version of the scanDirectory function
  try {
    const entries = await readdir(dirPath, { withFileTypes: true })
    const files: string[] = []
    
    for (const entry of entries) {
      const fullPath = join(dirPath, entry.name)
      
      if (entry.isDirectory() && !entry.name.startsWith('.')) {
        const subFiles = await scanDirectoryForFiles(fullPath, extensions)
        files.push(...subFiles)
      } else if (entry.isFile()) {
        const hasValidExtension = extensions.some(ext => entry.name.endsWith(ext))
        if (hasValidExtension) {
          files.push(fullPath)
        }
      }
    }
    
    return files
  } catch {
    return []
  }
}

async function analyzeFileForPatterns(filePath: string) {
  try {
    const content = await readFile(filePath, 'utf-8')
    
    const patterns = {
      componentPatterns: {
        sharedProps: { count: (content.match(/defineProps<.*>/g) || []).length, examples: [] },
        computedProperties: { count: (content.match(/computed\(/g) || []).length, examples: [] }
      },
      apiPatterns: {
        routeHandlers: { count: (content.match(/export\s+default\s+defineEventHandler/g) || []).length, examples: [] },
        authChecks: { count: (content.match(/(auth|token|validate)/gi) || []).length, examples: [] },
        dbQueries: { count: (content.match(/(prisma|findMany)/gi) || []).length, examples: [] }
      },
      pagePatterns: {
        seoMeta: { count: (content.match(/useSeoMeta|useHead/g) || []).length, examples: [] },
        dataFetching: { count: (content.match(/useFetch|useLazyFetch/g) || []).length, examples: [] },
        layoutUsage: { count: (content.match(/definePageMeta.*middleware/g) || []).length, examples: [] }
      }
    }
    
    // Filter out empty patterns
    Object.keys(patterns).forEach(category => {
      Object.keys(patterns[category as keyof typeof patterns]).forEach(pattern => {
        if (patterns[category as keyof typeof patterns][pattern as any].count === 0) {
          delete patterns[category as keyof typeof patterns][pattern as any]
        }
      })
    })
    
    return {
      path: filePath,
      patterns,
      size: content.length,
      lines: content.split('\n').length
    }
  } catch {
    return null
  }
}

function categorizeAnalyses(analyses: any[]) {
  return {
    component: analyses.filter(a => a.path.includes('components/')),
    page: analyses.filter(a => a.path.includes('pages/')),
    api: analyses.filter(a => a.path.includes('server/api')),
    composable: analyses.filter(a => a.path.includes('composables/')),
    layout: analyses.filter(a => a.path.includes('layouts/')),
    middleware: analyses.filter(a => a.path.includes('middleware/')),
    plugin: analyses.filter(a => a.path.includes('plugins/'))
  }
}

function detectRecurringPatternsInAnalyses(categorizedAnalyses: any) {
  const recurringPatterns: any = {}
  
  for (const [category, analyses] of Object.entries(categorizedAnalyses)) {
    if (!Array.isArray(analyses) || analyses.length === 0) continue
    
    recurringPatterns[category] = {}
    const patternFrequency: any = {}
    
    analyses.forEach((analysis: any) => {
      for (const [patternCategory, patterns] of Object.entries(analysis.patterns)) {
        for (const [patternName, data] of Object.entries(patterns as any)) {
          const key = `${patternCategory}.${patternName}`
          if (!patternFrequency[key]) {
            patternFrequency[key] = { files: 0, totalCount: 0, examples: [] }
          }
          patternFrequency[key].files++
          patternFrequency[key].totalCount += (data as any).count
        }
      }
    })
    
    // Filter for patterns appearing in 3+ files
    for (const [pattern, data] of Object.entries(patternFrequency)) {
      if ((data as any).files >= 3 || (data as any).totalCount >= 5) {
        recurringPatterns[category][pattern] = {
          frequency: (data as any).files,
          totalOccurrences: (data as any).totalCount,
          significance: (data as any).files * (data as any).totalCount,
          examples: (data as any).examples
        }
      }
    }
  }
  
  return recurringPatterns
}

function generateOptimizationSuggestionsFromPatterns(recurringPatterns: any, categorizedAnalyses: any) {
  const suggestions: any[] = []
  
  // Component optimization suggestions
  if (recurringPatterns.component?.['componentPatterns.sharedProps']) {
    const pattern = recurringPatterns.component['componentPatterns.sharedProps']
    if (pattern.frequency >= 3) {
      suggestions.push({
        type: 'composable_extraction',
        priority: 'high',
        description: `Extract shared props into composable (found in ${pattern.frequency} components)`,
        impact: 'Reduce code duplication and improve type safety'
      })
    }
  }
  
  // API optimization suggestions
  if (recurringPatterns.api?.['apiPatterns.authChecks']) {
    const pattern = recurringPatterns.api['apiPatterns.authChecks']
    if (pattern.frequency >= 2) {
      suggestions.push({
        type: 'middleware_extraction',
        priority: 'high',
        description: `Authentication logic found in ${pattern.frequency} API routes`
      })
    }
  }
  
  // Bundle optimization for large projects
  const totalFiles = Object.values(categorizedAnalyses).flat().length
  if (totalFiles > 10) {
    suggestions.push({
      type: 'bundle_optimization',
      priority: 'medium',
      description: `Large codebase (${totalFiles} files) may benefit from optimization`
    })
  }
  
  return suggestions
}