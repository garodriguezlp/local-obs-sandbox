# Spring Boot Log Management with Loki and Grafana

## Project Goal

Learn about Loki and Grafana by creating a local log management solution for Spring Boot applications that produce JSON Lines formatted logs.

## Requirements

### 1. Docker Compose Stack

Create a complete Docker Compose setup to:
- Easily push Spring Boot logs into the stack
- Query, filter, and shape logs conveniently
- Run all components locally

### 2. Comprehensive Markdown Guide

The guide should include the following sections:

#### Conceptual Overview
- Explain the role and purpose of each component in the stack
- Describe how the pieces work together
- Provide theory behind the architecture

#### Individual Component Setup
- How to pull each Docker image
- How to run each container individually
- Version compatibility matrix considerations
- How to verify each component independently using:
  - Web UI when available
  - HTTPie or curl for API endpoints
  - Basic health checks

#### Integration Guide
- Step-by-step instructions for connecting the components
- Required plugins and configurations for each piece
- Wiring details between services
- Network and port configurations

#### Final Configuration
- Complete Docker Compose file for the entire stack
- Environment variables and configurations
- Volume mappings for persistence

### 3. Test Data Generation

Include instructions or a script to generate sample Spring Boot JSON Lines logs for testing the complete setup.

## Deliverables

1. Comprehensive markdown documentation covering all sections above
2. Docker Compose file for the complete stack
3. Sample log generator for Spring Boot JSON Lines format
4. Verification steps to ensure the stack is working correctly
