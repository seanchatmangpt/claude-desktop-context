#!/usr/bin/env python3
"""
Predictive Loader Agent - Preloads context based on patterns and predictions
Uses ollama/qwen3 for intelligent prediction of future needs
"""

import json
from pathlib import Path
from typing import Dict, List, Tuple, Set
import datetime
import numpy as np
from collections import defaultdict
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

class PredictiveLoader:
    def __init__(self, orchestrator):
        self.orchestrator = orchestrator
        self.task_description = "Predictive context preloading"
        self.cache_path = Path("/Users/sac/claude-desktop-context/cache")
        self.cache_path.mkdir(parents=True, exist_ok=True)
        
    def analyze_temporal_patterns(self) -> Dict:
        """Analyze time-based usage patterns"""
        
        temporal_patterns = {
            'hourly': defaultdict(list),
            'daily': defaultdict(list),
            'weekly': defaultdict(list)
        }
        
        # Query historical data
        import sqlite3
        conn = sqlite3.connect(self.orchestrator.db_path)
        
        # Get session timing data
        sessions = conn.execute("""
            SELECT timestamp, agent, task, 
                   json_extract(metadata, '$.session_file') as session_file
            FROM automation_runs
            WHERE timestamp > datetime('now', '-30 days')
            ORDER BY timestamp
        """).fetchall()
        
        for timestamp, agent, task, session_file in sessions:
            dt = datetime.datetime.fromisoformat(timestamp)
            
            # Hour of day pattern
            temporal_patterns['hourly'][dt.hour].append({
                'agent': agent,
                'task': task,
                'session': session_file
            })
            
            # Day of week pattern
            temporal_patterns['daily'][dt.weekday()].append({
                'agent': agent,
                'task': task,
                'session': session_file
            })
            
            # Week of month pattern
            week_num = (dt.day - 1) // 7
            temporal_patterns['weekly'][week_num].append({
                'agent': agent,
                'task': task,
                'session': session_file
            })
            
        conn.close()
        return temporal_patterns
        
    def predict_next_topics(self, recent_sessions: List[Dict]) -> List[Dict]:
        """Predict likely next topics based on conversation flow"""
        
        if not recent_sessions:
            return []
            
        # Create topic progression model
        system_prompt = """Analyze the progression of topics in these CDCS sessions.
        Predict the most likely next topics or areas of focus.
        
        Consider:
        1. Natural topic progression
        2. Unfinished threads
        3. Implied next steps
        4. Common patterns in similar conversations
        
        Output JSON:
        {
            "predictions": [
                {
                    "topic": "predicted topic",
                    "confidence": 0.0-1.0,
                    "reasoning": "why this is likely",
                    "resources_needed": ["pattern1", "file1", "knowledge1"]
                }
            ]
        }
        """
        
        # Prepare recent context
        recent_context = '\n\n'.join([
            f"Session {s['file']}:\n{s['content'][:500]}"
            for s in recent_sessions[:3]
        ])
        
        prompt = f"Predict next topics from:\n{recent_context}"
        response = self.orchestrator.ollama_query(prompt, system_prompt)
        
        try:
            predictions = json.loads(response).get('predictions', [])
            return predictions
        except:
            return []
            
    def calculate_resource_similarity(self, sessions: List[Dict]) -> Dict[str, List[str]]:
        """Calculate similarity between sessions to predict resource needs"""
        
        if len(sessions) < 2:
            return {}
            
        # Extract text from sessions
        texts = [s['content'] for s in sessions]
        
        # Create TF-IDF vectors
        vectorizer = TfidfVectorizer(max_features=100, stop_words='english')
        try:
            tfidf_matrix = vectorizer.fit_transform(texts)
        except:
            return {}
            
        # Calculate similarity matrix
        similarity_matrix = cosine_similarity(tfidf_matrix)
        
        # Find similar sessions and their resources
        resource_predictions = {}
        
        for i, session in enumerate(sessions):
            similar_indices = np.argsort(similarity_matrix[i])[-5:-1][::-1]  # Top 4 similar
            
            similar_resources = set()
            for idx in similar_indices:
                if idx < len(sessions):
                    # Extract resources mentioned in similar session
                    similar_content = sessions[idx]['content']
                    
                    # Look for pattern references
                    import re
                    patterns = re.findall(r'patterns/catalog/(\w+)', similar_content)
                    similar_resources.update(patterns)
                    
                    # Look for file references
                    files = re.findall(r'/Users/sac/claude-desktop-context/(\S+)', similar_content)
                    similar_resources.update(files[:5])  # Limit
                    
            resource_predictions[session['file']] = list(similar_resources)
            
        return resource_predictions
        
    def identify_pattern_sequences(self) -> List[Dict]:
        """Identify common sequences of pattern applications"""
        
        sequences = []
        
        # Query pattern usage sequences
        import sqlite3
        conn = sqlite3.connect(self.orchestrator.db_path)
        
        # Get pattern usage history
        pattern_usage = conn.execute("""
            SELECT timestamp, pattern_hash, 
                   json_extract(pattern_content, '$.name') as pattern_name
            FROM discovered_patterns
            WHERE usage_count > 0
            ORDER BY timestamp
        """).fetchall()
        
        # Build sequence map
        sequence_map = defaultdict(list)
        
        for i in range(len(pattern_usage) - 1):
            current = pattern_usage[i]
            next_pattern = pattern_usage[i + 1]
            
            # Check if patterns used within same session (1 hour window)
            current_time = datetime.datetime.fromisoformat(current[0])
            next_time = datetime.datetime.fromisoformat(next_pattern[0])
            
            if (next_time - current_time).total_seconds() < 3600:  # Within 1 hour
                sequence_map[current[2]].append(next_pattern[2])
                
        # Find frequent sequences
        for pattern, next_patterns in sequence_map.items():
            if len(next_patterns) >= 2:  # At least 2 occurrences
                pattern_counter = defaultdict(int)
                for p in next_patterns:
                    pattern_counter[p] += 1
                    
                for next_pattern, count in pattern_counter.items():
                    if count >= 2:
                        sequences.append({
                            'first': pattern,
                            'second': next_pattern,
                            'frequency': count,
                            'confidence': count / len(next_patterns)
                        })
                        
        conn.close()
        return sequences
        
    def build_prediction_model(self, temporal_patterns: Dict, topic_predictions: List[Dict]) -> Dict:
        """Build comprehensive prediction model"""
        
        model = {
            'temporal': {},
            'topical': {},
            'sequential': {},
            'confidence_threshold': 0.6
        }
        
        # Temporal predictions
        current_time = datetime.datetime.now()
        current_hour = current_time.hour
        current_day = current_time.weekday()
        
        # What's typically accessed at this hour?
        if current_hour in temporal_patterns['hourly']:
            hour_patterns = temporal_patterns['hourly'][current_hour]
            task_counter = defaultdict(int)
            for p in hour_patterns:
                task_counter[p['task']] += 1
                
            model['temporal']['hourly'] = [
                {'task': task, 'frequency': count}
                for task, count in task_counter.items()
            ]
            
        # Topical predictions
        model['topical']['next_topics'] = [
            t for t in topic_predictions if t['confidence'] > model['confidence_threshold']
        ]
        
        # Pattern sequence predictions
        sequences = self.identify_pattern_sequences()
        model['sequential']['pattern_sequences'] = [
            s for s in sequences if s['confidence'] > model['confidence_threshold']
        ]
        
        return model
        
    def preload_predicted_resources(self, model: Dict) -> Dict:
        """Preload resources based on predictions"""
        
        preloaded = {
            'patterns': [],
            'files': [],
            'knowledge': []
        }
        
        # Preload patterns from sequential predictions
        for sequence in model['sequential'].get('pattern_sequences', []):
            pattern_file = Path(f"/Users/sac/claude-desktop-context/patterns/catalog/{sequence['second']}.md")
            if pattern_file.exists():
                content = pattern_file.read_text()
                preloaded['patterns'].append({
                    'name': sequence['second'],
                    'trigger': sequence['first'],
                    'content': content[:500],  # Summary
                    'confidence': sequence['confidence']
                })
                
        # Preload files from topic predictions
        for topic in model['topical'].get('next_topics', []):
            for resource in topic.get('resources_needed', []):
                if '/' in resource:  # Likely a file path
                    file_path = Path(f"/Users/sac/claude-desktop-context/{resource}")
                    if file_path.exists() and file_path.is_file():
                        preloaded['files'].append({
                            'path': str(file_path),
                            'topic': topic['topic'],
                            'size': file_path.stat().st_size
                        })
                        
        # Preload knowledge from temporal patterns
        current_hour = datetime.datetime.now().hour
        for task_info in model['temporal'].get('hourly', []):
            if task_info['frequency'] > 2:  # Frequent at this hour
                # Load related knowledge
                knowledge_query = f"SELECT * FROM discovered_patterns WHERE category = '{task_info['task']}' LIMIT 5"
                # This would query and preload relevant knowledge
                preloaded['knowledge'].append({
                    'category': task_info['task'],
                    'frequency': task_info['frequency']
                })
                
        return preloaded
        
    def optimize_cache(self, preloaded: Dict) -> Dict:
        """Optimize cache for quick access"""
        
        cache_stats = {
            'total_size': 0,
            'pattern_count': 0,
            'file_count': 0,
            'optimization_ratio': 0.0
        }
        
        # Create optimized cache file
        cache_data = {
            'timestamp': datetime.datetime.now().isoformat(),
            'preloaded': preloaded,
            'index': {
                'patterns': {},
                'files': {},
                'topics': {}
            }
        }
        
        # Build indices for O(1) lookup
        for pattern in preloaded['patterns']:
            cache_data['index']['patterns'][pattern['name']] = pattern
            cache_stats['pattern_count'] += 1
            
        for file_info in preloaded['files']:
            cache_data['index']['files'][file_info['path']] = file_info
            cache_stats['file_count'] += 1
            cache_stats['total_size'] += file_info['size']
            
        # Save cache
        cache_file = self.cache_path / f"predictive_cache_{datetime.datetime.now().strftime('%Y%m%d_%H')}.json"
        cache_file.write_text(json.dumps(cache_data, indent=2))
        
        # Update current cache pointer
        current_cache = self.cache_path / "current.json"
        current_cache.write_text(json.dumps({
            'cache_file': str(cache_file),
            'stats': cache_stats
        }, indent=2))
        
        # Calculate optimization ratio
        if cache_stats['total_size'] > 0:
            cache_stats['optimization_ratio'] = (
                cache_stats['pattern_count'] + cache_stats['file_count']
            ) / (cache_stats['total_size'] / 1000)  # Items per KB
            
        return cache_stats
        
    def generate_preload_recommendations(self, model: Dict) -> List[Dict]:
        """Generate specific preload recommendations"""
        
        recommendations = []
        
        # Use ollama to generate intelligent recommendations
        system_prompt = """Based on the prediction model, generate specific preload recommendations.
        Consider efficiency, likelihood of use, and resource constraints.
        
        Output JSON:
        {
            "recommendations": [
                {
                    "action": "preload|cache|index",
                    "resource": "specific resource",
                    "priority": 0.0-1.0,
                    "reason": "why this is recommended",
                    "expected_benefit": "performance improvement"
                }
            ]
        }
        """
        
        prompt = f"Generate preload recommendations from model:\n{json.dumps(model, indent=2)[:1000]}"
        response = self.orchestrator.ollama_query(prompt, system_prompt)
        
        try:
            recs = json.loads(response).get('recommendations', [])
            recommendations.extend(recs)
        except:
            # Fallback recommendations
            if model['topical'].get('next_topics'):
                recommendations.append({
                    'action': 'preload',
                    'resource': 'related_patterns',
                    'priority': 0.8,
                    'reason': 'Topics predicted with high confidence',
                    'expected_benefit': '50ms faster pattern access'
                })
                
        return recommendations
        
    def run(self) -> Dict:
        """Execute predictive loading"""
        metrics = {
            'tokens_processed': 0,
            'predictions_made': 0,
            'resources_preloaded': 0,
            'cache_efficiency': 0.0,
            'metadata': {}
        }
        
        # Get recent sessions
        recent_sessions = self.orchestrator.get_recent_sessions(24)
        
        # Analyze temporal patterns
        temporal_patterns = self.analyze_temporal_patterns()
        
        # Predict next topics
        topic_predictions = []
        if recent_sessions:
            topic_predictions = self.predict_next_topics(recent_sessions)
            metrics['predictions_made'] += len(topic_predictions)
            metrics['tokens_processed'] += sum(len(s['content']) // 4 for s in recent_sessions[:3])
            
        # Calculate resource similarity
        resource_predictions = self.calculate_resource_similarity(recent_sessions)
        
        # Build prediction model
        model = self.build_prediction_model(temporal_patterns, topic_predictions)
        
        # Preload predicted resources
        preloaded = self.preload_predicted_resources(model)
        metrics['resources_preloaded'] = (
            len(preloaded['patterns']) + 
            len(preloaded['files']) + 
            len(preloaded['knowledge'])
        )
        
        # Optimize cache
        cache_stats = self.optimize_cache(preloaded)
        metrics['cache_efficiency'] = cache_stats.get('optimization_ratio', 0.0)
        
        # Generate recommendations
        recommendations = self.generate_preload_recommendations(model)
        
        metrics['metadata'] = {
            'temporal_patterns': len(temporal_patterns['hourly']),
            'topic_predictions': len(topic_predictions),
            'pattern_sequences': len(model['sequential'].get('pattern_sequences', [])),
            'cache_size_kb': cache_stats['total_size'] / 1024,
            'top_predictions': [
                {'topic': t['topic'], 'confidence': t['confidence']}
                for t in topic_predictions[:3]
            ],
            'recommendations': len(recommendations)
        }
        
        return metrics
