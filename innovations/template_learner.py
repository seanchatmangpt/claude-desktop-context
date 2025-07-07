"""
CDCS Template Learning System - Learn from successful patterns

This module learns patterns from successful CDCS sessions and commands,
creating reusable templates for common workflows.
"""

from pathlib import Path
from typing import Dict, List, Set, Tuple, Optional, Any
from dataclasses import dataclass, field
from collections import defaultdict, Counter
import json
import re
from datetime import datetime, timedelta


@dataclass
class CommandPattern:
    """Represents a discovered command pattern."""
    pattern_type: str  # morning, debugging, commit, etc.
    commands: List[str]
    frequency: int
    success_rate: float
    avg_duration: float  # minutes
    context_tags: Set[str] = field(default_factory=set)
    
    def matches(self, command_sequence: List[str]) -> float:
        """Calculate match score for a command sequence."""
        if not command_sequence or not self.commands:
            return 0.0
        
        # Simple sequence matching
        matches = 0
        for i, cmd in enumerate(self.commands):
            if i < len(command_sequence) and cmd in command_sequence[i]:
                matches += 1
        
        return matches / len(self.commands)
    
    def to_template(self) -> Dict[str, Any]:
        """Convert to reusable template."""
        return {
            'name': f"{self.pattern_type}_workflow",
            'description': f"Common {self.pattern_type} workflow pattern",
            'commands': self.commands,
            'tags': list(self.context_tags),
            'metrics': {
                'frequency': self.frequency,
                'success_rate': self.success_rate,
                'avg_duration': self.avg_duration
            }
        }


@dataclass
class SessionPattern:
    """Represents a successful session pattern."""
    pattern_id: str
    start_context: Dict[str, Any]
    end_context: Dict[str, Any]
    transformations: List[str]
    duration: float
    productivity_score: float
    
    def similarity(self, context: Dict[str, Any]) -> float:
        """Calculate similarity to a given context."""
        score = 0.0
        
        # Compare projects
        if 'projects' in context and 'projects' in self.start_context:
            start_projects = set(self.start_context['projects'])
            current_projects = set(context['projects'])
            if start_projects & current_projects:
                score += 0.3
        
        # Compare status
        if context.get('status') == self.start_context.get('status'):
            score += 0.2
        
        # Compare time of day (morning/afternoon/evening patterns)
        if 'time' in context and 'time' in self.start_context:
            hour_diff = abs(context['time'].hour - self.start_context['time'].hour)
            if hour_diff <= 2:
                score += 0.2
        
        # Compare work type
        if context.get('work_type') == self.start_context.get('work_type'):
            score += 0.3
        
        return score


