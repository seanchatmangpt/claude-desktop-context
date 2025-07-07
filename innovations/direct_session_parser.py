"""
Direct Session Parser - Parse CDCS session files with intelligence

This module provides direct parsing of session recovery files,
applying the same innovation pattern from WeaverGen.
"""

import re
from pathlib import Path
from typing import Dict, List, Any, Optional, Tuple
from dataclasses import dataclass
from datetime import datetime
import json


@dataclass
class SessionContext:
    """Represents a session context point."""
    timestamp: str
    action: str
    details: Optional[str] = None
    confidence: float = 1.0
    
    def to_spr(self) -> str:
        """Convert to SPR format."""
        return f"- {self.timestamp}: {self.action}"


@dataclass 
class ProjectInfo:
    """Project information from session."""
    name: str
    path: str
    status: str
    completion: Optional[float] = None
    last_action: Optional[str] = None
    
    @property
    def summary(self) -> str:
        """Get project summary."""
        comp = f" ({self.completion}%)" if self.completion else ""
        return f"{self.name}{comp} - {self.status}"


class DirectSessionParser:
    """Parse CDCS session files directly."""
    
    def __init__(self):
        self.patterns = {
            'project': re.compile(r'\*\*Projects?\*\*:\s*(.+)'),
            'status': re.compile(r'\*\*Status\*\*:\s*(.+)'),
            'date': re.compile(r'\*\*Date\*\*:\s*(.+)'),
            'last_action': re.compile(r'\*\*Last Action\*\*:\s*(.+)'),
            'completion': re.compile(r'(\d+)%'),
            'context_anchor': re.compile(r'^-\s*(\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}[^:]*?):\s*(.+)$', re.MULTILINE),
            'recovery_command': re.compile(r'\*\*Recovery Command\*\*:\s*(.+)'),
            'file_created': re.compile(r'^-\s*(.+\.(?:md|py|yaml|json))(?:\s*\(.+\))?$', re.MULTILINE)
        }
    
    def parse_spr_file(self, file_path: Path) -> Dict[str, Any]:
        """Parse SPR session recovery file."""
        if not file_path.exists():
            return {'error': 'File not found', 'path': str(file_path)}
        
        content = file_path.read_text()
        
        # Parse main sections
        session_data = {
            'file_path': str(file_path),
            'parsed_at': datetime.now().isoformat(),
            'raw_size': len(content),
            'projects': self._parse_projects(content),
            'status': self._extract_field(content, 'status'),
            'date': self._extract_field(content, 'date'),
            'last_action': self._extract_field(content, 'last_action'),
            'context_anchors': self._parse_context_anchors(content),
            'files_created': self._parse_files_created(content),
            'recovery_command': self._extract_field(content, 'recovery_command')
        }
        
        # Extract work context
        session_data['work_context'] = self._build_work_context(session_data)
        
        # Calculate session health
        session_data['health_score'] = self._calculate_health_score(session_data)
        
        return session_data
    
    def _extract_field(self, content: str, field_name: str) -> Optional[str]:
        """Extract a field using pattern matching."""
        pattern = self.patterns.get(field_name)
        if pattern:
            match = pattern.search(content)
            if match:
                return match.group(1).strip()
        return None
    
    def _parse_projects(self, content: str) -> List[ProjectInfo]:
        """Parse project information from content."""
        projects = []
        
        # Find projects line
        project_match = self.patterns['project'].search(content)
        if not project_match:
            return projects
        
        project_text = project_match.group(1)
        
        # Parse individual projects
        # Format: "WeaverGen (70% achieved!), Agent-Guides (integrated), CLIAPI (dormant)"
        project_parts = re.split(r',\s*', project_text)
        
        for part in project_parts:
            # Extract name and status
            match = re.match(r'(\w+(?:-\w+)?)\s*\(([^)]+)\)', part)
            if match:
                name = match.group(1)
                status_info = match.group(2)
                
                # Extract completion percentage if present
                comp_match = self.patterns['completion'].search(status_info)
                completion = float(comp_match.group(1)) if comp_match else None
                
                # Clean status
                status = re.sub(r'\d+%\s*', '', status_info).strip()
                
                projects.append(ProjectInfo(
                    name=name,
                    path=f"/Users/sac/dev/{name.lower()}",  # Infer path
                    status=status,
                    completion=completion
                ))
        
        return projects
    
    def _parse_context_anchors(self, content: str) -> List[SessionContext]:
        """Parse context anchor points."""
        anchors = []
        
        matches = self.patterns['context_anchor'].findall(content)
        for timestamp, action in matches:
            anchors.append(SessionContext(
                timestamp=timestamp.strip(),
                action=action.strip()
            ))
        
        return anchors
    
    def _parse_files_created(self, content: str) -> List[str]:
        """Parse files created during session."""
        files = []
        
        # Look for file lists in the content
        lines = content.split('\n')
        in_files_section = False
        
        for line in lines:
            if 'Files Created' in line or 'Files Updated' in line:
                in_files_section = True
                continue
            elif line.strip() == '' and in_files_section:
                in_files_section = False
            elif in_files_section:
                match = self.patterns['file_created'].match(line)
                if match:
                    files.append(match.group(1))
        
        return files
    
    def _build_work_context(self, session_data: Dict[str, Any]) -> Dict[str, Any]:
        """Build comprehensive work context from parsed data."""
        context = {
            'active_projects': [],
            'recent_activities': [],
            'current_focus': None,
            'next_actions': []
        }
        
        # Active projects
        for project in session_data.get('projects', []):
            if 'dormant' not in project.status.lower():
                context['active_projects'].append(project.summary)
        
        # Recent activities from context anchors
        anchors = session_data.get('context_anchors', [])
        if anchors:
            context['recent_activities'] = [
                f"{a.timestamp}: {a.action}" for a in anchors[-5:]
            ]
        
        # Current focus from last action
        if session_data.get('last_action'):
            context['current_focus'] = session_data['last_action']
        
        # Next actions from recovery command
        if session_data.get('recovery_command'):
            context['next_actions'].append(session_data['recovery_command'])
        
        return context
    
    def _calculate_health_score(self, session_data: Dict[str, Any]) -> float:
        """Calculate session health score (0-1)."""
        score = 1.0
        
        # Deduct for missing critical fields
        critical_fields = ['projects', 'status', 'last_action']
        for field in critical_fields:
            if not session_data.get(field):
                score -= 0.2
        
        # Deduct for old sessions
        if session_data.get('date'):
            try:
                # Simple date parsing (would be more robust in production)
                if 'ago' in session_data['date'].lower():
                    score -= 0.1
            except:
                pass
        
        # Bonus for context richness
        if len(session_data.get('context_anchors', [])) > 3:
            score += 0.1
        
        if len(session_data.get('files_created', [])) > 5:
            score += 0.1
        
        return max(0.0, min(1.0, score))
    
    def generate_enhanced_spr(self, session_data: Dict[str, Any]) -> str:
        """Generate enhanced SPR with improvements."""
        lines = [
            "# Comprehensive System State - Session Recovery SPR",
            ""
        ]
        
        # Projects section with enhanced formatting
        if session_data.get('projects'):
            project_strs = []
            for p in session_data['projects']:
                project_strs.append(p.summary)
            lines.append(f"**Projects**: {', '.join(project_strs)}")
        
        # Core fields
        for field in ['status', 'date', 'last_action']:
            if session_data.get(field):
                lines.append(f"**{field.replace('_', ' ').title()}**: {session_data[field]}")
        
        # Health score
        lines.extend([
            f"**Session Health**: {session_data.get('health_score', 0):.0%}",
            ""
        ])
        
        # Work context section
        if session_data.get('work_context'):
            lines.append("## Current Work Context")
            ctx = session_data['work_context']
            
            if ctx.get('active_projects'):
                lines.append(f"**Active Projects**: {len(ctx['active_projects'])}")
                for proj in ctx['active_projects']:
                    lines.append(f"- {proj}")
            
            if ctx.get('current_focus'):
                lines.append(f"\n**Current Focus**: {ctx['current_focus']}")
            
            lines.append("")
        
        # Context anchors
        if session_data.get('context_anchors'):
            lines.append("## Context Anchors")
            for anchor in session_data['context_anchors'][-10:]:  # Last 10
                lines.append(f"- {anchor.timestamp}: {anchor.action}")
            lines.append("")
        
        # Files created
        if session_data.get('files_created'):
            lines.append("## Files Created/Updated")
            for file in session_data['files_created'][:15]:  # Top 15
                lines.append(f"- {file}")
            lines.append("")
        
        # Recovery command
        if session_data.get('recovery_command'):
            lines.append(f"**Recovery Command**: {session_data['recovery_command']}")
        
        return '\n'.join(lines)
    
    def merge_sessions(self, primary: Dict[str, Any], 
                      secondary: Dict[str, Any]) -> Dict[str, Any]:
        """Merge two session data structures intelligently."""
        merged = primary.copy()
        
        # Merge projects
        if 'projects' in secondary:
            existing_names = {p.name for p in merged.get('projects', [])}
            for proj in secondary['projects']:
                if proj.name not in existing_names:
                    merged.setdefault('projects', []).append(proj)
        
        # Merge context anchors (remove duplicates)
        if 'context_anchors' in secondary:
            existing_anchors = {(a.timestamp, a.action) 
                              for a in merged.get('context_anchors', [])}
            for anchor in secondary['context_anchors']:
                if (anchor.timestamp, anchor.action) not in existing_anchors:
                    merged.setdefault('context_anchors', []).append(anchor)
        
        # Take newer status/date/action
        for field in ['status', 'date', 'last_action']:
            if field in secondary and secondary[field]:
                merged[field] = secondary[field]
        
        # Merge files created
        if 'files_created' in secondary:
            merged_files = set(merged.get('files_created', []))
            merged_files.update(secondary['files_created'])
            merged['files_created'] = list(merged_files)
        
        # Recalculate work context and health
        merged['work_context'] = self._build_work_context(merged)
        merged['health_score'] = self._calculate_health_score(merged)
        
        return merged


