#!/usr/bin/env python3
"""
Unified CDCS-XAVOS Agent Example

This demonstrates an agent that leverages both CDCS's information-theoretic
capabilities and XAVOS's enterprise coordination features.
"""

import asyncio
import json
import subprocess
import time
from pathlib import Path
from typing import Dict, Any, Optional
import logging

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class UnifiedCDCSXAVOSAgent:
    """
    An agent that combines CDCS pattern detection with XAVOS coordination.
    """
    
    def __init__(self, agent_id: Optional[str] = None):
        self.agent_id = agent_id or f"unified_agent_{time.time_ns()}"
        self.cdcs_dir = Path("/Users/sac/claude-desktop-context")
        self.xavos_dir = Path("/Users/sac/dev/ai-self-sustaining-system")
        self.coordination_helper = self.xavos_dir / "agent_coordination" / "coordination_helper.sh"
        self.bridge_script = self.cdcs_dir / "cdcs_xavos_bridge.sh"
        
        # Agent state
        self.current_work = None
        self.patterns_detected = []
        self.completed_tasks = 0
        
        logger.info(f"Initialized unified agent: {self.agent_id}")
    
    async def run(self):
        """Main agent loop combining both systems."""
        logger.info(f"Starting unified agent {self.agent_id}")
        
        # Start heartbeat for work freshness
        await self.start_heartbeat()
        
        try:
            while True:
                # Phase 1: Pattern Detection (CDCS)
                patterns = await self.detect_cdcs_patterns()
                
                # Phase 2: Work Prioritization (XAVOS)
                priorities = await self.analyze_xavos_priorities()
                
                # Phase 3: Unified Decision Making
                work_item = await self.decide_next_work(patterns, priorities)
                
                if work_item:
                    # Phase 4: Claim and Process Work
                    if await self.claim_work(work_item):
                        result = await self.process_work(work_item)
                        await self.complete_work(work_item, result)
                        self.completed_tasks += 1
                
                # Phase 5: Self-Improvement Check
                if self.should_trigger_improvement():
                    await self.trigger_improvement_cycle()
                
                # Brief pause between cycles
                await asyncio.sleep(5)
                
        except KeyboardInterrupt:
            logger.info("Agent interrupted by user")
        except Exception as e:
            logger.error(f"Agent error: {e}")
        finally:
            await self.cleanup()
    
    async def detect_cdcs_patterns(self) -> Dict[str, Any]:
        """Detect patterns using CDCS entropy analysis."""
        logger.debug("Detecting CDCS patterns...")
        
        # Simulate CDCS pattern detection
        # In production, would use actual CDCS pattern detection
        patterns = {
            "detected": [
                {
                    "type": "code_duplication",
                    "entropy": 4.2,
                    "significance": 850,
                    "location": "coordination_functions"
                },
                {
                    "type": "performance_bottleneck", 
                    "entropy": 6.1,
                    "significance": 1200,
                    "location": "json_processing"
                }
            ],
            "total_entropy": 5.8,
            "compression_opportunity": 0.22
        }
        
        self.patterns_detected = patterns["detected"]
        return patterns
    
    async def analyze_xavos_priorities(self) -> Dict[str, Any]:
        """Analyze work priorities using XAVOS coordination."""
        logger.debug("Analyzing XAVOS priorities...")
        
        # Call XAVOS coordination helper
        try:
            result = subprocess.run(
                [str(self.coordination_helper), "claude-analyze-priorities"],
                capture_output=True,
                text=True,
                timeout=30
            )
            
            if result.returncode == 0:
                # Parse priority analysis from output
                # In production, would parse actual JSON output
                return {
                    "priorities": [
                        {"work_type": "optimization", "score": 95},
                        {"work_type": "refactoring", "score": 82},
                        {"work_type": "documentation", "score": 65}
                    ]
                }
        except Exception as e:
            logger.warning(f"XAVOS priority analysis failed: {e}")
        
        # Fallback priorities
        return {"priorities": [{"work_type": "general", "score": 50}]}
    
    async def decide_next_work(self, patterns: Dict, priorities: Dict) -> Optional[Dict]:
        """Unified decision making combining both systems."""
        logger.debug("Making unified work decision...")
        
        # Combine pattern significance with priority scores
        work_candidates = []
        
        # Generate work from patterns
        for pattern in patterns.get("detected", []):
            work_candidates.append({
                "id": f"work_{time.time_ns()}",
                "type": f"fix_{pattern['type']}",
                "description": f"Address {pattern['type']} in {pattern['location']}",
                "score": pattern["significance"] / 10,  # Normalize
                "source": "cdcs_pattern"
            })
        
        # Add XAVOS priorities
        for priority in priorities.get("priorities", []):
            work_candidates.append({
                "id": f"work_{time.time_ns()}_2",
                "type": priority["work_type"],
                "description": f"XAVOS priority: {priority['work_type']}",
                "score": priority["score"],
                "source": "xavos_priority"
            })
        
        # Sort by score and return highest
        work_candidates.sort(key=lambda x: x["score"], reverse=True)
        
        if work_candidates:
            selected = work_candidates[0]
            logger.info(f"Selected work: {selected['description']} (score: {selected['score']})")
            return selected
        
        return None
    
    async def claim_work(self, work_item: Dict) -> bool:
        """Claim work using XAVOS atomic coordination."""
        logger.info(f"Claiming work: {work_item['description']}")
        
        try:
            result = subprocess.run(
                [
                    str(self.coordination_helper),
                    "claim",
                    work_item["type"],
                    work_item["description"],
                    "high",
                    "unified_team"
                ],
                capture_output=True,
                text=True,
                env={**os.environ, "AGENT_ID": self.agent_id}
            )
            
            if result.returncode == 0 and "SUCCESS" in result.stdout:
                # Extract work ID from output
                for line in result.stdout.split('\n'):
                    if "Claimed work item" in line:
                        work_id = line.split()[-1]
                        work_item["claimed_id"] = work_id
                        self.current_work = work_item
                        return True
        except Exception as e:
            logger.error(f"Failed to claim work: {e}")
        
        return False
    
    async def process_work(self, work_item: Dict) -> Dict:
        """Process work combining CDCS and XAVOS capabilities."""
        logger.info(f"Processing work: {work_item['description']}")
        
        # Simulate work processing
        # In production, would perform actual work
        
        result = {
            "status": "success",
            "progress": 0,
            "output": {}
        }
        
        # Update progress periodically
        for progress in [25, 50, 75, 100]:
            await asyncio.sleep(2)  # Simulate work
            
            # Update XAVOS progress
            if "claimed_id" in work_item:
                subprocess.run(
                    [
                        str(self.coordination_helper),
                        "progress",
                        work_item["claimed_id"],
                        str(progress),
                        "in_progress"
                    ]
                )
            
            result["progress"] = progress
            logger.debug(f"Progress: {progress}%")
        
        # Add work results
        if work_item["source"] == "cdcs_pattern":
            result["output"]["entropy_reduced"] = 0.5
            result["output"]["compression_achieved"] = 0.15
        else:
            result["output"]["velocity_points"] = 8
        
        return result
    
    async def complete_work(self, work_item: Dict, result: Dict):
        """Complete work and update both systems."""
        logger.info(f"Completing work: {work_item['description']}")
        
        # Complete in XAVOS
        if "claimed_id" in work_item:
            velocity_points = result["output"].get("velocity_points", 5)
            subprocess.run(
                [
                    str(self.coordination_helper),
                    "complete",
                    work_item["claimed_id"],
                    result["status"],
                    str(velocity_points)
                ]
            )
        
        # Update CDCS metrics (in production)
        # self.update_cdcs_metrics(result)
        
        self.current_work = None
    
    def should_trigger_improvement(self) -> bool:
        """Determine if self-improvement should be triggered."""
        # Trigger every 10 completed tasks
        return self.completed_tasks > 0 and self.completed_tasks % 10 == 0
    
    async def trigger_improvement_cycle(self):
        """Trigger unified self-improvement cycle."""
        logger.info("Triggering self-improvement cycle...")
        
        try:
            subprocess.run(
                [str(self.bridge_script), "self-improve"],
                timeout=60
            )
        except Exception as e:
            logger.error(f"Self-improvement failed: {e}")
    
    async def start_heartbeat(self):
        """Start XAVOS heartbeat daemon."""
        try:
            subprocess.run(
                [str(self.coordination_helper), "heartbeat-start"]
            )
            logger.info("Heartbeat daemon started")
        except Exception as e:
            logger.warning(f"Failed to start heartbeat: {e}")
    
    async def cleanup(self):
        """Cleanup agent resources."""
        logger.info("Cleaning up agent resources...")
        
        # Complete any pending work
        if self.current_work and "claimed_id" in self.current_work:
            await self.complete_work(
                self.current_work,
                {"status": "interrupted", "progress": 0, "output": {}}
            )
        
        # Stop heartbeat
        try:
            subprocess.run(
                [str(self.coordination_helper), "heartbeat-stop"]
            )
        except:
            pass


async def main():
    """Run the unified agent."""
    import os
    
    # Configuration
    os.environ["AI_PROVIDER"] = "auto"  # Use both Claude and Ollama
    
    # Create and run agent
    agent = UnifiedCDCSXAVOSAgent()
    await agent.run()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nAgent stopped by user")
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()