class CDCSTemplateLearner:
    """Learn patterns from CDCS sessions and create templates."""
    
    def __init__(self, history_dir: Path = Path("/Users/sac/claude-desktop-context/history")):
        self.history_dir = history_dir
        self.command_patterns: Dict[str, CommandPattern] = {}
        self.session_patterns: List[SessionPattern] = []
        self.success_indicators = {
            'commit': ['git commit', 'git push'],
            'test_pass': ['test passed', 'all tests pass', '✓'],
            'completion': ['complete', 'done', 'finished'],
            'milestone': ['milestone', 'release', 'deploy']
        }
    
    def analyze_history(self, days: int = 30) -> Dict[str, Any]:
        """Analyze session history to find patterns."""
        results = {
            'command_patterns': [],
            'session_patterns': [],
            'productivity_insights': {},
            'recommendations': []
        }
        
        # Load session files
        sessions = self._load_recent_sessions(days)
        
        # Extract command sequences
        command_sequences = self._extract_command_sequences(sessions)
        
        # Find command patterns
        self.command_patterns = self._discover_command_patterns(command_sequences)
        results['command_patterns'] = list(self.command_patterns.values())
        
        # Find session patterns
        self.session_patterns = self._discover_session_patterns(sessions)
        results['session_patterns'] = self.session_patterns
        
        # Generate insights
        results['productivity_insights'] = self._analyze_productivity(sessions)
        
        # Generate recommendations
        results['recommendations'] = self._generate_recommendations()
        
        return results
    
    def _load_recent_sessions(self, days: int) -> List[Dict[str, Any]]:
        """Load recent session files."""
        sessions = []
        
        # In real implementation, would scan history directory
        # For now, create sample sessions
        sample_sessions = [
            {
                'timestamp': datetime.now() - timedelta(days=1),
                'duration': 180,  # minutes
                'commands': [
                    '/continue',
                    'git status',
                    'make test',
                    'fix errors',
                    'make test',
                    'git add -A',
                    'git commit -m "fix: test errors"',
                    'git push'
                ],
                'context': {
                    'projects': ['WeaverGen'],
                    'status': 'Active development',
                    'time': datetime.now().replace(hour=10)
                },
                'outcomes': ['commit', 'test_pass']
            },
            {
                'timestamp': datetime.now() - timedelta(days=2),
                'duration': 240,
                'commands': [
                    'make morning',
                    '/continue',
                    'review PR',
                    'implement feedback',
                    'test changes',
                    'git commit',
                    'push updates'
                ],
                'context': {
                    'projects': ['CDCS'],
                    'status': 'Feature development',
                    'time': datetime.now().replace(hour=9)
                },
                'outcomes': ['commit', 'milestone']
            }
        ]
        
        return sample_sessions + sessions
    
    def _extract_command_sequences(self, sessions: List[Dict[str, Any]]) -> List[List[str]]:
        """Extract command sequences from sessions."""
        sequences = []
        
        for session in sessions:
            if 'commands' in session:
                sequences.append(session['commands'])
        
        return sequences
    
    def _discover_command_patterns(self, sequences: List[List[str]]) -> Dict[str, CommandPattern]:
        """Discover common command patterns."""
        patterns = {}
        
        # Find common subsequences
        subsequence_counts = defaultdict(int)
        
        for sequence in sequences:
            # Extract all subsequences of length 2-5
            for length in range(2, min(6, len(sequence) + 1)):
                for i in range(len(sequence) - length + 1):
                    subseq = tuple(sequence[i:i+length])
                    subsequence_counts[subseq] += 1
        
        # Create patterns from frequent subsequences
        for subseq, count in subsequence_counts.items():
            if count >= 2:  # Appears at least twice
                pattern_type = self._classify_pattern(list(subseq))
                pattern_id = f"{pattern_type}_{len(subseq)}"
                
                patterns[pattern_id] = CommandPattern(
                    pattern_type=pattern_type,
                    commands=list(subseq),
                    frequency=count,
                    success_rate=0.8,  # Would calculate from outcomes
                    avg_duration=30.0,  # Would calculate from sessions
                    context_tags={pattern_type}
                )
        
        return patterns
    
    def _classify_pattern(self, commands: List[str]) -> str:
        """Classify a command pattern."""
        command_str = ' '.join(commands).lower()
        
        if 'git commit' in command_str or 'git push' in command_str:
            return 'commit'
        elif 'test' in command_str or 'pytest' in command_str:
            return 'testing'
        elif 'continue' in command_str or 'morning' in command_str:
            return 'startup'
        elif 'debug' in command_str or 'error' in command_str:
            return 'debugging'
        elif 'review' in command_str or 'analyze' in command_str:
            return 'review'
        else:
            return 'general'
    
    def _discover_session_patterns(self, sessions: List[Dict[str, Any]]) -> List[SessionPattern]:
        """Discover successful session patterns."""
        patterns = []
        
        # Group sessions by outcome success
        successful_sessions = [s for s in sessions 
                             if any(outcome in s.get('outcomes', []) 
                                   for outcome in ['commit', 'milestone', 'completion'])]
        
        # Create patterns from successful sessions
        for i, session in enumerate(successful_sessions):
            # Calculate productivity score
            productivity = self._calculate_productivity_score(session)
            
            # Extract transformations (what changed during session)
            transformations = self._extract_transformations(session)
            
            pattern = SessionPattern(
                pattern_id=f"session_{i}",
                start_context=session.get('context', {}),
                end_context=session.get('end_context', session.get('context', {})),
                transformations=transformations,
                duration=session.get('duration', 0),
                productivity_score=productivity
            )
            
            patterns.append(pattern)
        
        return patterns
    
    def _calculate_productivity_score(self, session: Dict[str, Any]) -> float:
        """Calculate productivity score for a session."""
        score = 0.5  # Base score
        
        # Positive indicators
        if 'commit' in session.get('outcomes', []):
            score += 0.2
        if 'test_pass' in session.get('outcomes', []):
            score += 0.1
        if 'milestone' in session.get('outcomes', []):
            score += 0.3
        
        # Time efficiency
        duration = session.get('duration', 180)
        if duration < 120:  # Under 2 hours
            score += 0.1
        elif duration > 300:  # Over 5 hours
            score -= 0.1
        
        # Command efficiency
        commands = session.get('commands', [])
        if commands:
            unique_commands = len(set(commands))
            if unique_commands / len(commands) > 0.7:  # Low repetition
                score += 0.1
        
        return min(1.0, max(0.0, score))
    
    def _extract_transformations(self, session: Dict[str, Any]) -> List[str]:
        """Extract what transformed during the session."""
        transformations = []
        
        # Check for code changes
        commands = session.get('commands', [])
        if any('commit' in cmd for cmd in commands):
            transformations.append('code_committed')
        
        if any('test' in cmd for cmd in commands):
            transformations.append('tests_run')
        
        if any('fix' in cmd or 'debug' in cmd for cmd in commands):
            transformations.append('issues_resolved')
        
        if any('implement' in cmd or 'add' in cmd for cmd in commands):
            transformations.append('features_added')
        
        return transformations
    
    def _analyze_productivity(self, sessions: List[Dict[str, Any]]) -> Dict[str, Any]:
        """Analyze productivity patterns."""
        insights = {
            'most_productive_time': None,
            'avg_session_duration': 0,
            'success_rate': 0,
            'common_blockers': [],
            'optimization_opportunities': []
        }
        
        if not sessions:
            return insights
        
        # Time analysis
        time_productivity = defaultdict(list)
        for session in sessions:
            if 'context' in session and 'time' in session['context']:
                hour = session['context']['time'].hour
                score = self._calculate_productivity_score(session)
                time_productivity[hour].append(score)
        
        # Find most productive time
        best_hour = max(time_productivity.items(), 
                       key=lambda x: sum(x[1])/len(x[1]) if x[1] else 0)
        insights['most_productive_time'] = f"{best_hour[0]:02d}:00"
        
        # Duration analysis
        durations = [s.get('duration', 0) for s in sessions if s.get('duration')]
        if durations:
            insights['avg_session_duration'] = sum(durations) / len(durations)
        
        # Success rate
        successful = len([s for s in sessions 
                         if any(o in s.get('outcomes', []) 
                               for o in self.success_indicators)])
        insights['success_rate'] = successful / len(sessions) if sessions else 0
        
        # Common blockers (commands that appear before 'fix' or 'debug')
        insights['common_blockers'] = self._find_common_blockers(sessions)
        
        # Optimization opportunities
        insights['optimization_opportunities'] = self._find_optimizations(sessions)
        
        return insights
    
    def _find_common_blockers(self, sessions: List[Dict[str, Any]]) -> List[str]:
        """Find common blockers from command patterns."""
        blocker_patterns = []
        
        for session in sessions:
            commands = session.get('commands', [])
            for i, cmd in enumerate(commands):
                if 'fix' in cmd or 'debug' in cmd or 'error' in cmd:
                    if i > 0:
                        # Previous command might be the blocker
                        blocker_patterns.append(commands[i-1])
        
        # Return most common blockers
        if blocker_patterns:
            counter = Counter(blocker_patterns)
            return [pattern for pattern, _ in counter.most_common(3)]
        
        return []
    
    def _find_optimizations(self, sessions: List[Dict[str, Any]]) -> List[str]:
        """Find optimization opportunities."""
        optimizations = []
        
        # Check for repeated commands
        for session in sessions:
            commands = session.get('commands', [])
            repeated = [cmd for cmd in set(commands) if commands.count(cmd) > 2]
            if repeated:
                optimizations.append(f"Automate repeated command: {repeated[0]}")
        
        # Check for long sessions without commits
        long_sessions = [s for s in sessions 
                        if s.get('duration', 0) > 240 
                        and 'commit' not in s.get('outcomes', [])]
        if long_sessions:
            optimizations.append("Consider more frequent commits in long sessions")
        
        # Check for test-fix cycles
        test_fix_cycles = 0
        for session in sessions:
            commands = session.get('commands', [])
            for i in range(len(commands) - 1):
                if 'test' in commands[i] and 'fix' in commands[i+1]:
                    test_fix_cycles += 1
        
        if test_fix_cycles > len(sessions) / 2:
            optimizations.append("Consider test-driven development to reduce fix cycles")
        
        return optimizations[:5]  # Top 5 optimizations
    
    def _generate_recommendations(self) -> List[str]:
        """Generate recommendations based on patterns."""
        recommendations = []
        
        # Command pattern recommendations
        for pattern in self.command_patterns.values():
            if pattern.frequency > 5 and pattern.success_rate > 0.8:
                recommendations.append(
                    f"Create alias for {pattern.pattern_type} workflow: "
                    f"{' → '.join(pattern.commands[:3])}"
                )
        
        # Session pattern recommendations  
        high_productivity = [p for p in self.session_patterns 
                           if p.productivity_score > 0.8]
        if high_productivity:
            recommendations.append(
                f"Replicate high-productivity patterns from "
                f"{len(high_productivity)} successful sessions"
            )
        
        return recommendations
    
    def generate_workflow_templates(self) -> Dict[str, Any]:
        """Generate reusable workflow templates."""
        templates = {
            'command_macros': [],
            'session_templates': [],
            'automation_scripts': []
        }
        
        # Command macros
        for pattern in self.command_patterns.values():
            if pattern.frequency >= 3:
                templates['command_macros'].append({
                    'name': f"macro_{pattern.pattern_type}",
                    'description': f"Common {pattern.pattern_type} workflow",
                    'commands': pattern.commands,
                    'usage_count': pattern.frequency,
                    'tags': list(pattern.context_tags)
                })
        
        # Session templates
        for pattern in self.session_patterns[:5]:  # Top 5
            if pattern.productivity_score > 0.7:
                templates['session_templates'].append({
                    'name': f"session_template_{pattern.pattern_id}",
                    'description': f"High-productivity session pattern",
                    'start_context': pattern.start_context,
                    'expected_duration': pattern.duration,
                    'transformations': pattern.transformations,
                    'productivity_score': pattern.productivity_score
                })
        
        # Automation scripts
        for pattern in self.command_patterns.values():
            if pattern.frequency >= 5 and len(pattern.commands) >= 3:
                script = self._generate_automation_script(pattern)
                templates['automation_scripts'].append(script)
        
        return templates
    
    def _generate_automation_script(self, pattern: CommandPattern) -> Dict[str, str]:
        """Generate automation script for a pattern."""
        script_lines = [
            "#!/bin/bash",
            f"# Auto-generated {pattern.pattern_type} workflow",
            f"# Based on {pattern.frequency} observed instances",
            ""
        ]
        
        for cmd in pattern.commands:
            # Convert commands to bash-friendly format
            if cmd.startswith('/'):
                script_lines.append(f"# Claude command: {cmd}")
            else:
                script_lines.append(cmd)
        
        return {
            'name': f"{pattern.pattern_type}_auto.sh",
            'content': '\n'.join(script_lines),
            'pattern_type': pattern.pattern_type
        }
    
    def predict_next_commands(self, current_commands: List[str], 
                            context: Dict[str, Any]) -> List[Tuple[str, float]]:
        """Predict likely next commands based on patterns."""
        predictions = []
        
        # Check command patterns
        for pattern in self.command_patterns.values():
            match_score = pattern.matches(current_commands)
            if match_score > 0.5:
                # Predict next commands from pattern
                pattern_index = len(current_commands)
                if pattern_index < len(pattern.commands):
                    next_cmd = pattern.commands[pattern_index]
                    predictions.append((next_cmd, match_score * pattern.success_rate))
        
        # Check session patterns
        for session_pattern in self.session_patterns:
            similarity = session_pattern.similarity(context)
            if similarity > 0.6:
                # Use transformations to predict commands
                for transform in session_pattern.transformations:
                    if transform == 'code_committed':
                        predictions.append(('git commit', similarity * 0.8))
                    elif transform == 'tests_run':
                        predictions.append(('make test', similarity * 0.7))
        
        # Sort by confidence and deduplicate
        predictions.sort(key=lambda x: x[1], reverse=True)
        seen = set()
        unique_predictions = []
        for cmd, conf in predictions:
            if cmd not in seen:
                seen.add(cmd)
                unique_predictions.append((cmd, conf))
        
        return unique_predictions[:5]  # Top 5 predictions


