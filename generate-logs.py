#!/usr/bin/env python3
"""
Spring Boot JSON Lines Log Generator

This script generates sample Spring Boot logs in JSON Lines format
for testing the Loki + Grafana stack.
"""

import json
import random
import time
from datetime import datetime, timezone
import os
import sys

# Log levels with relative frequencies
LOG_LEVELS = [
    ("INFO", 60),
    ("DEBUG", 20),
    ("WARN", 15),
    ("ERROR", 4),
    ("TRACE", 1),
]

# Sample loggers
LOGGERS = [
    "com.example.demo.controller.UserController",
    "com.example.demo.service.UserService",
    "com.example.demo.repository.UserRepository",
    "com.example.demo.controller.OrderController",
    "com.example.demo.service.OrderService",
    "com.example.demo.service.PaymentService",
    "com.example.demo.security.AuthenticationFilter",
    "com.example.demo.config.DataSourceConfig",
    "org.springframework.web.servlet.DispatcherServlet",
    "org.springframework.boot.web.embedded.tomcat.TomcatWebServer",
]

# Sample messages by log level
MESSAGES = {
    "INFO": [
        "Application started successfully",
        "User logged in successfully",
        "Order created with ID: {}",
        "Payment processed successfully",
        "Database connection established",
        "Request completed in {}ms",
        "New user registered: {}",
        "Session created for user: {}",
        "Cache refreshed successfully",
        "Health check passed",
    ],
    "DEBUG": [
        "Entering method: {}",
        "Exiting method: {}",
        "Query executed: SELECT * FROM users WHERE id = {}",
        "Cache hit for key: {}",
        "Validating request parameters",
        "Processing request from IP: {}",
        "Applying security filter",
        "Deserializing JSON payload",
        "Loading configuration from: {}",
        "Initializing bean: {}",
    ],
    "WARN": [
        "Slow query detected: took {}ms",
        "Cache miss for key: {}",
        "Deprecated API used: {}",
        "Retry attempt {} for operation",
        "Queue size approaching limit: {}",
        "Connection pool utilization high: {}%",
        "Session timeout for user: {}",
        "Invalid input received: {}",
        "Rate limit approaching for IP: {}",
        "Configuration value missing, using default",
    ],
    "ERROR": [
        "Failed to process payment: {}",
        "Database connection error: {}",
        "Authentication failed for user: {}",
        "Unable to send email notification",
        "External API call failed: {}",
        "Invalid JSON payload received",
        "Resource not found: {}",
        "Permission denied for user: {}",
        "Transaction rollback: {}",
        "Unexpected exception: {}",
    ],
    "TRACE": [
        "Method trace: {} with parameters: {}",
        "SQL statement: {}",
        "HTTP request headers: {}",
        "Request body: {}",
        "Response body: {}",
    ],
}

# Sample thread names
THREADS = [
    "http-nio-8080-exec-1",
    "http-nio-8080-exec-2",
    "http-nio-8080-exec-3",
    "http-nio-8080-exec-4",
    "scheduling-1",
    "task-executor-1",
    "task-executor-2",
]

# Sample exception classes
EXCEPTION_CLASSES = [
    "java.sql.SQLException",
    "org.springframework.web.client.HttpClientErrorException",
    "java.io.IOException",
    "java.lang.NullPointerException",
    "javax.validation.ValidationException",
    "org.springframework.security.access.AccessDeniedException",
    "com.example.demo.exception.ResourceNotFoundException",
    "com.example.demo.exception.PaymentException",
]

# Sample exception messages
EXCEPTION_MESSAGES = [
    "Connection timeout after 30000ms",
    "Invalid credentials provided",
    "Resource with ID {} not found",
    "Payment gateway returned error code: {}",
    "Validation failed for field: {}",
    "Database constraint violation",
    "API rate limit exceeded",
    "Session expired",
]


def generate_trace_id():
    """Generate a random trace ID"""
    return ''.join(random.choices('0123456789abcdef', k=32))


def generate_span_id():
    """Generate a random span ID"""
    return ''.join(random.choices('0123456789abcdef', k=16))


def format_message(template, level):
    """Format a message template with random values"""
    if '{}' in template:
        if 'ID' in template or 'id' in template:
            return template.format(random.randint(1000, 9999))
        elif 'ms' in template:
            return template.format(random.randint(50, 2000))
        elif 'user' in template.lower():
            return template.format(f"user{random.randint(1, 100)}")
        elif '%' in template:
            return template.format(random.randint(70, 95))
        elif 'IP' in template:
            return template.format(f"192.168.1.{random.randint(1, 255)}")
        else:
            return template.format(random.choice(['alpha', 'beta', 'gamma', 'delta']))
    return template


