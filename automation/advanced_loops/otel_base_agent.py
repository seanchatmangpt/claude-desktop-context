#!/usr/bin/env python3
"""
OpenTelemetry Base Agent - Enhanced base class with built-in observability
Provides automatic instrumentation for all CDCS automation agents
"""

import os
import sys
import time
import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, Optional, Callable
from functools import wraps
from contextlib import contextmanager

# OpenTelemetry imports
from opentelemetry import trace, metrics
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes
from opentelemetry.trace import Status, StatusCode
# from opentelemetry.instrumentation.logging import LoggingInstrumentor

# Add CDCS path
CDCS_PATH = Path("/Users/sac/claude-desktop-context")
sys.path.append(str(CDCS_PATH / "automation"))

from base_agent import BaseAgent as OriginalBaseAgent

class TelemetryConfig:
    """Configuration for OpenTelemetry"""
    
    def __init__(self):
        self.enabled = os.getenv('CDCS_TELEMETRY_ENABLED', 'true').lower() == 'true'
        self.endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'http://localhost:4317')
        self.service_name = 'cdcs-automation'
        self.service_version = '2.1.0'
        self.environment = os.getenv('CDCS_ENV', 'production')
        self.export_interval = int(os.getenv('OTEL_METRIC_EXPORT_INTERVAL', '30000'))  # ms
        
class OTelBaseAgent(OriginalBaseAgent):
    """Enhanced base agent with OpenTelemetry instrumentation"""
    
    # Class-level telemetry setup
    _telemetry_initialized = False
    _tracer = None
    _meter = None
    _config = TelemetryConfig()
    
    @classmethod
    def initialize_telemetry(cls):
        """Initialize OpenTelemetry providers"""
        if cls._telemetry_initialized or not cls._config.enabled:
            return
            
        # Create resource
        resource = Resource.create({
            ResourceAttributes.SERVICE_NAME: cls._config.service_name,
            ResourceAttributes.SERVICE_VERSION: cls._config.service_version,
            ResourceAttributes.DEPLOYMENT_ENVIRONMENT: cls._config.environment,
            ResourceAttributes.HOST_NAME: os.uname().nodename,
            ResourceAttributes.PROCESS_PID: os.getpid(),
        })
        
        # Setup tracing
        trace.set_tracer_provider(TracerProvider(resource=resource))
        tracer_provider = trace.get_tracer_provider()
        
        if cls._config.endpoint != 'none':
            span_processor = BatchSpanProcessor(
                OTLPSpanExporter(endpoint=cls._config.endpoint, insecure=True)
            )
            tracer_provider.add_span_processor(span_processor)
        
        # Setup metrics
        metric_reader = PeriodicExportingMetricReader(
            exporter=OTLPMetricExporter(endpoint=cls._config.endpoint, insecure=True),
            export_interval_millis=cls._config.export_interval
        )
        metrics.set_meter_provider(
            MeterProvider(resource=resource, metric_readers=[metric_reader])
        )
        
        # Instrument logging
        # LoggingInstrumentor().instrument()
        
        cls._tracer = trace.get_tracer(__name__, cls._config.service_version)
        cls._meter = metrics.get_meter(__name__, cls._config.service_version)
        cls._telemetry_initialized = True
        
    def __init__(self, orchestrator, agent_name: str):
        super().__init__(orchestrator, agent_name)
        
        # Initialize telemetry if not done
        self.__class__.initialize_telemetry()
        
        # Create agent-specific instruments
        self._create_metrics()
        
        # Add telemetry context to logger
        self._setup_contextual_logging()
        
    def _create_metrics(self):
        """Create agent-specific metrics"""
        self.execution_counter = self._meter.create_counter(
            name="cdcs.agent.executions",
            description="Number of agent executions",
            unit="1"
        )
        
        self.execution_duration = self._meter.create_histogram(
            name="cdcs.agent.execution.duration",
            description="Duration of agent executions",
            unit="s"
        )
        
        self.error_counter = self._meter.create_counter(
            name="cdcs.agent.errors",
            description="Number of agent errors",
            unit="1"
        )
        
        self.pattern_counter = self._meter.create_counter(
            name="cdcs.patterns.detected",
            description="Number of patterns detected",
            unit="1"
        )
        
        self.fix_counter = self._meter.create_counter(
            name="cdcs.fixes.applied",
            description="Number of fixes applied",
            unit="1"
        )
        
        # Gauge for system health
        self.health_gauge = self._meter.create_gauge(
            name="cdcs.system.health",
            description="System health score (0-100)",
            unit="1"
        )
        
    def _setup_contextual_logging(self):
        """Add trace context to log records"""
        class ContextFilter(logging.Filter):
            def filter(self, record):
                span = trace.get_current_span()
                if span and span.is_recording():
                    span_context = span.get_span_context()
                    record.trace_id = format(span_context.trace_id, '032x')
                    record.span_id = format(span_context.span_id, '016x')
                else:
                    record.trace_id = '0' * 32
                    record.span_id = '0' * 16
                return True
                
        self.logger.addFilter(ContextFilter())
        
    @contextmanager
    def start_span(self, name: str, attributes: Dict[str, Any] = None):
        """Context manager for creating spans"""
        if not self._config.enabled:
            yield None
            return
            
        with self._tracer.start_as_current_span(
            name,
            attributes=attributes or {}
        ) as span:
            try:
                yield span
            except Exception as e:
                span.set_status(Status(StatusCode.ERROR, str(e)))
                span.record_exception(e)
                raise
                
    def traced_method(self, func: Callable) -> Callable:
        """Decorator to add tracing to methods"""
        @wraps(func)
        def wrapper(*args, **kwargs):
            span_name = f"{self.agent_name}.{func.__name__}"
            with self.start_span(span_name) as span:
                if span:
                    span.set_attribute("agent.name", self.agent_name)
                    span.set_attribute("method.name", func.__name__)
                
                start_time = time.time()
                try:
                    result = func(*args, **kwargs)
                    if span:
                        span.set_status(Status(StatusCode.OK))
                    return result
                except Exception as e:
                    self.error_counter.add(1, {"agent": self.agent_name, "method": func.__name__})
                    raise
                finally:
                    duration = time.time() - start_time
                    self.execution_duration.record(
                        duration,
                        {"agent": self.agent_name, "method": func.__name__}
                    )
        return wrapper
        
    def run(self):
        """Enhanced run method with automatic tracing"""
        span_name = f"{self.agent_name}.run"
        
        with self.start_span(span_name) as span:
            if span:
                span.set_attribute("agent.name", self.agent_name)
                span.set_attribute("agent.class", self.__class__.__name__)
                
            self.execution_counter.add(1, {"agent": self.agent_name})
            
            try:
                # Call the actual run implementation
                super().run()
                
                if span:
                    span.set_status(Status(StatusCode.OK))
                    
            except Exception as e:
                self.error_counter.add(1, {"agent": self.agent_name, "error": type(e).__name__})
                if span:
                    span.set_status(Status(StatusCode.ERROR, str(e)))
                    span.record_exception(e)
                raise
                
    def record_pattern_detection(self, pattern_type: str, confidence: float):
        """Record pattern detection event"""
        self.pattern_counter.add(
            1,
            {
                "agent": self.agent_name,
                "pattern_type": pattern_type,
                "confidence_level": "high" if confidence > 0.8 else "medium"
            }
        )
        
        span = trace.get_current_span()
        if span and span.is_recording():
            span.add_event(
                "pattern_detected",
                {
                    "pattern.type": pattern_type,
                    "pattern.confidence": confidence
                }
            )
            
    def record_fix_applied(self, issue_type: str, success: bool):
        """Record fix application"""
        self.fix_counter.add(
            1,
            {
                "agent": self.agent_name,
                "issue_type": issue_type,
                "success": str(success).lower()
            }
        )
        
        span = trace.get_current_span()
        if span and span.is_recording():
            span.add_event(
                "fix_applied",
                {
                    "fix.issue_type": issue_type,
                    "fix.success": success
                }
            )
            
    def update_health_score(self, score: float):
        """Update system health score"""
        self.health_gauge.set(
            score,
            {"agent": self.agent_name}
        )
        
    def create_child_span(self, name: str, parent_span=None) -> Any:
        """Create a child span"""
        if not self._config.enabled:
            return None
            
        parent_context = parent_span.get_span_context() if parent_span else None
        return self._tracer.start_span(name, context=parent_context)
        
    def add_span_event(self, name: str, attributes: Dict[str, Any] = None):
        """Add event to current span"""
        span = trace.get_current_span()
        if span and span.is_recording():
            span.add_event(name, attributes or {})
            
    def set_span_attributes(self, attributes: Dict[str, Any]):
        """Set attributes on current span"""
        span = trace.get_current_span()
        if span and span.is_recording():
            for key, value in attributes.items():
                span.set_attribute(key, value)

