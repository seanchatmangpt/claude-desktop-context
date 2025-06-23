#!/usr/bin/env python3
"""
Memory Optimizer Agent - Compresses and optimizes CDCS memory using SPR
Uses ollama/qwen3 for intelligent semantic compression
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Tuple
import datetime
import shutil

class MemoryOptimizer:
    def __init__(self, orchestrator):
        self.orchestrator = orchestrator
        self.task_description = "Optimizing memory through intelligent compression"
        self.compressed_path = Path("/Users/sac/claude-desktop-context/memory/sessions/compressed")
        self.compressed_path.mkdir(parents=True, exist_ok=True)
        
    def analyze_session_for_compression(self, session_path: Path) -> Dict:
        """Analyze if session needs compression"""
        content = session_path.read_text()
        lines = len(content.splitlines())
        size_bytes = len(content.encode())
        entropy = self.orchestrator.calculate_shannon_entropy(content)
        
        # Compression criteria
        needs_compression = (
            lines > 10000 or  # Line threshold
            size_bytes > 100000 or  # Size threshold
            entropy > 6.0  # High entropy threshold
        )
        
        return {
            'path': session_path,
            'lines': lines,
            'size_bytes': size_bytes,
            'entropy': entropy,
            'needs_compression': needs_compression,
            'priority': entropy * (lines / 1000)  # Higher entropy + size = higher priority
        }
        
    def spr_compress(self, content: str, ratio: int = 15) -> Dict:
        """Semantic Pyramid Reduction compression using ollama"""
        
        system_prompt = f"""You are a Sparse Priming Representation (SPR) compressor.
        Compress the following content to 1/{ratio}th of its original size while preserving:
        1. Core concepts and relationships
        2. Key decisions and outcomes
        3. Discovered patterns and insights
        4. Critical implementation details
        5. Evolution opportunities
        
        Output format:
        {{
            "summary": "2-3 sentence overview",
            "key_points": ["point1", "point2", ...],
            "patterns": ["pattern1", "pattern2", ...],
            "decisions": ["decision1", "decision2", ...],
            "code_artifacts": ["essential code snippets"],
            "reconstruction_triggers": ["keywords that help reconstruct full context"],
            "metadata": {{
                "original_lines": number,
                "compressed_lines": number,
                "information_preserved": percentage
            }}
        }}
        """
        
        # Split content into chunks for ollama processing
        chunks = self.split_content_intelligently(content, 2000)
        compressed_chunks = []
        
        for i, chunk in enumerate(chunks):
            prompt = f"SPR compress chunk {i+1}/{len(chunks)}:\n\n{chunk}"
            response = self.orchestrator.ollama_query(prompt, system_prompt)
            
            try:
                compressed_chunks.append(json.loads(response))
            except:
                # Fallback to basic compression
                compressed_chunks.append({
                    "summary": chunk[:200] + "...",
                    "key_points": self.extract_key_points(chunk),
                    "patterns": [],
                    "decisions": [],
                    "code_artifacts": self.extract_code_snippets(chunk)[:3],
                    "reconstruction_triggers": self.extract_keywords(chunk)[:10]
                })
                
        # Merge compressed chunks
        return self.merge_compressed_chunks(compressed_chunks)
        
    def split_content_intelligently(self, content: str, chunk_size: int) -> List[str]:
        """Split content on semantic boundaries"""
        lines = content.splitlines()
        chunks = []
        current_chunk = []
        current_size = 0
        
        for line in lines:
            # Look for semantic boundaries
            is_boundary = (
                line.startswith('#') or  # Headers
                line.startswith('---') or  # Separators
                line.strip() == '' and current_size > chunk_size * 0.8  # Paragraphs
            )
            
            if is_boundary and current_size > chunk_size * 0.5:
                chunks.append('\n'.join(current_chunk))
                current_chunk = [line]
                current_size = len(line)
            else:
                current_chunk.append(line)
                current_size += len(line)
                
        if current_chunk:
            chunks.append('\n'.join(current_chunk))
            
        return chunks
        
    def extract_key_points(self, text: str) -> List[str]:
        """Extract key points using pattern matching"""
        key_points = []
        
        # Look for bullet points, numbered lists
        patterns = [
            r'^\s*[-*]\s+(.+)$',  # Bullet points
            r'^\s*\d+\.\s+(.+)$',  # Numbered lists
            r'^(?:Key|Important|Note|Critical):\s*(.+)$',  # Key indicators
        ]
        
        for line in text.splitlines():
            for pattern in patterns:
                import re
                match = re.match(pattern, line, re.IGNORECASE)
                if match:
                    key_points.append(match.group(1).strip())
                    break
                    
        return key_points[:10]  # Limit to top 10
        
    def extract_code_snippets(self, text: str) -> List[str]:
        """Extract important code snippets"""
        import re
        code_blocks = re.findall(r'```[\w]*\n(.*?)\n```', text, re.DOTALL)
        
        # Prioritize by length and complexity
        snippets = []
        for block in code_blocks:
            if 10 < len(block.splitlines()) < 50:  # Reasonable size
                snippets.append(block)
                
        return snippets
        
    def extract_keywords(self, text: str) -> List[str]:
        """Extract keywords for reconstruction"""
        # Simple keyword extraction
        words = re.findall(r'\b[A-Z][a-z]+(?:[A-Z][a-z]+)*\b', text)  # CamelCase
        technical_terms = re.findall(r'\b(?:function|class|import|pattern|system|agent|evolution)\b', text.lower())
        
        all_keywords = list(set(words + technical_terms))
        return all_keywords[:20]
        
    def merge_compressed_chunks(self, chunks: List[Dict]) -> Dict:
        """Merge multiple compressed chunks into unified structure"""
        merged = {
            "summary": "",
            "key_points": [],
            "patterns": [],
            "decisions": [],
            "code_artifacts": [],
            "reconstruction_triggers": [],
            "metadata": {
                "original_lines": 0,
                "compressed_lines": 0,
                "information_preserved": 0.94  # Target
            }
        }
        
        # Aggregate summaries
        summaries = [c.get('summary', '') for c in chunks if c.get('summary')]
        if summaries:
            merged['summary'] = ' '.join(summaries[:3])  # Top 3 summaries
            
        # Merge lists with deduplication
        for key in ['key_points', 'patterns', 'decisions', 'reconstruction_triggers']:
            all_items = []
            for chunk in chunks:
                all_items.extend(chunk.get(key, []))
            merged[key] = list(dict.fromkeys(all_items))[:20]  # Dedupe and limit
            
        # Select best code artifacts
        all_code = []
        for chunk in chunks:
            all_code.extend(chunk.get('code_artifacts', []))
        merged['code_artifacts'] = all_code[:5]  # Top 5 code snippets
        
        # Calculate metadata
        total_original = sum(c.get('metadata', {}).get('original_lines', 0) for c in chunks)
        merged['metadata']['original_lines'] = total_original
        merged['metadata']['compressed_lines'] = len(str(merged).splitlines())
        
        return merged
        
    def save_compressed_session(self, session_path: Path, compressed_data: Dict) -> Path:
        """Save compressed session and archive original"""
        # Create compressed filename
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        compressed_name = f"{session_path.stem}_compressed_{timestamp}.spr"
        compressed_file = self.compressed_path / compressed_name
        
        # Add metadata
        compressed_data['_metadata'] = {
            'original_file': session_path.name,
            'original_path': str(session_path),
            'compression_date': datetime.datetime.now().isoformat(),
            'compression_ratio': compressed_data['metadata']['original_lines'] / max(compressed_data['metadata']['compressed_lines'], 1)
        }
        
        # Save compressed version
        compressed_file.write_text(json.dumps(compressed_data, indent=2))
        
        # Archive original
        archive_path = self.compressed_path / "originals"
        archive_path.mkdir(exist_ok=True)
        shutil.move(str(session_path), str(archive_path / session_path.name))
        
        # Create pointer file
        pointer_content = f"COMPRESSED TO: {compressed_file.name}\n"
        pointer_content += f"Compression ratio: {compressed_data['_metadata']['compression_ratio']:.1f}:1\n"
        pointer_content += f"Date: {compressed_data['_metadata']['compression_date']}\n"
        session_path.write_text(pointer_content)
        
        return compressed_file
        
    def optimize_pattern_cache(self) -> Dict:
        """Optimize the pattern cache for quick access"""
        pattern_stats = {}
        
        # Analyze pattern usage
        import sqlite3
        conn = sqlite3.connect(self.orchestrator.db_path)
        patterns = conn.execute("""
            SELECT pattern_hash, pattern_content, usage_count, confidence
            FROM discovered_patterns
            ORDER BY usage_count * confidence DESC
            LIMIT 100
        """).fetchall()
        conn.close()
        
        # Create optimized cache
        cache_path = Path("/Users/sac/claude-desktop-context/patterns/cache")
        cache_path.mkdir(parents=True, exist_ok=True)
        
        pattern_cache = {
            "patterns": [],
            "index": {},
            "updated": datetime.datetime.now().isoformat()
        }
        
        for hash_val, content, usage, confidence in patterns:
            pattern_data = json.loads(content)
            pattern_cache["patterns"].append({
                "hash": hash_val,
                "data": pattern_data,
                "score": usage * confidence
            })
            
            # Create index for fast lookup
            if pattern_data.get('category'):
                if pattern_data['category'] not in pattern_cache["index"]:
                    pattern_cache["index"][pattern_data['category']] = []
                pattern_cache["index"][pattern_data['category']].append(hash_val)
                
        # Save cache
        cache_file = cache_path / "pattern_cache.json"
        cache_file.write_text(json.dumps(pattern_cache, indent=2))
        
        pattern_stats['cached_patterns'] = len(pattern_cache["patterns"])
        pattern_stats['categories'] = list(pattern_cache["index"].keys())
        
        return pattern_stats
        
    def run(self) -> Dict:
        """Execute memory optimization"""
        metrics = {
            'tokens_processed': 0,
            'sessions_compressed': 0,
            'compression_achieved': 0.0,
            'space_saved_mb': 0.0,
            'metadata': {}
        }
        
        # Find sessions needing compression
        sessions_path = Path("/Users/sac/claude-desktop-context/memory/sessions")
        candidates = []
        
        for session_file in sessions_path.glob("*.md"):
            analysis = self.analyze_session_for_compression(session_file)
            if analysis['needs_compression']:
                candidates.append(analysis)
                
        # Sort by priority
        candidates.sort(key=lambda x: x['priority'], reverse=True)
        
        # Compress top candidates
        total_original_size = 0
        total_compressed_size = 0
        
        for candidate in candidates[:3]:  # Limit to 3 per run
            session_path = candidate['path']
            content = session_path.read_text()
            
            # Calculate compression ratio based on entropy
            if candidate['entropy'] > 6.0:
                ratio = 20
            elif candidate['entropy'] > 4.5:
                ratio = 15
            else:
                ratio = 10
                
            compressed = self.spr_compress(content, ratio)
            compressed_file = self.save_compressed_session(session_path, compressed)
            
            original_size = candidate['size_bytes']
            compressed_size = len(compressed_file.read_text().encode())
            
            total_original_size += original_size
            total_compressed_size += compressed_size
            
            metrics['sessions_compressed'] += 1
            metrics['tokens_processed'] += original_size // 4
            
        # Calculate compression metrics
        if total_original_size > 0:
            metrics['compression_achieved'] = total_original_size / total_compressed_size
            metrics['space_saved_mb'] = (total_original_size - total_compressed_size) / (1024 * 1024)
            
        # Optimize pattern cache
        pattern_stats = self.optimize_pattern_cache()
        
        metrics['metadata'] = {
            'candidates_found': len(candidates),
            'avg_entropy': sum(c['entropy'] for c in candidates) / len(candidates) if candidates else 0,
            'pattern_cache': pattern_stats
        }
        
        return metrics
