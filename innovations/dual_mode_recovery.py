"""
Dual-Mode Session Recovery - Works with or without full session data

This module implements flexible session recovery that can work with
partial data, corrupted files, or even reconstruct from workspace.
"""

from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime
import json
import subprocess
import os


@dataclass
class RecoveryConfig:
    """Configuration for dual-mode recovery."""
    prefer_spr: bool = True
    auto_reconstruct: bool = True
    use_git_history: bool = True
    use_ai_enhancement: bool = False
    cache_results: bool = True
    workspace_paths: List[Path] = None
    
    def __post_init__(self):
        if self.workspace_paths is None:
            self.workspace_paths = [
                Path("/Users/sac/dev"),
                Path("/Users/sac/claude-desktop-context")
            ]


class DualModeSessionRecovery:
    """Flexible session recovery with multiple fallback strategies."""
    
    def __init__(self, config: Optional[RecoveryConfig] = None):
        self.config = config or RecoveryConfig()
        self.recovery_strategies = [
            self._recover_from_spr,
            self._recover_from_checkpoint,
            self._recover_from_git,
            self._recover_from_workspace,
            self._recover_from_scratch
        ]
    
    def recover_session(self, 
                       force_mode: Optional[str] = None) -> Dict[str, Any]:
        """
        Recover session using best available method.
        
        Args:
            force_mode: Force specific mode ('spr', 'git', 'workspace', 'auto')
        
        Returns:
            Recovered session data with confidence scores
        """
        print("🔄 Initiating Dual-Mode Session Recovery")
        
        if force_mode:
            return self._force_recovery_mode(force_mode)
        
        # Try each strategy in order
        for strategy in self.recovery_strategies:
            try:
                result = strategy()
                if result and result.get('confidence', 0) > 0.5:
                    result['recovery_method'] = strategy.__name__
                    return self._enhance_result(result)
            except Exception as e:
                print(f"  ❌ {strategy.__name__} failed: {e}")
                continue
        
        # If all strategies fail, return minimal session
        return self._create_minimal_session()
    
    def _force_recovery_mode(self, mode: str) -> Dict[str, Any]:
        """Force specific recovery mode."""
        mode_map = {
            'spr': self._recover_from_spr,
            'git': self._recover_from_git,
            'workspace': self._recover_from_workspace,
            'checkpoint': self._recover_from_checkpoint
        }
        
        if mode in mode_map:
            return mode_map[mode]()
        else:
            raise ValueError(f"Unknown recovery mode: {mode}")
    
    def _recover_from_spr(self) -> Dict[str, Any]:
        """Recover from session_recovery.spr file."""
        spr_path = Path("/Users/sac/claude-desktop-context/session_recovery.spr")
        
        if not spr_path.exists():
            raise FileNotFoundError("SPR file not found")
        
        print("  ✅ Found session_recovery.spr")
        
        # Parse SPR content
        from .direct_session_parser import DirectSessionParser
        parser = DirectSessionParser()
        session_data = parser.parse_spr_file(spr_path)
        
        # Add recovery metadata
        session_data['confidence'] = session_data.get('health_score', 0.8)
        session_data['recovery_source'] = 'spr'
        
        return session_data
    
    def _recover_from_checkpoint(self) -> Dict[str, Any]:
        """Recover from checkpoint files."""
        checkpoint_dir = Path("/Users/sac/claude-desktop-context")
        
        # Find most recent checkpoint
        checkpoints = list(checkpoint_dir.glob("CHECKPOINT_*.md"))
        if not checkpoints:
            raise FileNotFoundError("No checkpoint files found")
        
        latest_checkpoint = max(checkpoints, key=lambda p: p.stat().st_mtime)
        print(f"  ✅ Found checkpoint: {latest_checkpoint.name}")
        
        # Parse checkpoint
        content = latest_checkpoint.read_text()
        session_data = self._parse_checkpoint_content(content)
        
        session_data['confidence'] = 0.75
        session_data['recovery_source'] = 'checkpoint'
        session_data['checkpoint_file'] = str(latest_checkpoint)
        
        return session_data
    
    def _recover_from_git(self) -> Dict[str, Any]:
        """Recover from git history and current state."""
        if not self.config.use_git_history:
            raise RuntimeError("Git history recovery disabled")
        
        print("  🔍 Analyzing git repositories...")
        
        session_data = {
            'projects': [],
            'recent_commits': [],
            'current_branches': {},
            'uncommitted_changes': {}
        }
        
        # Scan workspace for git repos
        for workspace in self.config.workspace_paths:
            if not workspace.exists():
                continue
            
            git_repos = list(workspace.glob("**/.git"))[:10]  # Limit to 10
            
            for git_dir in git_repos:
                repo_path = git_dir.parent
                repo_info = self._analyze_git_repo(repo_path)
                if repo_info:
                    session_data['projects'].append(repo_info)
        
        # Calculate confidence based on findings
        if session_data['projects']:
            session_data['confidence'] = 0.6 + (0.1 * min(len(session_data['projects']), 4))
        else:
            session_data['confidence'] = 0.3
        
        session_data['recovery_source'] = 'git'
        session_data['work_context'] = self._build_git_context(session_data)
        
        return session_data
    
    def _recover_from_workspace(self) -> Dict[str, Any]:
        """Recover from workspace file analysis."""
        print("  📁 Scanning workspace for active projects...")
        
        session_data = {
            'projects': [],
            'recent_files': [],
            'active_directories': []
        }
        
        # Scan for recent files
        recent_threshold = datetime.now().timestamp() - (24 * 60 * 60)  # 24 hours
        
        for workspace in self.config.workspace_paths:
            if not workspace.exists():
                continue
            
            # Find recently modified files
            for ext in ['*.py', '*.md', '*.yaml', '*.json']:
                for file_path in workspace.glob(f"**/{ext}")[:50]:  # Limit
                    try:
                        if file_path.stat().st_mtime > recent_threshold:
                            session_data['recent_files'].append({
                                'path': str(file_path),
                                'modified': datetime.fromtimestamp(file_path.stat().st_mtime).isoformat(),
                                'project': file_path.parts[4] if len(file_path.parts) > 4 else 'unknown'
                            })
                    except:
                        continue
        
        # Identify active projects
        project_counts = {}
        for file_info in session_data['recent_files']:
            project = file_info['project']
            project_counts[project] = project_counts.get(project, 0) + 1
        
        # Create project list
        for project, count in sorted(project_counts.items(), key=lambda x: x[1], reverse=True):
            if project != 'unknown':
                session_data['projects'].append({
                    'name': project,
                    'activity_score': count,
                    'path': f"/Users/sac/dev/{project}"
                })
        
        session_data['confidence'] = 0.5 if session_data['projects'] else 0.2
        session_data['recovery_source'] = 'workspace'
        session_data['work_context'] = self._build_workspace_context(session_data)
        
        return session_data
    
    def _recover_from_scratch(self) -> Dict[str, Any]:
        """Create minimal session from scratch."""
        print("  🆕 Creating new session from scratch")
        
        return {
            'projects': [],
            'status': 'New session - no history found',
            'timestamp': datetime.now().isoformat(),
            'confidence': 0.1,
            'recovery_source': 'scratch',
            'work_context': {
                'message': 'Starting fresh - what would you like to work on?',
                'suggestions': [
                    'Review recent projects',
                    'Check git status',
                    'Start new feature'
                ]
            }
        }
    
    def _parse_checkpoint_content(self, content: str) -> Dict[str, Any]:
        """Parse checkpoint file content."""
        session_data = {
            'projects': [],
            'status': '',
            'context_anchors': []
        }
        
        lines = content.split('\n')
        
        for line in lines:
            # Extract projects
            if '**Projects**:' in line or '**Project**:' in line:
                projects_text = line.split(':', 1)[1].strip()
                # Simple project extraction
                if 'WeaverGen' in projects_text:
                    session_data['projects'].append({
                        'name': 'WeaverGen',
                        'status': 'Active'
                    })
            
            # Extract status
            elif '**Status**:' in line:
                session_data['status'] = line.split(':', 1)[1].strip()
            
            # Extract context anchors
            elif line.strip().startswith('- ') and ':' in line:
                parts = line.strip('- ').split(':', 1)
                if len(parts) == 2:
                    session_data['context_anchors'].append({
                        'time': parts[0].strip(),
                        'action': parts[1].strip()
                    })
        
        return session_data
    
    def _analyze_git_repo(self, repo_path: Path) -> Optional[Dict[str, Any]]:
        """Analyze a git repository."""
        try:
            os.chdir(repo_path)
            
            # Get current branch
            branch = subprocess.run(
                ['git', 'branch', '--show-current'],
                capture_output=True, text=True
            ).stdout.strip()
            
            # Get last commit
            last_commit = subprocess.run(
                ['git', 'log', '-1', '--oneline'],
                capture_output=True, text=True
            ).stdout.strip()
            
            # Check for uncommitted changes
            status = subprocess.run(
                ['git', 'status', '--porcelain'],
                capture_output=True, text=True
            ).stdout.strip()
            
            return {
                'name': repo_path.name,
                'path': str(repo_path),
                'branch': branch,
                'last_commit': last_commit,
                'has_changes': bool(status),
                'change_count': len(status.split('\n')) if status else 0
            }
            
        except Exception:
            return None
        finally:
            os.chdir(Path.home())
    
    def _build_git_context(self, session_data: Dict[str, Any]) -> Dict[str, Any]:
        """Build context from git data."""
        context = {
            'active_projects': [],
            'needs_attention': []
        }
        
        for project in session_data.get('projects', []):
            context['active_projects'].append(
                f"{project['name']} ({project['branch']})"
            )
            
            if project.get('has_changes'):
                context['needs_attention'].append(
                    f"{project['name']}: {project['change_count']} uncommitted changes"
                )
        
        return context
    
    def _build_workspace_context(self, session_data: Dict[str, Any]) -> Dict[str, Any]:
        """Build context from workspace data."""
        context = {
            'active_projects': [],
            'recent_activity': []
        }
        
        for project in session_data.get('projects', [])[:5]:
            context['active_projects'].append(
                f"{project['name']} (activity: {project['activity_score']})"
            )
        
        # Recent files summary
        recent = session_data.get('recent_files', [])[:5]
        for file_info in recent:
            context['recent_activity'].append(
                f"{Path(file_info['path']).name} - {file_info['modified']}"
            )
        
        return context
    
    def _enhance_result(self, session_data: Dict[str, Any]) -> Dict[str, Any]:
        """Enhance recovered session with additional intelligence."""
        # Add timestamp
        session_data['recovered_at'] = datetime.now().isoformat()
        
        # Add recovery quality assessment
        confidence = session_data.get('confidence', 0.5)
        if confidence > 0.8:
            session_data['quality'] = 'high'
        elif confidence > 0.5:
            session_data['quality'] = 'medium'
        else:
            session_data['quality'] = 'low'
        
        # Add recommendations based on recovery
        session_data['recommendations'] = self._generate_recommendations(session_data)
        
        # Cache if configured
        if self.config.cache_results:
            self._cache_session(session_data)
        
        return session_data
    
    def _generate_recommendations(self, session_data: Dict[str, Any]) -> List[str]:
        """Generate recommendations based on recovered data."""
        recommendations = []
        
        source = session_data.get('recovery_source', '')
        quality = session_data.get('quality', 'low')
        
        if quality == 'low':
            recommendations.append("Consider saving checkpoints more frequently")
        
        if source == 'git':
            recommendations.append("Review uncommitted changes before continuing")
        
        if source == 'workspace':
            recommendations.append("Verify active project context is correct")
        
        if not session_data.get('projects'):
            recommendations.append("No active projects detected - select a project to work on")
        
        return recommendations
    
    def _cache_session(self, session_data: Dict[str, Any]) -> None:
        """Cache recovered session data."""
        cache_path = Path("/Users/sac/claude-desktop-context/.recovery_cache.json")
        
        try:
            with open(cache_path, 'w') as f:
                json.dump(session_data, f, indent=2, default=str)
        except Exception as e:
            print(f"Failed to cache session: {e}")
    
    def _create_minimal_session(self) -> Dict[str, Any]:
        """Create absolute minimal session."""
        return {
            'error': 'All recovery strategies failed',
            'timestamp': datetime.now().isoformat(),
            'confidence': 0.0,
            'recovery_source': 'minimal',
            'work_context': {
                'message': 'Unable to recover previous session',
                'action': 'Please specify what you were working on'
            },
            'recommendations': [
                'Manually specify your current project',
                'Check if session files exist',
                'Verify workspace permissions'
            ]
        }
    
    def validate_recovery(self, session_data: Dict[str, Any]) -> bool:
        """Validate recovered session data."""
        required_fields = ['confidence', 'recovery_source']
        
        for field in required_fields:
            if field not in session_data:
                return False
        
        # Check confidence threshold
        if session_data['confidence'] < 0.1:
            return False
        
        return True