# Convenience function for manual instrumentation
def instrument_function(name: str = None):
    """Decorator to instrument any function with OpenTelemetry"""
    def decorator(func):
        span_name = name or f"{func.__module__}.{func.__name__}"
        
        @wraps(func)
        def wrapper(*args, **kwargs):
            tracer = trace.get_tracer(__name__)
            with tracer.start_as_current_span(span_name) as span:
                span.set_attribute("function.name", func.__name__)
                span.set_attribute("function.module", func.__module__)
                
                try:
                    result = func(*args, **kwargs)
                    span.set_status(Status(StatusCode.OK))
                    return result
                except Exception as e:
                    span.set_status(Status(StatusCode.ERROR, str(e)))
                    span.record_exception(e)
                    raise
                    
        return wrapper
    return decorator

if __name__ == "__main__":
    # Test telemetry
    print("Testing OpenTelemetry instrumentation...")
    
    class TestAgent(OTelBaseAgent):
        def run(self):
            with self.start_span("test_operation") as span:
                self.logger.info("Test operation started")
                time.sleep(0.1)
                self.record_pattern_detection("test_pattern", 0.95)
                self.record_fix_applied("test_issue", True)
                self.update_health_score(95.0)
                self.logger.info("Test operation completed")
    
    # Mock orchestrator
    class MockOrchestrator:
        base_path = CDCS_PATH
    
    agent = TestAgent(MockOrchestrator(), "TestAgent")
    agent.run()
    
    print("Telemetry test completed. Check your OTLP endpoint for data.")
