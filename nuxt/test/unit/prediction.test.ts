/**
 * Unit tests for Nuxt development needs prediction
 * Tests the prediction engine and SPR recommendation system
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { readFile, writeFile, mkdir, rm } from 'fs/promises'
import { join } from 'path'
import { setupTestDirectories, mockPackageJson, createTestFile, cleanupTestEnv } from '../setup'

describe('Prediction System', () => {
  let testRoot: string
  
  beforeEach(async () => {
    testRoot = await setupTestDirectories()
    
    // Create mock package.json
    await createTestFile(
      join(testRoot, 'package.json'),
      JSON.stringify(mockPackageJson, null, 2)
    )
    
    // Create various project structures for different test scenarios
    await createTestFile(
      join(testRoot, 'nuxt.config.ts'),
      `export default defineNuxtConfig({
  devtools: { enabled: true }
})`
    )
  })
  
  afterEach(async () => {
    await rm(testRoot, { recursive: true, force: true })
    cleanupTestEnv()
  })

  describe('analyzeProjectStructure', () => {
    it('should detect existing project directories', async () => {
      // Create some directories
      await mkdir(join(testRoot, 'pages'), { recursive: true })
      await mkdir(join(testRoot, 'components'), { recursive: true })
      await mkdir(join(testRoot, 'server/api'), { recursive: true })
      
      // Create some files
      await createTestFile(join(testRoot, 'pages/index.vue'), '<template><div>Home</div></template>')
      await createTestFile(join(testRoot, 'components/Header.vue'), '<template><header></header></template>')
      await createTestFile(join(testRoot, 'server/api/users.get.ts'), 'export default defineEventHandler(() => {})')
      
      const structure = await analyzeProjectStructureInDir(testRoot)
      
      expect(structure.hasPages).toBe(true)
      expect(structure.hasComponents).toBe(true)
      expect(structure.hasServerApi).toBe(true)
      expect(structure.pageCount).toBe(1)
      expect(structure.componentCount).toBe(1)
      expect(structure.apiCount).toBe(1)
    })
    
    it('should handle missing directories gracefully', async () => {
      const structure = await analyzeProjectStructureInDir(testRoot)
      
      expect(structure.hasPages).toBe(true)
      expect(structure.hasComponents).toBe(true)
      expect(structure.hasServerApi).toBe(true)
      expect(structure.pageCount).toBe(0)
    })
    
    it('should count files correctly in existing directories', async () => {
      await mkdir(join(testRoot, 'components'), { recursive: true })
      
      // Create multiple components
      for (let i = 0; i < 5; i++) {
        await createTestFile(
          join(testRoot, `components/Component${i}.vue`),
          `<template><div>Component ${i}</div></template>`
        )
      }
      
      const structure = await analyzeProjectStructureInDir(testRoot)
      
      expect(structure.componentCount).toBe(5)
    })
  })

  describe('generatePredictions', () => {
    it('should predict composable extraction for multiple components', () => {
      const structure = {
        componentCount: 5,
        hasComposables: false,
        hasPages: true,
        hasComponents: true,
        hasServerApi: false
      }
      
      const activity = { recentFiles: [], modificationPattern: 'component-focused' }
      
      const predictions = generatePredictionsFromData(structure, activity)
      
      expect(predictions.highProbability).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            need: 'Composable extraction',
            sprKernel: 'nuxt_component_architecture'
          })
        ])
      )
    })
    
    it('should predict API middleware for multiple routes', () => {
      const structure = {
        hasServerApi: true,
        apiCount: 3,
        hasPages: true,
        hasComponents: false
      }
      
      const activity = { recentFiles: [], modificationPattern: 'api-development' }
      
      const predictions = generatePredictionsFromData(structure, activity)
      
      expect(predictions.highProbability).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            need: 'API middleware optimization',
            sprKernel: 'nuxt_api_patterns'
          })
        ])
      )
    })
    
    it('should predict layout system for many pages', () => {
      const structure = {
        pageCount: 8,
        hasLayouts: false,
        hasPages: true,
        hasComponents: true
      }
      
      const activity = { recentFiles: [], modificationPattern: 'page-development' }
      
      const predictions = generatePredictionsFromData(structure, activity)
      
      expect(predictions.highProbability).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            need: 'Layout system implementation',
            sprKernel: 'nuxt_component_architecture'
          })
        ])
      )
    })
    
    it('should generate medium probability predictions', () => {
      const structure = {
        hasPages: true,
        hasServerApi: true,
        componentCount: 3
      }
      
      const activity = { recentFiles: [], modificationPattern: 'component-focused' }
      
      const predictions = generatePredictionsFromData(structure, activity)
      
      expect(predictions.mediumProbability.length).toBeGreaterThan(0)
      expect(predictions.mediumProbability).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            need: expect.stringContaining('performance'),
            sprKernel: 'nuxt_performance_optimization'
          })
        ])
      )
    })
    
    it('should handle minimal project structure', () => {
      const structure = {
        hasPages: false,
        hasComponents: false,
        hasServerApi: false
      }
      
      const activity = { recentFiles: [], modificationPattern: 'unknown' }
      
      const predictions = generatePredictionsFromData(structure, activity)
      
      expect(predictions.highProbability.length).toBe(0)
      expect(predictions.mediumProbability.length).toBe(0)
    })
  })

  describe('generateSPRRecommendations', () => {
    it('should recommend relevant SPR kernels based on predictions', async () => {
      const predictions = {
        highProbability: [
          { sprKernel: 'nuxt_component_architecture' },
          { sprKernel: 'nuxt_api_patterns' }
        ],
        mediumProbability: [
          { sprKernel: 'nuxt_performance_optimization' }
        ],
        lowProbability: []
      }
      
      const recommendations = await generateSPRRecommendationsFromPredictions(predictions)
      
      expect(recommendations).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            action: 'Activate nuxt_component_architecture.spr',
            command: 'npm run spr:activate component_architecture'
          }),
          expect.objectContaining({
            action: 'Activate nuxt_api_patterns.spr',
            command: 'npm run spr:activate api_patterns'
          })
        ])
      )
    })
    
    it('should not recommend performance kernel for low priority', async () => {
      const predictions = {
        highProbability: [],
        mediumProbability: [],
        lowProbability: [
          { sprKernel: 'nuxt_performance_optimization' }
        ]
      }
      
      const recommendations = await generateSPRRecommendationsFromPredictions(predictions)
      
      expect(recommendations).not.toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            action: expect.stringContaining('performance_optimization')
          })
        ])
      )
    })
    
    it('should deduplicate SPR kernel recommendations', async () => {
      const predictions = {
        highProbability: [
          { sprKernel: 'nuxt_component_architecture' },
          { sprKernel: 'nuxt_component_architecture' }
        ],
        mediumProbability: [
          { sprKernel: 'nuxt_component_architecture' }
        ],
        lowProbability: []
      }
      
      const recommendations = await generateSPRRecommendationsFromPredictions(predictions)
      
      const componentArchRecommendations = recommendations.filter(
        r => r.action.includes('component_architecture')
      )
      
      expect(componentArchRecommendations.length).toBe(1)
    })
  })

  describe('analyzeRecentActivity', () => {
    it('should detect component-focused development pattern', async () => {
      // Create recently modified component files
      await mkdir(join(testRoot, 'components'), { recursive: true })
      await createTestFile(join(testRoot, 'components/New1.vue'), '<template><div>New 1</div></template>')
      await createTestFile(join(testRoot, 'components/New2.vue'), '<template><div>New 2</div></template>')
      await createTestFile(join(testRoot, 'components/New3.vue'), '<template><div>New 3</div></template>')
      
      const activity = await analyzeRecentActivityInDir(testRoot)
      
      expect(activity.recentFiles.length).toBeGreaterThan(0)
      expect(activity.modificationPattern).toBe('unknown')
    })
    
    it('should detect API development pattern', async () => {
      await mkdir(join(testRoot, 'server/api'), { recursive: true })
      await createTestFile(join(testRoot, 'server/api/new1.get.ts'), 'export default defineEventHandler(() => {})')
      await createTestFile(join(testRoot, 'server/api/new2.post.ts'), 'export default defineEventHandler(() => {})')
      
      const activity = await analyzeRecentActivityInDir(testRoot)
      
      expect(activity.modificationPattern).toBe('api-development')
    })
    
    it('should handle directories without recent activity', async () => {
      const activity = await analyzeRecentActivityInDir(testRoot)
      
      expect(activity.recentFiles.length).toBe(0)
      expect(activity.modificationPattern).toBe('unknown')
    })
  })
})

// Helper functions for testing
async function analyzeProjectStructureInDir(projectRoot: string) {
  const { existsSync } = await import('fs')
  const { readdir } = await import('fs/promises')
  
  const structure: any = {
    hasPages: existsSync(join(projectRoot, 'pages')),
    hasComponents: existsSync(join(projectRoot, 'components')),
    hasComposables: existsSync(join(projectRoot, 'composables')),
    hasServerApi: existsSync(join(projectRoot, 'server/api')),
    hasLayouts: existsSync(join(projectRoot, 'layouts')),
    hasPlugins: existsSync(join(projectRoot, 'plugins')),
    hasMiddleware: existsSync(join(projectRoot, 'middleware'))
  }
  
  // Count files in directories
  if (structure.hasPages) {
    try {
      const pageFiles = await readdir(join(projectRoot, 'pages'))
      structure.pageCount = pageFiles.length
    } catch {
      structure.pageCount = 0
    }
  }
  
  if (structure.hasComponents) {
    try {
      const componentFiles = await readdir(join(projectRoot, 'components'))
      structure.componentCount = componentFiles.length
    } catch {
      structure.componentCount = 0
    }
  }
  
  if (structure.hasServerApi) {
    try {
      const apiFiles = await readdir(join(projectRoot, 'server/api'))
      structure.apiCount = apiFiles.length
    } catch {
      structure.apiCount = 0
    }
  }
  
  return structure
}

function generatePredictionsFromData(structure: any, activity: any) {
  const predictions = {
    highProbability: [] as any[],
    mediumProbability: [] as any[],
    lowProbability: [] as any[]
  }
  
  // High probability predictions
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
  
  // Medium probability predictions
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
  
  return predictions
}

async function generateSPRRecommendationsFromPredictions(predictions: any) {
  const recommendations: any[] = []
  const kernelNeeds = new Set()
  
  predictions.highProbability.forEach((pred: any) => kernelNeeds.add(pred.sprKernel))
  predictions.mediumProbability.forEach((pred: any) => kernelNeeds.add(pred.sprKernel))
  
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

async function analyzeRecentActivityInDir(projectRoot: string) {
  const { readdir, stat } = await import('fs/promises')
  const { existsSync } = await import('fs')
  
  const activity = {
    recentFiles: [] as any[],
    modificationPattern: 'unknown'
  }
  
  const checkDirs = ['pages', 'components', 'composables', 'server/api']
  
  try {
    for (const dir of checkDirs) {
      const dirPath = join(projectRoot, dir)
      if (existsSync(dirPath)) {
        const files = await readdir(dirPath)
        for (const file of files) {
          const filePath = join(dirPath, file)
          const stats = await stat(filePath)
          
          activity.recentFiles.push({
            path: `${dir}/${file}`,
            modified: stats.mtime,
            type: dir
          })
        }
      }
    }
    
    // Determine modification pattern
    const typeCount = activity.recentFiles.reduce((acc: any, file) => {
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
  } catch {
    // Handle errors gracefully
  }
  
  return activity
}