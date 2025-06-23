# CDCS Automation Agents
"""
Intelligent agents that use ollama/qwen3 for autonomous CDCS enhancement
"""

from . import pattern_miner
from . import memory_optimizer
from . import knowledge_synthesizer
from . import evolution_hunter
from . import predictive_loader
from . import system_health_monitor

__all__ = [
    'pattern_miner',
    'memory_optimizer',
    'knowledge_synthesizer',
    'evolution_hunter',
    'predictive_loader',
    'system_health_monitor'
]
