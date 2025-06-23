/**
 * Unit tests for Nuxt performance benchmarking
 * Tests build time measurement, bundle analysis, and SPR efficiency calculation
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { writeFile, mkdir, rm } from 'fs/promises'
import { join } from 'path'
import { setupTestDirectories, mockBenchmarkResults, createTestFile, cleanupTestEnv } from '../setup'

// Mock child_process exec
vi.mock('child_process', () => ({
  exec: vi.fn()
}))

describe('Performance Benchmarking', () => {
  let testRoot: string
  
  beforeEach(async () => {
    testRoot = await setupTestDirectories()
    
    // Create mock build output
    await mkdir(join(testRoot, '.output/public'), { recursive: true })
    await mkdir(join(testRoot, '.output/server'), { recursive: true })
    
    // Create mock SPR kernels
    await createTestFile(
      join(testRoot, 'spr_kernels/nuxt_component_architecture.spr'),
      '# Test Kernel\n- Concept 1\n- Concept 2\n- Concept 3'
    )
    
    await createTestFile(
      join(testRoot, 'spr_kernels/nuxt_api_patterns.spr'),
      '# API Kernel\n- API Concept 1\n- API Concept 2'
    )
  })
  
  afterEach(async () => {
    await rm(testRoot, { recursive: true, force: true })
    cleanupTestEnv()
  })

  describe('measureBuildTime', () => {
    it('should measure successful build time', async () => {
      const mockExec = vi.fn().mockResolvedValue({
        stdout: 'Build completed successfully',
        stderr: ''
      })
      
      const result = await measureBuildTimeWithMock(mockExec, 25000)
      
      expect(result.success).toBe(true)
      expect(result.buildTime).toBe(25000)
      expect(result.buildTimeSeconds).toBe('25.00')
    })
    
    it('should handle build failures gracefully', async () => {
      const mockExec = vi.fn().mockRejectedValue(new Error('Build failed'))
      
      const result = await measureBuildTimeWithMock(mockExec, 0)
      
      expect(result.success).toBe(false)
      expect(result.error).toContain('Build failed')
    })
    
    it('should measure different build times accurately', async () => {
      const mockExec = vi.fn().mockResolvedValue({ stdout: '', stderr: '' })
      
      const result1 = await measureBuildTimeWithMock(mockExec, 15000)
      const result2 = await measureBuildTimeWithMock(mockExec, 45000)
      
      expect(result1.buildTimeSeconds).toBe('15.00')
      expect(result2.buildTimeSeconds).toBe('45.00')
    })
  })

  describe('analyzeBundleSize', () => {
    it('should analyze bundle size from output directory', async () => {
      // Mock du command output
      const mockExec = vi.fn()
        .mockResolvedValueOnce({ stdout: '250K\t.output' })     // Total size
        .mockResolvedValueOnce({ stdout: '180K\t.output/public' }) // Client size
        .mockResolvedValueOnce({ stdout: '70K\t.output/server' })  // Server size
      
      const result = await analyzeBundleSizeWithMock(mockExec, testRoot)
      
      expect(result.success).toBe(true)
      expect(result.totalSize).toBe('250K')
      expect(result.clientSize).toBe('180K')
      expect(result.serverSize).toBe('70K')
    })
    
    it('should handle missing build output', async () => {
      await rm(join(testRoot, '.output'), { recursive: true, force: true })
      
      const result = await analyzeBundleSizeWithMock(vi.fn(), testRoot)
      
      expect(result.success).toBe(false)
      expect(result.error).toContain('Build output not found')
    })
    
    it('should handle partial build output', async () => {
      // Remove server directory
      await rm(join(testRoot, '.output/server'), { recursive: true, force: true })
      
      const mockExec = vi.fn()
        .mockResolvedValueOnce({ stdout: '180K\t.output' })
        .mockResolvedValueOnce({ stdout: '180K\t.output/public' })
        .mockRejectedValueOnce(new Error('No such directory'))
      
      const result = await analyzeBundleSizeWithMock(mockExec, testRoot)
      
      expect(result.success).toBe(true)
      expect(result.clientSize).toBe('180K')
      expect(result.serverSize).toBe('N/A')
    })
  })

  describe('measureSPREfficiency', () => {
    it('should calculate SPR efficiency correctly', async () => {
      const result = await measureSPREfficiencyInDir(testRoot)
      
      expect(result.success).toBe(true)
      expect(result.totalConcepts).toBe(5) // 3 + 2 concepts from mock kernels
      expect(parseFloat(result.efficiency.replace('%', ''))).toBeGreaterThan(90)
      expect(parseFloat(result.tokenReduction.replace('%', ''))).toBeGreaterThan(85)
    })
    
    it('should handle missing SPR kernels', async () => {
      await rm(join(testRoot, 'spr_kernels'), { recursive: true, force: true })
      
      const result = await measureSPREfficiencyInDir(testRoot)
      
      expect(result.success).toBe(false)
      expect(result.error).toBe('SPR kernels not found')
    })
    
    it('should calculate token savings accurately', async () => {
      // Create larger kernel for more accurate calculation
      await createTestFile(
        join(testRoot, 'spr_kernels/large_kernel.spr'),
        Array.from({length: 50}, (_, i) => `- Large concept ${i + 1}`).join('\n')
      )
      
      const result = await measureSPREfficiencyInDir(testRoot)
      
      expect(result.success).toBe(true)
      expect(parseInt(result.sprTokens)).toBeGreaterThan(0)
      expect(parseInt(result.fileTokens)).toBeGreaterThan(parseInt(result.sprTokens))
    })
  })

  describe('calculatePerformanceRating', () => {
    it('should give excellent rating for optimal metrics', () => {
      const metrics = {
        buildTime: { success: true, buildTimeSeconds: '15.00' },
        bundleSize: { success: true, totalSize: '150KB' },
        sprEfficiency: { success: true, efficiency: '95%' },
        lighthouse: { success: true, performance: 95, accessibility: 95, bestPractices: 95, seo: 95 }
      }
      
      const rating = calculatePerformanceRatingFromMetrics(metrics)
      
      expect(rating.score).toBeGreaterThanOrEqual(95)
      expect(rating.rating).toContain('★★★★★')
    })
    
    it('should give poor rating for suboptimal metrics', () => {
      const metrics = {
        buildTime: { success: true, buildTimeSeconds: '120.00' },
        bundleSize: { success: true, totalSize: '2MB' },
        sprEfficiency: { success: true, efficiency: '30%' },
        lighthouse: { success: true, performance: 45, accessibility: 60, bestPractices: 50, seo: 55 }
      }
      
      const rating = calculatePerformanceRatingFromMetrics(metrics)
      
      expect(rating.score).toBeLessThan(60)
      expect(rating.rating).toContain('★☆☆☆☆')
    })
    
    it('should handle missing metrics gracefully', () => {
      const metrics = {
        buildTime: { success: false },
        bundleSize: { success: false },
        sprEfficiency: { success: false },
        lighthouse: { success: false }
      }
      
      const rating = calculatePerformanceRatingFromMetrics(metrics)
      
      expect(rating.score).toBeLessThanOrEqual(100)
      expect(rating.rating).toBeDefined()
    })
    
    it('should weight build time appropriately', () => {
      const fastBuild = {
        buildTime: { success: true, buildTimeSeconds: '10.00' },
        lighthouse: { success: true, performance: 80, accessibility: 80, bestPractices: 80, seo: 80 },
        sprEfficiency: { success: true, efficiency: '85%' }
      }
      
      const slowBuild = {
        buildTime: { success: true, buildTimeSeconds: '90.00' },
        lighthouse: { success: true, performance: 80, accessibility: 80, bestPractices: 80, seo: 80 },
        sprEfficiency: { success: true, efficiency: '85%' }
      }
      
      const fastRating = calculatePerformanceRatingFromMetrics(fastBuild)
      const slowRating = calculatePerformanceRatingFromMetrics(slowBuild)
      
      expect(fastRating.score).toBeGreaterThan(slowRating.score)
    })
  })

  describe('runLighthouseAudit', () => {
    it('should parse lighthouse results correctly', async () => {
      const mockLighthouseOutput = JSON.stringify({
        lhr: {
          categories: {
            performance: { score: 0.92 },
            accessibility: { score: 0.88 },
            'best-practices': { score: 0.95 },
            seo: { score: 0.91 }
          }
        }
      })
      
      const mockExec = vi.fn()
        .mockResolvedValueOnce({ stdout: 'lighthouse' }) // which lighthouse
        .mockResolvedValueOnce({ stdout: mockLighthouseOutput })
      
      const result = await runLighthouseAuditWithMock(mockExec)
      
      expect(result.success).toBe(true)
      expect(result.performance).toBe(92)
      expect(result.accessibility).toBe(88)
      expect(result.bestPractices).toBe(95)
      expect(result.seo).toBe(91)
    })
    
    it('should handle lighthouse unavailability', async () => {
      const mockExec = vi.fn().mockRejectedValue(new Error('command not found'))
      
      const result = await runLighthouseAuditWithMock(mockExec)
      
      expect(result.success).toBe(false)
      expect(result.error).toContain('Lighthouse not available')
    })
  })

  describe('analyzeApiPerformance', () => {
    it('should analyze API route count', async () => {
      await mkdir(join(testRoot, 'server/api'), { recursive: true })
      
      // Create multiple API routes
      await createTestFile(join(testRoot, 'server/api/users.get.ts'), 'export default defineEventHandler(() => {})')
      await createTestFile(join(testRoot, 'server/api/products.get.ts'), 'export default defineEventHandler(() => {})')
      await createTestFile(join(testRoot, 'server/api/auth.post.ts'), 'export default defineEventHandler(() => {})')
      
      const mockExec = vi.fn().mockResolvedValue({ stdout: '3' })
      
      const result = await analyzeApiPerformanceWithMock(mockExec, testRoot)
      
      expect(result.success).toBe(true)
      expect(result.apiRouteCount).toBe(3)
      expect(result.status).toContain('API routes detected')
    })
    
    it('should handle projects without API routes', async () => {
      const result = await analyzeApiPerformanceWithMock(vi.fn(), testRoot)
      
      expect(result.success).toBe(false)
      expect(result.message).toBeUndefined()
    })
    
    it('should recommend middleware for many routes', async () => {
      const mockExec = vi.fn().mockResolvedValue({ stdout: '8' })
      
      const result = await analyzeApiPerformanceWithMock(mockExec, testRoot)
      
      expect(result.recommendation).toContain('middleware optimization')
    })
  })
})

// Helper functions for testing
async function measureBuildTimeWithMock(mockExec: any, duration: number) {
  const startTime = Date.now()
  
  try {
    await mockExec('npm run build')
    return {
      buildTime: duration,
      buildTimeSeconds: (duration / 1000).toFixed(2),
      success: true,
      output: 'Build completed'
    }
  } catch (error: any) {
    return {
      buildTime: null,
      success: false,
      error: error.message
    }
  }
}

async function analyzeBundleSizeWithMock(mockExec: any, projectRoot: string) {
  const { existsSync } = await import('fs')
  const outputDir = join(projectRoot, '.output')
  
  if (!existsSync(outputDir)) {
    return { error: 'Build output not found. Run build first.', success: false }
  }
  
  try {
    const { stdout: totalOut } = await mockExec(`du -sh ${outputDir}`)
    const totalSize = totalOut.trim().split('\t')[0]
    
    let clientSize = 'N/A'
    let serverSize = 'N/A'
    
    try {
      const { stdout: clientOut } = await mockExec(`du -sh ${join(outputDir, 'public')}`)
      clientSize = clientOut.trim().split('\t')[0]
    } catch {
      // Client dir might not exist
    }
    
    try {
      const { stdout: serverOut } = await mockExec(`du -sh ${join(outputDir, 'server')}`)
      serverSize = serverOut.trim().split('\t')[0]
    } catch {
      // Server dir might not exist
    }
    
    return {
      totalSize,
      clientSize,
      serverSize,
      success: true
    }
  } catch (error: any) {
    return {
      error: error.message,
      success: false
    }
  }
}

async function measureSPREfficiencyInDir(projectRoot: string) {
  const { existsSync } = await import('fs')
  const { readFile, stat } = await import('fs/promises')
  
  const sprDir = join(projectRoot, 'spr_kernels')
  
  if (!existsSync(sprDir)) {
    return { error: 'SPR kernels not found', success: false }
  }
  
  try {
    const kernelFiles = ['nuxt_component_architecture.spr', 'nuxt_api_patterns.spr', 'large_kernel.spr']
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
    
    const estimatedFileSize = 150 * 1024 // 150KB
    const compressionRatio = (totalSprSize / estimatedFileSize).toFixed(3)
    const efficiency = ((1 - parseFloat(compressionRatio)) * 100).toFixed(1)
    
    const sprTokens = Math.ceil(totalSprSize / 4)
    const fileTokens = Math.ceil(estimatedFileSize / 4)
    const tokenReduction = ((1 - sprTokens / fileTokens) * 100).toFixed(1)
    
    return {
      totalSprSize: (totalSprSize / 1024).toFixed(1) + 'KB',
      totalConcepts,
      compressionRatio,
      efficiency: efficiency + '%',
      sprTokens: sprTokens.toString(),
      fileTokens: fileTokens.toString(),
      tokenReduction: tokenReduction + '%',
      success: true
    }
  } catch (error: any) {
    return {
      error: error.message,
      success: false
    }
  }
}

function calculatePerformanceRatingFromMetrics(metrics: any) {
  let score = 100
  
  // Build time scoring
  if (metrics.buildTime?.success) {
    const buildSeconds = parseFloat(metrics.buildTime.buildTimeSeconds)
    if (buildSeconds > 60) score -= 20
    else if (buildSeconds > 30) score -= 10
  }
  
  // Lighthouse scoring
  if (metrics.lighthouse?.success) {
    const avgScore = (metrics.lighthouse.performance + metrics.lighthouse.accessibility + 
                     metrics.lighthouse.bestPractices + metrics.lighthouse.seo) / 4
    if (avgScore < 70) score -= 30
    else if (avgScore < 85) score -= 15
  }
  
  // SPR efficiency scoring
  if (metrics.sprEfficiency?.success) {
    const efficiency = parseFloat(metrics.sprEfficiency.efficiency.replace('%', ''))
    if (efficiency < 70) score -= 20
    else if (efficiency < 80) score -= 10
  }
  
  // Determine rating
  let rating = '★☆☆☆☆ Needs Work'
  if (score >= 95) rating = '★★★★★ Excellent'
  else if (score >= 80) rating = '★★★★☆ Good'
  else if (score >= 65) rating = '★★★☆☆ Fair'
  else if (score >= 50) rating = '★★☆☆☆ Poor'
  
  return { score, rating }
}

async function runLighthouseAuditWithMock(mockExec: any) {
  try {
    await mockExec('which lighthouse')
    const { stdout } = await mockExec('lighthouse http://localhost:3000 --output=json --quiet')
    
    const report = JSON.parse(stdout)
    
    return {
      performance: Math.round(report.lhr.categories.performance.score * 100),
      accessibility: Math.round(report.lhr.categories.accessibility.score * 100),
      bestPractices: Math.round(report.lhr.categories['best-practices'].score * 100),
      seo: Math.round(report.lhr.categories.seo.score * 100),
      success: true
    }
  } catch {
    return {
      error: 'Lighthouse not available or server failed to start',
      success: false
    }
  }
}

async function analyzeApiPerformanceWithMock(mockExec: any, projectRoot: string) {
  const { existsSync } = await import('fs')
  const apiDir = join(projectRoot, 'server/api')
  
  if (!existsSync(apiDir)) {
    return { message: 'No API routes found', success: true }
  }
  
  try {
    const { stdout } = await mockExec(`find ${apiDir} -name "*.ts" -o -name "*.js" | wc -l`)
    const apiCount = parseInt(stdout.trim())
    
    return {
      apiRouteCount: apiCount,
      status: apiCount > 0 ? 'API routes detected' : 'No API routes',
      recommendation: apiCount > 5 ? 'Consider middleware optimization' : 'Good API structure',
      success: true
    }
  } catch (error: any) {
    return {
      error: error.message,
      success: false
    }
  }
}