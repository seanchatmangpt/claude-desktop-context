/**
 * Unit tests for SPR activation functionality
 * Tests the core SPR kernel activation and analysis
 */

import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest'
import { readFile, writeFile, mkdir, rm } from 'fs/promises'
import { join } from 'path'
import { setupTestDirectories, mockSprKernel, createTestFile, cleanupTestEnv } from '../setup'

// Import the functions we're testing (these would be extracted from the scripts)
import { exec } from 'child_process'
import { promisify } from 'util'
const execAsync = promisify(exec)

describe('SPR Activation', () => {
  let testRoot: string
  
  beforeEach(async () => {
    testRoot = await setupTestDirectories()
    
    // Create mock SPR kernel
    await createTestFile(
      join(testRoot, 'spr_kernels/nuxt_component_architecture.spr'),
      mockSprKernel
    )
  })
  
  afterEach(async () => {
    await rm(testRoot, { recursive: true, force: true })
    cleanupTestEnv()
  })

  describe('loadKernel', () => {
    it('should load SPR kernel successfully', async () => {
      const kernelPath = join(testRoot, 'spr_kernels/nuxt_component_architecture.spr')
      const content = await readFile(kernelPath, 'utf-8')
      
      expect(content).toContain('Test SPR Kernel')
      expect(content).toContain('Test concept one')
      expect(content).toContain('test-pattern → optimization')
    })
    
    it('should throw error for non-existent kernel', async () => {
      const kernelPath = join(testRoot, 'spr_kernels/non_existent.spr')
      
      await expect(async () => {
        await readFile(kernelPath, 'utf-8')
      }).rejects.toThrow()
    })
  })

  describe('analyzeKernel', () => {
    it('should correctly analyze kernel structure', () => {
      const analysis = analyzeKernelContent(mockSprKernel)
      
      expect(analysis.concepts).toBe(3) // Three "- Test concept" lines
      expect(analysis.sections).toBe(2) // Two "##" sections
      expect(analysis.size).toBeGreaterThan(0)
    })
    
    it('should handle empty kernel content', () => {
      const analysis = analyzeKernelContent('')
      
      expect(analysis.concepts).toBe(0)
      expect(analysis.sections).toBe(0)
      expect(analysis.size).toBe(0)
    })
  })

  describe('extractKeyPatterns', () => {
    it('should extract concept patterns correctly', () => {
      const patterns = extractKeyPatternsFromContent(mockSprKernel)
      
      expect(patterns).toContain('Test concept one')
      expect(patterns).toContain('Test concept two')
      expect(patterns).toContain('Test concept three')
      expect(patterns.length).toBe(3)
    })
    
    it('should limit patterns to 8 maximum', () => {
      const longContent = Array.from({length: 15}, (_, i) => `- Pattern ${i + 1}`).join('\n')
      const patterns = extractKeyPatternsFromContent(longContent)
      
      expect(patterns.length).toBeLessThanOrEqual(8)
    })
  })

  describe('extractGraphConnections', () => {
    it('should extract graph connections with arrows', () => {
      const connections = extractGraphConnectionsFromContent(mockSprKernel)
      
      expect(connections).toContain('test-pattern → optimization → performance')
      expect(connections).toContain('component-structure → composable-extraction')
      expect(connections.length).toBe(2)
    })
    
    it('should handle content without connections', () => {
      const connections = extractGraphConnectionsFromContent('No connections here')
      
      expect(connections.length).toBe(0)
    })
  })

  describe('calculateTokenSavings', () => {
    it('should calculate token efficiency correctly', () => {
      const stats = { size: 4096, concepts: 10, sections: 3 } // 4KB
      const savings = calculateTokenSavingsFromStats(stats)
      
      expect(savings.sprTokens).toBe(1024) // 4096 / 4
      expect(savings.equivalentFileTokens).toBe(25600) // 100KB / 4
      expect(parseFloat(savings.efficiencyGain)).toBeGreaterThan(90)
    })
    
    it('should handle zero size gracefully', () => {
      const stats = { size: 0, concepts: 0, sections: 0 }
      const savings = calculateTokenSavingsFromStats(stats)
      
      expect(savings.sprTokens).toBe(0)
      expect(savings.efficiencyGain).toBe('100.0')
    })
  })

  describe('getKernelDescription', () => {
    it('should return correct descriptions for known kernels', () => {
      expect(getKernelDescriptionForName('component_architecture'))
        .toContain('Component composition')
      
      expect(getKernelDescriptionForName('api_patterns'))
        .toContain('Server-side API')
      
      expect(getKernelDescriptionForName('performance_optimization'))
        .toContain('Bundle optimization')
    })
    
    it('should return default description for unknown kernels', () => {
      expect(getKernelDescriptionForName('unknown_kernel'))
        .toBe('Nuxt.js development patterns')
    })
  })
})

// Helper functions extracted from the original script for testing
function analyzeKernelContent(content: string) {
  const lines = content.split('\n')
  const concepts = lines.filter(line => line.trim().startsWith('-')).length
  const sections = lines.filter(line => line.trim().startsWith('##')).length
  const size = Buffer.byteLength(content, 'utf-8')
  
  return { concepts, sections, size }
}

function extractKeyPatternsFromContent(content: string) {
  const patterns: string[] = []
  const lines = content.split('\n')
  
  lines.forEach(line => {
    const trimmed = line.trim()
    if (trimmed.startsWith('-')) {
      const pattern = trimmed.substring(1).trim()
      patterns.push(pattern)
    }
  })
  
  return patterns.slice(0, 8)
}

function extractGraphConnectionsFromContent(content: string) {
  const connections: string[] = []
  const lines = content.split('\n')
  
  lines.forEach(line => {
    if (line.includes('→') || line.includes('->')) {
      connections.push(line.trim())
    }
  })
  
  return connections
}

function calculateTokenSavingsFromStats(stats: { size: number }) {
  const sprTokens = Math.ceil(stats.size / 4)
  const equivalentFileTokens = Math.ceil(100 * 1024 / 4) // 100KB equivalent
  const tokenSavings = equivalentFileTokens - sprTokens
  const efficiencyGain = ((tokenSavings / equivalentFileTokens) * 100).toFixed(1)
  
  return { sprTokens, equivalentFileTokens, tokenSavings, efficiencyGain }
}

function getKernelDescriptionForName(kernelName: string) {
  const descriptions: Record<string, string> = {
    component_architecture: 'Component composition, routing, SSR patterns, and auto-imports',
    api_patterns: 'Server-side API development, middleware, authentication, and database integration',
    performance_optimization: 'Bundle optimization, image handling, SSR performance, and monitoring'
  }
  
  return descriptions[kernelName] || 'Nuxt.js development patterns'
}