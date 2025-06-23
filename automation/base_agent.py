#!/usr/bin/env python3
"""
Base Agent for CDCS Automation
Simple base class that OTel base agent extends
"""

import logging
from pathlib import Path
from datetime import datetime

class BaseAgent:
    """Basic agent functionality"""
    
    def __init__(self, orchestrator, agent_name: str):
        self.orchestrator = orchestrator
        self.agent_name = agent_name
        self.base_path = orchestrator.base_path if orchestrator else Path("/Users/sac/claude-desktop-context")
        
        # Setup logging
        self.logger = logging.getLogger(agent_name)
        self.logger.setLevel(logging.INFO)
        
        # Console handler
        if not self.logger.handlers:
            handler = logging.StreamHandler()
            formatter = logging.Formatter(
                f'[%(asctime)s] [{agent_name}] %(levelname)s: %(message)s',
                datefmt='%Y-%m-%d %H:%M:%S'
            )
            handler.setFormatter(formatter)
            self.logger.addHandler(handler)
    
    def run(self):
        """Override in subclasses"""
        self.logger.info(f"{self.agent_name} running...")
        raise NotImplementedError("Subclasses must implement run()")
    
    def log_discovery(self, discovery_type: str, details: str):
        """Log a discovery or pattern"""
        timestamp = datetime.now().isoformat()
        self.logger.info(f"Discovery [{discovery_type}]: {details}")
        
        # Could write to file or database here
        discovery_path = self.base_path / "automation" / "discoveries.log"
        discovery_path.parent.mkdir(exist_ok=True)
        
        with discovery_path.open('a') as f:
            f.write(f"{timestamp} | {self.agent_name} | {discovery_type} | {details}\n")
