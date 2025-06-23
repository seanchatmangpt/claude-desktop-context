#!/usr/bin/env python3
"""
Knowledge Synthesizer Agent - Builds knowledge graphs across sessions
Uses ollama/qwen3 to find connections and synthesize insights
"""

import json
import networkx as nx
from pathlib import Path
from typing import Dict, List, Set, Tuple
import datetime
import numpy as np
from collections import defaultdict

class KnowledgeSynthesizer:
    def __init__(self, orchestrator):
        self.orchestrator = orchestrator
        self.task_description = "Synthesizing knowledge across sessions"
        self.knowledge_path = Path("/Users/sac/claude-desktop-context/knowledge")
        self.knowledge_path.mkdir(parents=True, exist_ok=True)
        self.graph = nx.DiGraph()
        
    def extract_concepts(self, text: str) -> List[Dict]:
        """Extract key concepts from text using ollama"""
        
        system_prompt = """Extract key concepts from this CDCS session.
        Focus on:
        1. Technical concepts (tools, patterns, algorithms)
        2. Domain concepts (problems, solutions, approaches)
        3. System concepts (CDCS components, capabilities)
        4. Relationships between concepts
        
        Output JSON:
        {
            "concepts": [
                {
                    "name": "concept name",
                    "type": "technical|domain|system",
                    "description": "brief description",
                    "related_to": ["other", "concepts"],
                    "importance": 0.0-1.0
                }
            ]
        }
        """
        
        prompt = f"Extract concepts from:\n{text[:2000]}"
        response = self.orchestrator.ollama_query(prompt, system_prompt)
        
        try:
            return json.loads(response).get('concepts', [])
        except:
            # Fallback extraction
            return self.fallback_concept_extraction(text)
            
    def fallback_concept_extraction(self, text: str) -> List[Dict]:
        """Simple pattern-based concept extraction"""
        concepts = []
        
        # Extract capitalized terms
        import re
        terms = re.findall(r'\b[A-Z][a-zA-Z]+(?:\s+[A-Z][a-zA-Z]+)*\b', text)
        
        for term in set(terms):
            if len(term) > 3:  # Skip short terms
                concepts.append({
                    "name": term,
                    "type": "domain",
                    "description": f"Mentioned in context",
                    "related_to": [],
                    "importance": 0.5
                })
                
        return concepts[:20]  # Limit
        
    def build_knowledge_graph(self, sessions: List[Dict]) -> nx.DiGraph:
        """Build knowledge graph from sessions"""
        
        for session in sessions:
            # Extract concepts
            concepts = self.extract_concepts(session['content'])
            
            # Add nodes
            for concept in concepts:
                node_id = concept['name'].lower().replace(' ', '_')
                
                if node_id not in self.graph:
                    self.graph.add_node(
                        node_id,
                        name=concept['name'],
                        type=concept['type'],
                        description=concept['description'],
                        importance=concept['importance'],
                        sessions=[session['file']],
                        first_seen=session['file'],
                        occurrence_count=1
                    )
                else:
                    # Update existing node
                    self.graph.nodes[node_id]['occurrence_count'] += 1
                    self.graph.nodes[node_id]['sessions'].append(session['file'])
                    self.graph.nodes[node_id]['importance'] = max(
                        self.graph.nodes[node_id]['importance'],
                        concept['importance']
                    )
                    
                # Add edges
                for related in concept.get('related_to', []):
                    related_id = related.lower().replace(' ', '_')
                    if related_id in self.graph:
                        if self.graph.has_edge(node_id, related_id):
                            self.graph[node_id][related_id]['weight'] += 1
                        else:
                            self.graph.add_edge(node_id, related_id, weight=1)
                            
        return self.graph
        
    def identify_concept_clusters(self) -> List[Set[str]]:
        """Identify clusters of related concepts"""
        
        # Use community detection
        try:
            import community
            partition = community.best_partition(self.graph.to_undirected())
            
            clusters = defaultdict(set)
            for node, cluster_id in partition.items():
                clusters[cluster_id].add(node)
                
            return list(clusters.values())
        except:
            # Fallback to connected components
            return list(nx.weakly_connected_components(self.graph))
            
    def synthesize_insights(self, clusters: List[Set[str]]) -> List[Dict]:
        """Generate insights from concept clusters"""
        insights = []
        
        for i, cluster in enumerate(clusters):
            if len(cluster) < 3:  # Skip small clusters
                continue
                
            # Get cluster concepts
            cluster_concepts = []
            for node_id in cluster:
                node_data = self.graph.nodes[node_id]
                cluster_concepts.append({
                    'name': node_data['name'],
                    'type': node_data['type'],
                    'importance': node_data['importance']
                })
                
            # Use ollama to synthesize insight
            system_prompt = """Synthesize an insight from these related concepts.
            Generate a novel understanding or connection that emerges from their combination.
            
            Output JSON:
            {
                "insight": "the synthesized insight",
                "type": "pattern|principle|opportunity|connection",
                "confidence": 0.0-1.0,
                "applications": ["potential use case 1", "use case 2"],
                "prerequisites": ["required knowledge or context"]
            }
            """
            
            concepts_str = json.dumps(cluster_concepts, indent=2)
            prompt = f"Synthesize insight from concepts:\n{concepts_str}"
            
            response = self.orchestrator.ollama_query(prompt, system_prompt)
            
            try:
                insight = json.loads(response)
                insight['cluster_id'] = i
                insight['concepts'] = [c['name'] for c in cluster_concepts]
                insights.append(insight)
            except:
                # Basic insight
                insights.append({
                    'insight': f"Cluster of {len(cluster)} related concepts",
                    'type': 'connection',
                    'confidence': 0.5,
                    'cluster_id': i,
                    'concepts': [self.graph.nodes[n]['name'] for n in list(cluster)[:5]]
                })
                
        return insights
        
    def detect_knowledge_gaps(self) -> List[Dict]:
        """Identify gaps in knowledge graph"""
        gaps = []
        
        # Find weakly connected nodes (potential gaps)
        for node in self.graph.nodes():
            in_degree = self.graph.in_degree(node)
            out_degree = self.graph.out_degree(node)
            
            if in_degree + out_degree < 2:  # Isolated or weakly connected
                node_data = self.graph.nodes[node]
                
                # Use ollama to identify what's missing
                prompt = f"What knowledge would better connect '{node_data['name']}' ({node_data['description']}) to a broader system?"
                
                response = self.orchestrator.ollama_query(prompt, 
                    "Suggest missing connections or knowledge gaps. Be specific and actionable."
                )
                
                gaps.append({
                    'concept': node_data['name'],
                    'current_connections': in_degree + out_degree,
                    'gap_analysis': response[:200],
                    'priority': node_data['importance'] * (1 / (in_degree + out_degree + 1))
                })
                
        return sorted(gaps, key=lambda x: x['priority'], reverse=True)[:10]
        
    def generate_knowledge_map(self) -> Dict:
        """Generate visual knowledge map data"""
        
        # Calculate layout
        try:
            pos = nx.spring_layout(self.graph, k=2, iterations=50)
        except:
            pos = {}
            
        # Prepare node data
        nodes = []
        for node_id, (x, y) in pos.items():
            node_data = self.graph.nodes[node_id]
            nodes.append({
                'id': node_id,
                'x': float(x),
                'y': float(y),
                'name': node_data['name'],
                'type': node_data['type'],
                'size': np.log(node_data['occurrence_count'] + 1) * 10,
                'importance': node_data['importance']
            })
            
        # Prepare edge data
        edges = []
        for source, target, data in self.graph.edges(data=True):
            edges.append({
                'source': source,
                'target': target,
                'weight': data.get('weight', 1)
            })
            
        return {
            'nodes': nodes,
            'edges': edges,
            'stats': {
                'total_concepts': len(self.graph.nodes),
                'total_connections': len(self.graph.edges),
                'avg_connections': np.mean([self.graph.degree(n) for n in self.graph.nodes]) if self.graph.nodes else 0
            }
        }
        
    def save_synthesis_results(self, results: Dict):
        """Save synthesis results to knowledge base"""
        
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        
        # Save knowledge graph
        graph_file = self.knowledge_path / f"knowledge_graph_{timestamp}.json"
        nx.write_json_graph(self.graph, str(graph_file))
        
        # Save insights
        insights_file = self.knowledge_path / f"insights_{timestamp}.json"
        insights_file.write_text(json.dumps(results['insights'], indent=2))
        
        # Save knowledge map
        map_file = self.knowledge_path / f"knowledge_map_{timestamp}.json"
        map_file.write_text(json.dumps(results['knowledge_map'], indent=2))
        
        # Update current knowledge pointer
        current_file = self.knowledge_path / "current.json"
        current_file.write_text(json.dumps({
            'timestamp': timestamp,
            'graph': str(graph_file),
            'insights': str(insights_file),
            'map': str(map_file),
            'stats': results['stats']
        }, indent=2))
        
    def run(self) -> Dict:
        """Execute knowledge synthesis"""
        metrics = {
            'tokens_processed': 0,
            'concepts_extracted': 0,
            'insights_generated': 0,
            'gaps_identified': 0,
            'metadata': {}
        }
        
        # Get recent sessions
        sessions = self.orchestrator.get_recent_sessions(168)  # Last week
        
        if not sessions:
            return metrics
            
        # Build knowledge graph
        self.build_knowledge_graph(sessions)
        metrics['concepts_extracted'] = len(self.graph.nodes)
        metrics['tokens_processed'] = sum(len(s['content']) // 4 for s in sessions)
        
        # Identify clusters
        clusters = self.identify_concept_clusters()
        
        # Synthesize insights
        insights = self.synthesize_insights(clusters)
        metrics['insights_generated'] = len(insights)
        
        # Detect knowledge gaps
        gaps = self.detect_knowledge_gaps()
        metrics['gaps_identified'] = len(gaps)
        
        # Generate knowledge map
        knowledge_map = self.generate_knowledge_map()
        
        # Prepare results
        results = {
            'insights': insights,
            'gaps': gaps,
            'knowledge_map': knowledge_map,
            'stats': {
                'concepts': len(self.graph.nodes),
                'connections': len(self.graph.edges),
                'clusters': len(clusters),
                'largest_cluster': max(len(c) for c in clusters) if clusters else 0
            }
        }
        
        # Save results
        self.save_synthesis_results(results)
        
        metrics['metadata'] = {
            'clusters_found': len(clusters),
            'avg_cluster_size': np.mean([len(c) for c in clusters]) if clusters else 0,
            'graph_density': nx.density(self.graph) if len(self.graph) > 1 else 0,
            'top_concepts': sorted(
                [(n, self.graph.nodes[n]['occurrence_count']) for n in self.graph.nodes],
                key=lambda x: x[1],
                reverse=True
            )[:10]
        }
        
        return metrics