# Integration functions
def learn_from_cdcs_history():
    """Learn patterns from CDCS history."""
    learner = CDCSTemplateLearner()
    
    print("🧠 Learning from CDCS session history...")
    results = learner.analyze_history(days=30)
    
    print(f"\n📊 Discovered Patterns:")
    print(f"- Command Patterns: {len(results['command_patterns'])}")
    print(f"- Session Patterns: {len(results['session_patterns'])}")
    
    print("\n💡 Productivity Insights:")
    insights = results['productivity_insights']
    print(f"- Most Productive Time: {insights.get('most_productive_time', 'Unknown')}")
    print(f"- Average Session Duration: {insights.get('avg_session_duration', 0):.0f} minutes")
    print(f"- Success Rate: {insights.get('success_rate', 0):.0%}")
    
    print("\n🚀 Recommendations:")
    for rec in results['recommendations'][:3]:
        print(f"- {rec}")
    
    # Generate templates
    templates = learner.generate_workflow_templates()
    
    # Save templates
    template_path = Path("/Users/sac/claude-desktop-context/learned_templates.json")
    with open(template_path, 'w') as f:
        json.dump(templates, f, indent=2, default=str)
    
    print(f"\n📁 Templates saved to: {template_path}")
    
    return learner


if __name__ == "__main__":
    learn_from_cdcs_history()