/**
 * Global test setup for Nuxt CDCS testing
 * Configures test environment and mocks
 */

import { vi } from 'vitest'
import { mkdir, writeFile } from 'fs/promises'
import { join } from 'path'

// Mock console methods to reduce noise in tests
const originalConsole = global.console
global.console = {
  ...originalConsole,
  log: vi.fn(),
  info: vi.fn(),
  warn: vi.fn(),
  error: originalConsole.error // Keep errors visible
}

// Setup test directories
export async function setupTestDirectories() {
  const testRoot = join(process.cwd(), 'test-temp', `test-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`)
  
  // Create test project structure
  await mkdir(join(testRoot, '.cdcs'), { recursive: true })
  await mkdir(join(testRoot, 'spr_kernels'), { recursive: true })
  await mkdir(join(testRoot, 'components'), { recursive: true })
  await mkdir(join(testRoot, 'pages'), { recursive: true })
  await mkdir(join(testRoot, 'server/api'), { recursive: true })
  await mkdir(join(testRoot, 'composables'), { recursive: true })
  
  return testRoot
}

// Mock SPR kernel
export const mockSprKernel = `# Test SPR Kernel
## Core Concepts
- Test concept one
- Test concept two
- Test concept three

## Pattern Connections
test-pattern → optimization → performance
component-structure → composable-extraction
`

// Mock package.json
export const mockPackageJson = {
  name: 'test-nuxt-project',
  version: '1.0.0',
  dependencies: {
    nuxt: '^3.9.0'
  },
  scripts: {
    dev: 'nuxt dev',
    build: 'nuxt build'
  },
  cdcs: {
    version: '3.0.0',
    sprKernels: ['test_kernel'],
    tokenEfficiency: '93%'
  }
}

// Mock prediction results
export const mockPredictions = {
  timestamp: new Date().toISOString(),
  predictions: {
    highProbability: [
      {
        need: 'Composable extraction',
        reason: '3 components share logic',
        action: 'Create shared composable',
        sprKernel: 'nuxt_component_architecture'
      }
    ],
    mediumProbability: [
      {
        need: 'Performance optimization',
        reason: 'Bundle size growing',
        action: 'Implement lazy loading',
        sprKernel: 'nuxt_performance_optimization'
      }
    ],
    lowProbability: []
  },
  sprRecommendations: [
    {
      action: 'Activate nuxt_component_architecture.spr',
      reason: 'Component development patterns detected',
      command: 'npm run spr:activate component_architecture'
    }
  ]
}

// Mock benchmark results
export const mockBenchmarkResults = {
  timestamp: new Date().toISOString(),
  metrics: {
    buildTime: {
      buildTime: 25000,
      buildTimeSeconds: '25.00',
      success: true
    },
    bundleSize: {
      totalSize: '180KB',
      clientSize: '120KB',
      serverSize: '60KB',
      success: true
    },
    sprEfficiency: {
      totalSprSize: '8KB',
      totalConcepts: 15,
      efficiency: '92%',
      tokenReduction: '90%',
      success: true
    }
  },
  rating: {
    score: 88,
    rating: '★★★★☆ Good'
  }
}

// Helper to create test files
export async function createTestFile(filePath: string, content: string) {
  await writeFile(filePath, content, 'utf-8')
}

// Clean up after tests
export function cleanupTestEnv() {
  vi.restoreAllMocks()
}