# Utility functions for CDCS integration
def parse_current_session() -> Dict[str, Any]:
    """Parse the current CDCS session."""
    parser = DirectSessionParser()
    session_path = Path("/Users/sac/claude-desktop-context/session_recovery.spr")
    
    return parser.parse_spr_file(session_path)


def enhance_current_session() -> str:
    """Enhance and return the current session SPR."""
    parser = DirectSessionParser()
    session_data = parse_current_session()
    
    return parser.generate_enhanced_spr(session_data)


if __name__ == "__main__":
    # Test the parser
    parser = DirectSessionParser()
    session_path = Path("/Users/sac/claude-desktop-context/session_recovery.spr")
    
    if session_path.exists():
        print("🔍 Parsing current session...")
        session_data = parser.parse_spr_file(session_path)
        
        print(f"\n📊 Session Health: {session_data['health_score']:.0%}")
        print(f"📁 Projects: {len(session_data.get('projects', []))}")
        print(f"⚓ Context Anchors: {len(session_data.get('context_anchors', []))}")
        print(f"📄 Files Created: {len(session_data.get('files_created', []))}")
        
        if session_data.get('work_context'):
            ctx = session_data['work_context']
            print(f"\n🎯 Current Focus: {ctx.get('current_focus', 'Unknown')}")
            print(f"🚀 Active Projects: {len(ctx.get('active_projects', []))}")
        
        # Generate enhanced SPR
        enhanced = parser.generate_enhanced_spr(session_data)
        print("\n📝 Enhanced SPR Preview:")
        print(enhanced[:500] + "..." if len(enhanced) > 500 else enhanced)