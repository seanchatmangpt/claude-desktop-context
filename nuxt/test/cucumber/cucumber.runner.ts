#!/usr/bin/env node
/**
 * Cucumber test runner for Vitest integration
 * Runs Gherkin feature files with step definitions
 */

import { runCli } from '@cucumber/cucumber/api'
import { join } from 'path'
import { existsSync } from 'fs'

const projectRoot = process.cwd()
const featuresDir = join(projectRoot, 'features')
const stepDefinitionsDir = join(projectRoot, 'test/cucumber/step-definitions')

async function runCucumberTests() {
  if (!existsSync(featuresDir)) {
    console.error('Features directory not found:', featuresDir)
    process.exit(1)
  }
  
  if (!existsSync(stepDefinitionsDir)) {
    console.error('Step definitions directory not found:', stepDefinitionsDir)
    process.exit(1)
  }
  
  const args = [
    featuresDir,
    '--require-module', 'ts-node/register',
    '--require', stepDefinitionsDir + '/**/*.steps.ts',
    '--format', 'pretty',
    '--format', 'json:test-results/cucumber-report.json',
    '--format', 'html:test-results/cucumber-report.html',
    '--parallel', '2',
    '--retry', '1',
    ...process.argv.slice(2) // Pass through any additional args
  ]
  
  try {
    const result = await runCli({
      argv: ['node', 'cucumber-js', ...args],
      cwd: projectRoot,
      stdout: process.stdout,
      stderr: process.stderr,
      env: process.env
    })
    
    process.exit(result.success ? 0 : 1)
  } catch (error) {
    console.error('Cucumber test execution failed:', error)
    process.exit(1)
  }
}

// Helper function to run specific feature
export async function runFeature(featureName: string) {
  const featurePath = join(featuresDir, `${featureName}.feature`)
  
  if (!existsSync(featurePath)) {
    throw new Error(`Feature file not found: ${featurePath}`)
  }
  
  const args = [
    featurePath,
    '--require-module', 'ts-node/register',
    '--require', stepDefinitionsDir + '/**/*.steps.ts',
    '--format', 'pretty'
  ]
  
  return await runCli({
    argv: ['node', 'cucumber-js', ...args],
    cwd: projectRoot,
    stdout: process.stdout,
    stderr: process.stderr,
    env: process.env
  })
}

// Helper function to run specific scenario
export async function runScenario(featureName: string, scenarioName: string) {
  const featurePath = join(featuresDir, `${featureName}.feature`)
  
  const args = [
    featurePath,
    '--require-module', 'ts-node/register',
    '--require', stepDefinitionsDir + '/**/*.steps.ts',
    '--format', 'pretty',
    '--name', `"${scenarioName}"`
  ]
  
  return await runCli({
    argv: ['node', 'cucumber-js', ...args],
    cwd: projectRoot,
    stdout: process.stdout,
    stderr: process.stderr,
    env: process.env
  })
}

// Run if called directly
if (require.main === module) {
  runCucumberTests()
}