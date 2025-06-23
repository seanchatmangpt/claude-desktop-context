#!/usr/bin/env python3
"""
CDCS Predictive Context Loading System
Version: 2.2.0
"""

import json
import os
import math
from collections import Counter, defaultdict
from datetime import datetime, timedelta
import hashlib

class PredictiveLoader:
    def __init__(self, cdcs_root="/Users/sac/claude-desktop-context"):
        self.root = cdcs_root
        self.prediction_dir = os.path.join(self.root, "analysis/prediction")
        self.cache_file = os.path.join(self.prediction_dir, "context_cache.json")
        self.history_file = os.path.join(self.prediction_dir, "interaction_history.json")
        self.patterns_dir = os.path.join(self.root, "patterns/catalog")
        
        self.load_history()
        
    def load_history(self):
        """Load interaction history for pattern analysis"""
        if os.path.exists(self.history_file):
            with open(self.history_file, 'r') as f:
                self.history = json.load(f)
        else:
            self.history = {
                "sessions": [],
                "patterns": defaultdict(int),
                "transitions": defaultdict(lambda: defaultdict(int))
            }
    
    def calculate_shannon_entropy(self, text):
        """Calculate Shannon entropy of text"""
        if not text:
            return 0.0
            
        # Count character frequencies
        freq = Counter(text)
        total = len(text)
        
        # Calculate entropy
        entropy = 0
        for count in freq.values():
            p = count / total
            if p > 0:
                entropy -= p * math.log2(p)
                
        return entropy
    
    def extract_conversation_vector(self, messages, vector_size=384):
        """Extract a simple vector representation of conversation"""
        # Simplified vectorization - in production, use proper embeddings
        vector = [0.0] * vector_size
        
        # Extract features
        features = {
            'length': len(messages),
            'code_present': any('```' in str(m) for m in messages),
            'file_ops': sum(1 for m in messages if any(
                term in str(m).lower() for term in ['file', 'read', 'write', 'create']
            )),
            'pattern_refs': sum(1 for m in messages if 'pattern' in str(m).lower()),
            'complexity': sum(len(str(m)) for m in messages) / max(len(messages), 1)
        }
        
        # Map features to vector positions
        for i, (key, value) in enumerate(features.items()):
            if i < vector_size:
                vector[i] = float(value)
                
        return vector
    
    def cosine_similarity(self, vec1, vec2):
        """Calculate cosine similarity between vectors"""
        dot_product = sum(a * b for a, b in zip(vec1, vec2))
        norm1 = math.sqrt(sum(a * a for a in vec1))
        norm2 = math.sqrt(sum(b * b for b in vec2))
        
        if norm1 == 0 or norm2 == 0:
            return 0.0
            
        return dot_product / (norm1 * norm2)
    
    def predict_next_topics(self, current_context, num_predictions=3):
        """Predict the next likely topics based on conversation trajectory"""
        predictions = []
        
        # Extract current vector
        current_vector = self.extract_conversation_vector(current_context)
        
        # Compare with historical patterns
        similarities = []
        for session in self.history.get("sessions", []):
            hist_vector = session.get("vector", [])
            if hist_vector:
                sim = self.cosine_similarity(current_vector, hist_vector)
                similarities.append({
                    "similarity": sim,
                    "next_topics": session.get("topics", []),
                    "patterns_used": session.get("patterns", [])
                })
        
        # Sort by similarity
        similarities.sort(key=lambda x: x["similarity"], reverse=True)
        
        # Aggregate predictions
        topic_scores = defaultdict(float)
        pattern_scores = defaultdict(float)
        
        for sim in similarities[:10]:  # Top 10 most similar
            weight = sim["similarity"]
            for topic in sim["next_topics"]:
                topic_scores[topic] += weight
            for pattern in sim["patterns_used"]:
                pattern_scores[pattern] += weight
        
        # Generate predictions
        top_topics = sorted(topic_scores.items(), key=lambda x: x[1], reverse=True)
        top_patterns = sorted(pattern_scores.items(), key=lambda x: x[1], reverse=True)
        
        for i in range(min(num_predictions, len(top_topics))):
            predictions.append({
                "topic": top_topics[i][0] if i < len(top_topics) else None,
                "confidence": top_topics[i][1] if i < len(top_topics) else 0,
                "related_patterns": [p[0] for p in top_patterns[:3]]
            })
        
        return predictions
    
    def preload_context(self, predictions):
        """Preload predicted content into cache"""
        cache = {
            "timestamp": datetime.now().isoformat(),
            "predictions": predictions,
            "preloaded": {
                "patterns": [],
                "files": [],
                "agent_contexts": []
            }
        }
        
        # Preload patterns
        for pred in predictions:
            if pred["confidence"] > 0.7:  # High confidence threshold
                for pattern in pred["related_patterns"][:2]:
                    pattern_path = self.find_pattern_file(pattern)
                    if pattern_path and os.path.exists(pattern_path):
                        cache["preloaded"]["patterns"].append({
                            "name": pattern,
                            "path": pattern_path,
                            "size": os.path.getsize(pattern_path)
                        })
        
        # Save cache
        with open(self.cache_file, 'w') as f:
            json.dump(cache, f, indent=2)
            
        return cache
    
    def find_pattern_file(self, pattern_name):
        """Find pattern file by name"""
        for root, dirs, files in os.walk(self.patterns_dir):
            for file in files:
                if pattern_name.lower() in file.lower():
                    return os.path.join(root, file)
        return None
    
    def update_history(self, session_data):
        """Update interaction history with new session data"""
        self.history["sessions"].append({
            "timestamp": datetime.now().isoformat(),
            "vector": session_data.get("vector", []),
            "topics": session_data.get("topics", []),
            "patterns": session_data.get("patterns_used", [])
        })
        
        # Keep only recent history (last 100 sessions)
        self.history["sessions"] = self.history["sessions"][-100:]
        
        # Update pattern frequency
        for pattern in session_data.get("patterns_used", []):
            self.history["patterns"][pattern] += 1
        
        # Save history
        with open(self.history_file, 'w') as f:
            json.dump(self.history, f, indent=2)