# CLI Integration
def recover_cdcs_session(mode: Optional[str] = None) -> Dict[str, Any]:
    """Recover CDCS session with dual-mode system."""
    recovery = DualModeSessionRecovery()
    
    result = recovery.recover_session(force_mode=mode)
    
    print(f"\n📊 Recovery Results:")
    print(f"- Method: {result.get('recovery_source', 'unknown')}")
    print(f"- Confidence: {result.get('confidence', 0):.0%}")
    print(f"- Quality: {result.get('quality', 'unknown')}")
    
    if result.get('projects'):
        print(f"- Projects Found: {len(result['projects'])}")
    
    if result.get('recommendations'):
        print("\n💡 Recommendations:")
        for rec in result['recommendations']:
            print(f"  - {rec}")
    
    return result


if __name__ == "__main__":
    import sys
    
    mode = sys.argv[1] if len(sys.argv) > 1 else None
    
    print("🚀 CDCS Dual-Mode Session Recovery\n")
    
    session = recover_cdcs_session(mode)
    
    # Save recovery report
    report_path = Path("/Users/sac/claude-desktop-context/recovery_report.json")
    with open(report_path, 'w') as f:
        json.dump(session, f, indent=2, default=str)
    
    print(f"\n📁 Recovery report saved to: {report_path}")