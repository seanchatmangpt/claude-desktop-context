import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // Enable Cucumber/Gherkin integration
    include: [
      'features/**/*.feature',
      'test/cucumber/**/*.steps.ts'
    ],
    globals: true,
    environment: 'node',
    setupFiles: ['test/setup.ts'],
    // Cucumber-specific configuration
    cucumber: {
      features: 'features/**/*.feature',
      stepDefinitions: 'test/cucumber/step-definitions/**/*.steps.ts',
      requireModule: ['ts-node/register'],
      format: [
        'pretty',
        'json:test-results/cucumber-report.json',
        'html:test-results/cucumber-report.html'
      ],
      parallel: 2,
      retry: 1,
      timeout: 30000
    },
    coverage: {
      reporter: ['text', 'json', 'html'],
      exclude: [
        'node_modules/',
        'test/',
        'features/',
        '**/*.config.*',
        '**/*.steps.ts'
      ],
      thresholds: {
        global: {
          branches: 80,
          functions: 80,
          lines: 80,
          statements: 80
        }
      }
    }
  }
})