class DynamicChunkSizer:
    """Dynamically adjust chunk sizes based on content entropy"""
    
    def __init__(self):
        self.base_sizes = {
            'write': 500,
            'read': 5000, 
            'edit': 250
        }
        self.metrics = {
            "total_operations": 0,
            "entropy_distribution": [],
            "size_adjustments": []
        }
    
    def calculate_optimal_chunk_size(self, content, operation_type='write'):
        """Calculate optimal chunk size based on content entropy"""
        if operation_type not in self.base_sizes:
            operation_type = 'write'
            
        base_size = self.base_sizes[operation_type]
        
        # Calculate entropy
        entropy = self.calculate_shannon_entropy(content)
        self.metrics["entropy_distribution"].append(entropy)
        
        # Determine multiplier based on entropy
        if entropy > 6.5:  # Very high (compressed/binary)
            multiplier = 0.5
        elif entropy > 5.0:  # High (code/structured)
            multiplier = 0.8
        elif entropy > 3.5:  # Medium (normal text)
            multiplier = 1.0
        else:  # Low (repetitive)
            multiplier = 1.5
        
        # Additional adjustments
        if self.detect_high_latency():
            multiplier *= 1.2
            
        optimal_size = int(base_size * multiplier)
        
        # Track metrics
        self.metrics["total_operations"] += 1
        self.metrics["size_adjustments"].append({
            "operation": operation_type,
            "entropy": entropy,
            "multiplier": multiplier,
            "size": optimal_size
        })
        
        return optimal_size
    
    def calculate_shannon_entropy(self, text):
        """Calculate Shannon entropy of text"""
        if not text:
            return 0.0
            
        freq = Counter(text)
        total = len(text)
        
        entropy = 0
        for count in freq.values():
            p = count / total
            if p > 0:
                entropy -= p * math.log2(p)
                
        return entropy
    
    def detect_high_latency(self):
        """Detect if system is experiencing high latency"""
        # Simplified - check if recent operations were slow
        recent = self.metrics["size_adjustments"][-5:]
        if len(recent) < 5:
            return False
            
        # In production, measure actual I/O timing
        return False
    
    def get_metrics_summary(self):
        """Get summary of dynamic sizing metrics"""
        if not self.metrics["entropy_distribution"]:
            return {"status": "no data"}
            
        return {
            "total_operations": self.metrics["total_operations"],
            "avg_entropy": sum(self.metrics["entropy_distribution"]) / len(self.metrics["entropy_distribution"]),
            "entropy_range": [
                min(self.metrics["entropy_distribution"]),
                max(self.metrics["entropy_distribution"])
            ],
            "recent_adjustments": self.metrics["size_adjustments"][-10:]
        }

if __name__ == "__main__":
    # Test predictive loading
    print("=== CDCS Predictive Context Loading Test ===")
    loader = PredictiveLoader()
    
    # Simulate current context
    test_context = [
        "I need to analyze a large CSV file",
        "The file contains sales data with patterns",
        "Looking for temporal patterns in the data"
    ]
    
    predictions = loader.predict_next_topics(test_context)
    print("\nPredictions:")
    for i, pred in enumerate(predictions):
        print(f"{i+1}. Topic: {pred['topic']}, Confidence: {pred['confidence']:.2f}")
        print(f"   Related patterns: {pred['related_patterns']}")
    
    # Test dynamic chunk sizing
    print("\n=== Dynamic Chunk Sizing Test ===")
    sizer = DynamicChunkSizer()
    
    # Test different content types
    test_contents = {
        "repetitive": "a" * 1000,
        "normal_text": "The quick brown fox jumps over the lazy dog. " * 20,
        "code": "def process_data(x):\n    return [i**2 for i in x if i > 0]\n" * 10,
        "high_entropy": "".join([chr(i) for i in range(32, 127)]) * 10
    }
    
    for content_type, content in test_contents.items():
        size = sizer.calculate_optimal_chunk_size(content, 'write')
        entropy = sizer.calculate_shannon_entropy(content)
        print(f"\n{content_type}:")
        print(f"  Entropy: {entropy:.2f}")
        print(f"  Optimal chunk size: {size} lines")
    
    print("\n=== Metrics Summary ===")
    print(json.dumps(sizer.get_metrics_summary(), indent=2))