def generate_log_entry():
    """Generate a single log entry in JSON Lines format"""
    # Select log level based on frequency
    level = random.choices(
        [l[0] for l in LOG_LEVELS],
        weights=[l[1] for l in LOG_LEVELS],
        k=1
    )[0]
    
    # Generate basic log entry
    log_entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "level": level,
        "thread": random.choice(THREADS),
        "logger": random.choice(LOGGERS),
        "message": format_message(random.choice(MESSAGES[level]), level),
        "application": "demo-app",
    }
    
    # Add trace and span IDs (50% of the time)
    if random.random() < 0.5:
        log_entry["traceId"] = generate_trace_id()
        log_entry["spanId"] = generate_span_id()
    
    # Add exception details for ERROR logs (70% of the time)
    if level == "ERROR" and random.random() < 0.7:
        exception_class = random.choice(EXCEPTION_CLASSES)
        exception_message = format_message(random.choice(EXCEPTION_MESSAGES), level)
        
        log_entry["exception"] = {
            "class": exception_class,
            "message": exception_message,
            "stackTrace": f"{exception_class}: {exception_message}\n\tat com.example.demo.Example.method(Example.java:{random.randint(10, 200)})\n\tat com.example.demo.Main.run(Main.java:{random.randint(10, 100)})"
        }
    
    return log_entry


def write_log(log_entry, log_file):
    """Write a log entry to file in JSON Lines format"""
    with open(log_file, 'a') as f:
        f.write(json.dumps(log_entry) + '\n')


def main():
    """Main function to generate logs"""
    # Create logs directory if it doesn't exist
    log_dir = "logs"
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
        print(f"Created directory: {log_dir}")
    
    log_file = os.path.join(log_dir, "application.log")
    
    # Determine mode: batch or continuous
    mode = sys.argv[1] if len(sys.argv) > 1 else "batch"
    
    if mode == "continuous":
        print(f"Generating logs continuously to {log_file}")
        print("Press Ctrl+C to stop")
        try:
            while True:
                log_entry = generate_log_entry()
                write_log(log_entry, log_file)
                
                # Print to console
                level_color = {
                    "INFO": "\033[32m",    # Green
                    "DEBUG": "\033[36m",   # Cyan
                    "WARN": "\033[33m",    # Yellow
                    "ERROR": "\033[31m",   # Red
                    "TRACE": "\033[37m",   # White
                }
                reset_color = "\033[0m"
                
                print(f"{level_color.get(log_entry['level'], '')}"
                      f"[{log_entry['level']:5s}] "
                      f"{log_entry['logger']:50s} - "
                      f"{log_entry['message']}"
                      f"{reset_color}")
                
                # Random delay between 0.1 and 2 seconds
                time.sleep(random.uniform(0.1, 2.0))
        except KeyboardInterrupt:
            print("\n\nStopped log generation")
    
    elif mode == "batch":
        # Generate a batch of logs
        count = int(sys.argv[2]) if len(sys.argv) > 2 else 100
        print(f"Generating {count} log entries to {log_file}")
        
        for i in range(count):
            log_entry = generate_log_entry()
            write_log(log_entry, log_file)
            
            if (i + 1) % 10 == 0:
                print(f"Generated {i + 1}/{count} logs")
        
        print(f"\nCompleted! Generated {count} logs to {log_file}")
    
    elif mode == "burst":
        # Generate bursts of logs with pauses
        bursts = int(sys.argv[2]) if len(sys.argv) > 2 else 5
        logs_per_burst = int(sys.argv[3]) if len(sys.argv) > 3 else 50
        
        print(f"Generating {bursts} bursts of {logs_per_burst} logs each")
        
        for burst in range(bursts):
            print(f"\nBurst {burst + 1}/{bursts}...")
            for i in range(logs_per_burst):
                log_entry = generate_log_entry()
                write_log(log_entry, log_file)
                time.sleep(0.01)  # Small delay within burst
            
            if burst < bursts - 1:
                print(f"Waiting 5 seconds before next burst...")
                time.sleep(5)
        
        print(f"\nCompleted! Generated {bursts * logs_per_burst} logs in {bursts} bursts")
    
    else:
        print("Usage:")
        print("  python generate-logs.py batch [count]        - Generate batch of logs (default: 100)")
        print("  python generate-logs.py continuous           - Generate logs continuously")
        print("  python generate-logs.py burst [bursts] [per] - Generate bursts of logs")
        sys.exit(1)


if __name__ == "__main__":
    main()
